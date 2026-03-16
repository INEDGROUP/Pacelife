import SwiftUI

struct PLTheme {
    static let shared = PLTheme()

    // Animation presets
    static let springSnappy = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let springSmooth = Animation.spring(response: 0.5, dampingFraction: 0.85)
    static let easeSmooth = Animation.easeInOut(duration: 0.3)
}
