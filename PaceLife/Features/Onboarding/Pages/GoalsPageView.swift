import SwiftUI

struct GoalsPageView: View {
    @Binding var selectedGoals: Set<OnboardingViewModel.LifeGoal>
    let onNext: () -> Void
    @State private var appeared = false

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("What do you want\nto improve?")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

                    Text("Pick as many as you like")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(OnboardingViewModel.LifeGoal.allCases.enumerated()), id: \.element.id) { index, goal in
                        GoalCard(
                            goal: goal,
                            isSelected: selectedGoals.contains(goal)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                if selectedGoals.contains(goal) {
                                    selectedGoals.remove(goal)
                                } else {
                                    selectedGoals.insert(goal)
                                }
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.75)
                            .delay(0.1 + Double(index) * 0.06),
                            value: appeared
                        )
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            PLPrimaryButton(
                title: selectedGoals.isEmpty ? "Skip for now" : "Continue (\(selectedGoals.count) selected)",
                icon: "arrow.right"
            ) {
                onNext()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

struct GoalCard: View {
    let goal: OnboardingViewModel.LifeGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                            ? LinearGradient(colors: [goal.color.opacity(0.2), goal.color.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.plBgTertiary, Color.plBgTertiary], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle()
                                .strokeBorder(isSelected ? goal.color.opacity(0.4) : Color.plBorder, lineWidth: 0.5)
                        )

                    Image(systemName: goal.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            isSelected
                            ? LinearGradient(colors: [goal.color, goal.color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.plTextTertiary, Color.plTextTertiary], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: isSelected ? goal.color.opacity(0.3) : .clear, radius: 6)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }

                Text(goal.rawValue)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.plTextPrimary : Color.plTextSecondary)
                    .multilineTextAlignment(.center)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(goal.color)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .fill(isSelected ? goal.color.opacity(0.06) : Color.plBgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(
                        isSelected ? goal.color.opacity(0.35) : Color.plBorder,
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
