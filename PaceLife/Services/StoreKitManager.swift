import Foundation
import StoreKit

@MainActor
class StoreKitManager: ObservableObject {
    @Published var products: [Product] = []

    private let productIDs = [
        "com.inedgroup.pacelife.monthly",
        "com.inedgroup.pacelife.annual"
    ]

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price > $1.price }
        } catch {
            print("StoreKit load error: \(error)")
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                case .unverified:
                    print("StoreKit: unverified transaction")
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("StoreKit purchase error: \(error)")
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            print("StoreKit restore error: \(error)")
        }
    }
}
