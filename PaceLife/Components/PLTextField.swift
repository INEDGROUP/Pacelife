import SwiftUI

struct PLTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isFocused ? Color.plGreen : Color.plTextTertiary)
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.2), value: isFocused)

            Group {
                if isSecure && !isRevealed {
                    SecureField(placeholder, text: $text)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .focused($isFocused)
                        .keyboardType(keyboardType)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .font(.system(size: 15, design: .rounded))
            .foregroundStyle(Color.plTextPrimary)

            if isSecure {
                Button(action: { isRevealed.toggle() }) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.plTextTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: PLRadius.lg)
                .fill(Color.plBgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: PLRadius.lg)
                        .stroke(isFocused ? Color.plGreen.opacity(0.5) : Color.plBorder, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
