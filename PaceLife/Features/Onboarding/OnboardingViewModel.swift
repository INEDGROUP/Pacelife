import SwiftUI
import Combine

class OnboardingViewModel: ObservableObject {
    @Published var userName: String = ""
    @Published var selectedGoals: Set<LifeGoal> = []

    enum LifeGoal: String, CaseIterable, Identifiable {
        case energy = "Boost Energy"
        case sleep = "Better Sleep"
        case movement = "Move More"
        case focus = "Deep Focus"
        case stress = "Less Stress"
        case habits = "Build Habits"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .energy: return "bolt.fill"
            case .sleep: return "moon.stars.fill"
            case .movement: return "figure.walk"
            case .focus: return "brain.head.profile"
            case .stress: return "leaf.fill"
            case .habits: return "checkmark.seal.fill"
            }
        }

        var color: Color {
            switch self {
            case .energy: return .plAmber
            case .sleep: return .plBlue
            case .movement: return .plGreen
            case .focus: return Color(hex: "B088FF")
            case .stress: return Color(hex: "5ECFA8")
            case .habits: return Color(hex: "FF8C69")
            }
        }
    }
}
