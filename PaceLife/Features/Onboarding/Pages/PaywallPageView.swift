import SwiftUI

struct PaywallPageView: View {
    let onComplete: () -> Void
    @State private var appeared = false
    @State private var selectedPlan: Plan = .annual

    enum Plan: String, CaseIterable {
        case monthly = "Monthly"
        case annual = "Annual"

        var price: String {
            switch self {
            case .monthly: return "£8.99"
            case .annual: return "£59.99"
            }
        }

        var period: String {
            switch self {
            case .monthly: return "per month"
            case .annual: return "per year · save 44%"
            }
        }

        var monthlyEquivalent: String? {
            switch self {
            case .annual: return "£5.00/mo"
            default: return nil
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text("Start your\nfree trial")
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

                    Text("7 days free, then choose your plan")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)
                }

                VStack(spacing: 10) {
                    ForEach(Plan.allCases, id: \.self) { plan in
                        OnboardingPlanCard(
                            plan: plan,
                            isSelected: selectedPlan == plan
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPlan = plan
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.75)
                            .delay(plan == .monthly ? 0.3 : 0.4),
                            value: appeared
                        )
                    }
                }

                VStack(spacing: 8) {
                    FeatureRow(icon: "sparkles", text: "AI-powered daily energy coaching")
                    FeatureRow(icon: "map.fill", text: "Personalised city routes")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Weekly insights & patterns")
                    FeatureRow(icon: "bell.fill", text: "Smart energy alerts")
                }
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.45), value: appeared)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                PLPrimaryButton(title: "Start 7-Day Free Trial", icon: "arrow.right") {
                    onComplete()
                }

                HStack(spacing: 16) {
                    Text("Cancel anytime")
                    Text("·")
                    Text("No commitment")
                    Text("·")
                    Text("Restore purchases")
                }
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.plTextTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.55), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

struct OnboardingPlanCard: View {
    let plan: PaywallPageView.Plan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.rawValue)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)

                        if plan == .annual {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.plBg)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.plGreen)
                                .clipShape(Capsule())
                        }
                    }

                    Text(plan.period)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.plGreen : Color.plTextPrimary)

                    if let equiv = plan.monthlyEquivalent {
                        Text(equiv)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.plGreen)
                    }
                }

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.plGreen : Color.plBorder, lineWidth: isSelected ? 2 : 0.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.plGreen)
                            .frame(width: 12, height: 12)
                            .transition(.scale)
                    }
                }
                .padding(.leading, 8)
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
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.plGreen)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.plTextSecondary)
            Spacer()
        }
    }
}
