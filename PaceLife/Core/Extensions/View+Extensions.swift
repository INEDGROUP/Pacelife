import SwiftUI

extension View {
    func plCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.plBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(Color.plBorder, lineWidth: 0.5)
            )
    }

    func plAccentCard(color: Color = .plGreen, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.plBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
            )
    }

    func plSectionLabel() -> some View {
        self
            .font(.plMicro)
            .foregroundColor(.plTextTertiary)
            .tracking(1.0)
            .textCase(.uppercase)
    }
}
