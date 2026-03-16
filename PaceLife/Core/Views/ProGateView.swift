import SwiftUI

struct ProGateView: View {
    let feature: String
    let icon: String
    let description: String
    @State private var showPaywall = false
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.plGreen.opacity(0.1))
                    .frame(width: 90, height: 90)
                Circle()
                    .fill(Color.plGreen.opacity(0.05))
                    .frame(width: 120, height: 120)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.plGreen, Color(hex: "6B8FFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 10) {
                Text(feature)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                PLPrimaryButton(
                    title: userManager.isTrialActive ? "Upgrade to Pro" : "Start Free Trial",
                    icon: "sparkles"
                ) {
                    showPaywall = true
                }
                .padding(.horizontal, 32)

                if userManager.isTrialActive {
                    Text("\(userManager.trialDaysLeft) days left in your trial")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.plAmber)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.plBg)
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
                .environmentObject(userManager)
        }
    }
}
