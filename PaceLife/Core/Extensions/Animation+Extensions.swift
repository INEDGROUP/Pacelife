import SwiftUI

extension AnyTransition {
    static var plSlideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    static var plFade: AnyTransition {
        .opacity.animation(.easeInOut(duration: 0.25))
    }
}
