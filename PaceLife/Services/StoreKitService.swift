import Foundation
import StoreKit
import SwiftUI
import Supabase

@MainActor
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSubscribed = false
    @Published var hasLifetimeAccess = false

    private var updateListenerTask: Task<Void, Error>?

    let productIDs = [
        "com.inedgroup.pacelife.monthly",
        "com.inedgroup.pacelife.annual"
    ]

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { p1, _ in
                p1.id.contains("monthly")
            }
            print("StoreKit: loaded \(products.count) products")
            for p in products {
                print("StoreKit: \(p.id) = \(p.displayPrice)")
            }
        } catch {
            errorMessage = "Failed to load products"
            print("StoreKit load error: \(error)")
        }
        isLoading = false
    }

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await verifyWithServer(transaction: transaction)
            await transaction.finish()
            return transaction
        case .userCancelled:
            return nil
        case .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func restore() async {
        isLoading = true
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        isLoading = false
    }

    func updateSubscriptionStatus() async {
        var activeIDs: Set<String> = []
        var hasAccess = false

        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    activeIDs.insert(transaction.productID)
                    hasAccess = true
                    print("StoreKit: active entitlement = \(transaction.productID)")
                }
            } catch {
                print("StoreKit: unverified transaction")
            }
        }

        purchasedProductIDs = activeIDs
        isSubscribed = hasAccess
        hasLifetimeAccess = hasAccess

        if hasAccess {
            await updateSupabaseSubscription(productIDs: activeIDs)
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await self.verifyWithServer(transaction: transaction)
                    await transaction.finish()
                } catch {
                    print("StoreKit transaction update error: \(error)")
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private func verifyWithServer(transaction: StoreKit.Transaction) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        guard let session = try? await SupabaseManager.shared.client.auth.session else { return }

        let supabaseURL = "https://vhgnnujzcjjugbneuwhn.supabase.co"
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoZ25udWp6Y2pqdWdibmV1d2huIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1ODg5MDgsImV4cCI6MjA4OTE2NDkwOH0.JjtPfC3P1V-pAZ4UrHDSbTNvxIlNHlrL3TCKqfWo4EA"

        guard let url = URL(string: "\(supabaseURL)/functions/v1/verify-purchase") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "user_id": userId.supabaseString,
            "transaction_id": String(transaction.id),
            "original_transaction_id": String(transaction.originalID),
            "product_id": transaction.productID,
            "purchase_date": transaction.purchaseDate.timeIntervalSince1970,
            "expires_date": transaction.expirationDate?.timeIntervalSince1970 as Any,
            "environment": transaction.environment.rawValue
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("StoreKit server verify: \(http.statusCode)")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("StoreKit server response: \(json)")
            }
        } catch {
            print("StoreKit server verify error: \(error)")
        }
    }

    private func updateSupabaseSubscription(productIDs: Set<String>) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        let client = SupabaseManager.shared.client
        let plan = productIDs.contains("com.inedgroup.pacelife.annual") ? "annual" : "monthly"
        do {
            try await client
                .from("subscriptions")
                .update([
                    "status": AnyJSON.string("active"),
                    "plan": AnyJSON.string(plan),
                    "updated_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
                ])
                .eq("user_id", value: userId.supabaseString)
                .execute()
            await UserManager.shared.loadUserData(userId: userId)
            print("StoreKit: Supabase subscription updated to \(plan)")
        } catch {
            print("StoreKit Supabase update error: \(error)")
        }
    }

    var monthlyProduct: Product? {
        products.first { $0.id.contains("monthly") }
    }

    var annualProduct: Product? {
        products.first { $0.id.contains("annual") }
    }

    var activeSubscriptionName: String {
        if purchasedProductIDs.contains("com.inedgroup.pacelife.annual") { return "Annual" }
        if purchasedProductIDs.contains("com.inedgroup.pacelife.monthly") { return "Monthly" }
        return "None"
    }
}
