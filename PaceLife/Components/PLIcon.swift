import SwiftUI

struct PLIcon: View {
    let symbol: String
    let size: CGFloat
    let color: Color
    var backgroundOpacity: Double = 0.12
    var cornerRadius: CGFloat? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius ?? size * 0.35)
                .fill(color.opacity(backgroundOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius ?? size * 0.35)
                        .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                )
                .frame(width: size * 1.8, height: size * 1.8)

            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

struct PLGradientIcon: View {
    let symbol: String
    let size: CGFloat
    let colors: [Color]
    var cornerRadius: CGFloat? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius ?? size * 0.35)
                .fill(
                    LinearGradient(
                        colors: colors.map { $0.opacity(0.15) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius ?? size * 0.35)
                        .strokeBorder(
                            LinearGradient(
                                colors: colors.map { $0.opacity(0.3) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .frame(width: size * 1.8, height: size * 1.8)

            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

struct PLAnimatedFlame: View {
    let size: CGFloat
    @State private var animate = false

    var body: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .font(.system(size: size * 0.7, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FF6B35"), Color(hex: "FF9500")],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .scaleEffect(animate ? 1.08 : 0.95)
                .animation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: animate
                )
                .shadow(color: Color(hex: "FF6B35").opacity(0.4), radius: animate ? 8 : 4)
        }
        .frame(width: size, height: size)
        .onAppear { animate = true }
    }
}

struct PLMoodIndicator: View {
    let mood: Int
    let size: CGFloat

    var moodConfig: (symbol: String, colors: [Color]) {
        switch mood {
        case 5: return ("face.smiling.inverse", [Color(hex: "FFD700"), Color(hex: "FF9500")])
        case 4: return ("face.smiling", [Color(hex: "4CFFA0"), Color(hex: "00C875")])
        case 3: return ("face.smiling", [Color(hex: "6B8FFF"), Color(hex: "4A6FF5")])
        case 2: return ("minus.circle", [Color(hex: "FFB347"), Color(hex: "FF9500")])
        case 1: return ("cloud.rain", [Color(hex: "FF6B6B"), Color(hex: "FF4444")])
        default: return ("questionmark.circle", [Color.plTextTertiary, Color.plTextTertiary])
        }
    }

    var body: some View {
        PLGradientIcon(
            symbol: moodConfig.symbol,
            size: size,
            colors: moodConfig.colors
        )
    }
}
