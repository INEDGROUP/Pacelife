import SwiftUI

extension Font {
    // MARK: - Display (New York serif - built into iOS)
    static func plDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    // MARK: - Body (SF Pro Rounded - built into iOS)
    static func plSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Preset styles
    static let plTitle = Font.plDisplay(26)
    static let plHeadline = Font.plSans(18, weight: .medium)
    static let plBody = Font.plSans(14)
    static let plCaption = Font.plSans(11)
    static let plMicro = Font.plSans(10)
}
