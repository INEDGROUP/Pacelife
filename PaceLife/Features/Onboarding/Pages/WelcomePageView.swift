import SwiftUI

struct WelcomePageView: View {
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.plGreen.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .scaleEffect(appeared ? 1.0 : 0.5)

                    Circle()
                        .fill(Color.plGreen.opacity(0.08))
                        .frame(width: 160, height: 160)
                        .scaleEffect(appeared ? 1.0 : 0.3)

                    Image(systemName: "figure.walk.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.plGreen)
                        .scaleEffect(appeared ? 1.0 : 0.3)
                        .opacity(appeared ? 1 : 0)
                }
                .animation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.1), value: appeared)

                VStack(spacing: 12) {
                    Text("PaceLife")
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: appeared)

                    Text("Your city.\nYour rhythm.\nYour energy.")
                        .font(.system(size: 20, weight: .light, design: .rounded))
                        .foregroundStyle(Color.plTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appeared)
                }
            }

            Spacer()
            Spacer()

            VStack(spacing: 16) {
                PLPrimaryButton(title: "Get Started", icon: "arrow.right") {
                    onNext()
                }

                Text("Free 7-day trial · then £8.99/month")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.55), value: appeared)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear { appeared = true }
    }
}
