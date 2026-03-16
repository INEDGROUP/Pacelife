import SwiftUI

struct PLPrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color.plBg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                Capsule()
                    .fill(Color.plGreen)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PLPressButtonStyle(isPressed: $isPressed))
    }
}

struct PLPressButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) {
                    isPressed = newValue
                }
            }
    }
}
