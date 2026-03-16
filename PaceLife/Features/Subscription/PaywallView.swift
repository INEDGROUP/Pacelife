import SwiftUI
import StoreKit

struct PaywallView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var userManager: UserManager
    @StateObject private var storeKit = StoreKitService.shared
    @State private var selectedProductID = "com.inedgroup.pacelife.annual"
    @State private var appeared = false
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorText = ""
    @State private var purchaseSuccess = false

    var body: some View {
        ZStack {
            Color.plBg.ignoresSafeArea()
            AnimatedBackgroundView()

            if purchaseSuccess {
                successView
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.plTextTertiary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            headerSection
                            plansSection
                            featuresSection
                            buttonsSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            appeared = true
            Task { await storeKit.loadProducts() }
        }
        .alert("Purchase failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorText)
        }
    }

    var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.plGreen.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.plGreen)
            }
            .scaleEffect(purchaseSuccess ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: purchaseSuccess)

            VStack(spacing: 8) {
                Text("Welcome to Pro!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                Text("Your 7-day free trial has started.\nEnjoy unlimited access to PaceLife.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            PLPrimaryButton(title: "Start exploring", icon: "arrow.right") {
                isPresented = false
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.plGreen.opacity(0.1))
                    .frame(width: 90, height: 90)
                Circle()
                    .fill(Color.plGreen.opacity(0.06))
                    .frame(width: 120, height: 120)
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.plGreen, Color(hex: "6B8FFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.5)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)

            VStack(spacing: 8) {
                Text("PaceLife Pro")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)

                if userManager.isTrialActive {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.plAmber)
                        Text("\(userManager.trialDaysLeft) days left in your free trial")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.plAmber)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.plAmber.opacity(0.1))
                    .clipShape(Capsule())
                } else {
                    Text("Unlock your full potential")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)
        }
    }

    var plansSection: some View {
        VStack(spacing: 10) {
            if storeKit.isLoading && storeKit.products.isEmpty {
                ProgressView()
                    .tint(Color.plGreen)
                    .frame(height: 120)
            } else if storeKit.products.isEmpty {
                VStack(spacing: 10) {
                    Text("Unable to load products")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                    Button("Retry") {
                        Task { await storeKit.loadProducts() }
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plGreen)
                }
                .frame(height: 120)
            } else {
                ForEach(storeKit.products, id: \.id) { product in
                    StoreKitPlanCard(
                        product: product,
                        isSelected: selectedProductID == product.id,
                        isAnnual: product.id.contains("annual")
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedProductID = product.id
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appeared)
    }

    var featuresSection: some View {
        VStack(spacing: 10) {
            PLFeatureRow(icon: "sparkles", text: "AI-powered daily energy coaching")
            PLFeatureRow(icon: "map.fill", text: "Personalised city routes with weather")
            PLFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Weekly insights and energy patterns")
            PLFeatureRow(icon: "bell.fill", text: "Smart notifications and streak alerts")
            PLFeatureRow(icon: "flame.fill", text: "Streak tracking and achievements")
            PLFeatureRow(icon: "heart.fill", text: "Apple Health integration")
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appeared)
    }

    var buttonsSection: some View {
        VStack(spacing: 14) {
            PLPrimaryButton(
                title: isPurchasing ? "Processing..." : "Start 7-Day Free Trial",
                icon: isPurchasing ? "hourglass" : "arrow.right"
            ) {
                Task { await purchaseSelected() }
            }
            .disabled(isPurchasing || storeKit.products.isEmpty)
            .opacity(isPurchasing || storeKit.products.isEmpty ? 0.7 : 1)

            Button(action: {
                Task { await storeKit.restore() }
            }) {
                Text("Restore purchases")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }

            HStack(spacing: 10) {
                Button("Terms of Use") { }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
                Text("·")
                    .foregroundStyle(Color.plTextTertiary)
                    .font(.system(size: 11))
                Button("Privacy Policy") { }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
                Text("·")
                    .foregroundStyle(Color.plTextTertiary)
                    .font(.system(size: 11))
                Text("Cancel anytime")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appeared)
    }

    private func purchaseSelected() async {
        guard let product = storeKit.products.first(where: { $0.id == selectedProductID }) else {
            if let first = storeKit.products.first {
                selectedProductID = first.id
            }
            errorText = "Product not found. Please try again."
            showError = true
            return
        }
        isPurchasing = true
        do {
            if let _: StoreKit.Transaction = try await storeKit.purchase(product) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    purchaseSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    isPresented = false
                }
            }
        } catch {
            errorText = error.localizedDescription
            showError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        isPurchasing = false
    }
}

struct StoreKitPlanCard: View {
    let product: Product
    let isSelected: Bool
    let isAnnual: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(isAnnual ? "Annual" : "Monthly")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                        if isAnnual {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(Color.plBg)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.plGreen)
                                .clipShape(Capsule())
                        }
                    }
                    Text(isAnnual ? "per year · save 44%" : "per month · cancel anytime")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                    Text("7-day free trial included")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.plGreen.opacity(0.8))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(product.displayPrice)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.plGreen : Color.plTextPrimary)
                    if isAnnual {
                        Text("≈ \(annualMonthlyPrice)/mo")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.plGreen)
                    }
                }

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.plGreen : Color.plBorder,
                            lineWidth: isSelected ? 2 : 0.5
                        )
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(Color.plGreen)
                            .frame(width: 14, height: 14)
                            .transition(.scale)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .fill(isSelected ? Color.plGreen.opacity(0.08) : Color.plBgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(
                        isSelected ? Color.plGreen.opacity(0.4) : Color.plBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    var annualMonthlyPrice: String {
        let price = product.price
        let monthly = price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: monthly)) ?? "£5.00"
    }
}

private struct PLFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.plGreen)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.plTextSecondary)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.plGreen)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.plBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
    }
}
