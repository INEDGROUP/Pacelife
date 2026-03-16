import SwiftUI

enum SpotCategory: String, CaseIterable, Identifiable {
    case park = "park"
    case cafe = "cafe"
    case gym = "gym"
    case trail = "trail"
    case viewpoint = "viewpoint"
    case relax = "relax"
    case focus = "focus"
    case energy = "energy"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .park: return "Park"
        case .cafe: return "Café"
        case .gym: return "Gym"
        case .trail: return "Trail"
        case .viewpoint: return "Viewpoint"
        case .relax: return "Relax"
        case .focus: return "Focus"
        case .energy: return "Energy"
        }
    }

    var icon: String {
        switch self {
        case .park: return "leaf.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .gym: return "bolt.heart.fill"
        case .trail: return "figure.walk"
        case .viewpoint: return "binoculars.fill"
        case .relax: return "bed.double.fill"
        case .focus: return "brain.head.profile"
        case .energy: return "bolt.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .park: return [Color(hex: "4CFFA0"), Color(hex: "00C875")]
        case .cafe: return [Color(hex: "C68642"), Color(hex: "8B5E3C")]
        case .gym: return [Color(hex: "FF6B35"), Color(hex: "FF4500")]
        case .trail: return [Color(hex: "6B8FFF"), Color(hex: "4A6FF5")]
        case .viewpoint: return [Color(hex: "FFD700"), Color(hex: "FF9500")]
        case .relax: return [Color(hex: "B088FF"), Color(hex: "7B4FFF")]
        case .focus: return [Color(hex: "5ECFA8"), Color(hex: "00A878")]
        case .energy: return [Color(hex: "FFD700"), Color(hex: "FF6B35")]
        }
    }

    static func from(_ string: String?) -> SpotCategory {
        guard let string = string else { return .park }
        return SpotCategory(rawValue: string) ?? .park
    }
}
