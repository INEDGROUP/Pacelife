import SwiftUI

struct NamePageView: View {
    @Binding var name: String
    let onNext: () -> Void
    @State private var appeared = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("What should we\ncall you?")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

                    Text("We'll personalise everything for you")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)
                }

                VStack(spacing: 8) {
                    TextField("Your first name", text: $name)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .submitLabel(.continue)
                        .onSubmit { if !name.isEmpty { onNext() } }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 24)
                        .background(Color.plBgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: PLRadius.lg)
                                .strokeBorder(
                                    isFocused ? Color.plGreen.opacity(0.5) : Color.plBorder,
                                    lineWidth: isFocused ? 1 : 0.5
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: isFocused)

                    if !name.isEmpty {
                        Text("Nice to meet you, \(name) 👋")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.plGreen)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appeared)
            }
            .padding(.horizontal, 24)

            Spacer()

            PLPrimaryButton(
                title: name.isEmpty ? "Skip for now" : "Continue",
                icon: "arrow.right"
            ) {
                onNext()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.45), value: appeared)
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isFocused = true
            }
        }
    }
}
