import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.plBg.ignoresSafeArea()
            AnimatedBackgroundView()

            VStack(spacing: 0) {
                if currentPage < 4 {
                    OnboardingProgressBar(current: currentPage, total: 4)
                        .padding(.top, 60)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }

                TabView(selection: $currentPage) {
                    WelcomePageView(onNext: { advance() })
                        .tag(0)
                    NamePageView(name: $viewModel.userName, onNext: { advance() })
                        .tag(1)
                    GoalsPageView(selectedGoals: $viewModel.selectedGoals, onNext: { advance() })
                        .tag(2)
                    PermissionsPageView(onNext: { advance() })
                        .tag(3)
                    PaywallPageView(onComplete: { complete() })
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.82), value: currentPage)
            }
        }
    }

    private func advance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            currentPage += 1
        }
    }

    private func complete() {
        withAnimation(.easeInOut(duration: 0.4)) {
            hasCompletedOnboarding = true
        }
    }
}

struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.plGreen : Color.white.opacity(0.15))
                    .frame(height: 3)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: current)
            }
        }
    }
}

struct AnimatedBackgroundView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.plGreen.opacity(0.08), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            .scaleEffect(animate ? 1.2 : 1.0)
            .animation(
                .easeInOut(duration: 4).repeatForever(autoreverses: true),
                value: animate
            )

            RadialGradient(
                colors: [Color.plBlue.opacity(0.06), Color.clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()
            .scaleEffect(animate ? 1.0 : 1.15)
            .animation(
                .easeInOut(duration: 5).repeatForever(autoreverses: true),
                value: animate
            )
        }
        .onAppear { animate = true }
    }
}
