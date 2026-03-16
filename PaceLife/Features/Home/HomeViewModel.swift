import Foundation
import SwiftUI
import CoreLocation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var todayCheckin: Checkin?
    @Published var latestCheckin: Checkin?
    @Published var weekCheckins: [Checkin] = []
    @Published var _hasCheckedInToday = false
    @Published var isLoading = false

    var hasCheckedInToday: Bool {
        get { _hasCheckedInToday }
        set { _hasCheckedInToday = newValue }
    }
    @Published var hasLoadedOnce = false
    @Published var suggestedRoute: SuggestedRoute?
    @Published var todaySteps: Int = 0

    var energyScore: Int {
        todayCheckin?.energy ?? latestCheckin?.energy ?? 0
    }

    var sleepHours: Double {
        todayCheckin?.sleepHours ?? latestCheckin?.sleepHours ?? 0
    }

    var moodValue: Int {
        todayCheckin?.mood ?? latestCheckin?.mood ?? 0
    }

    var moodText: String {
        switch moodValue {
        case 5: return "Amazing"
        case 4: return "Great"
        case 3: return "Good"
        case 2: return "Meh"
        case 1: return "Low"
        default: return "—"
        }
    }

    var moodEmoji: String {
        switch moodValue {
        case 5: return "🤩"
        case 4: return "😄"
        case 3: return "😊"
        case 2: return "😕"
        case 1: return "😔"
        default: return "—"
        }
    }

    var energyTrend: String {
        guard weekCheckins.count >= 2 else { return "" }
        let latest = weekCheckins.last?.energy ?? 0
        let previous = weekCheckins[weekCheckins.count - 2].energy
        if latest > previous { return "+\(latest - previous) vs yesterday" }
        if latest < previous { return "\(latest - previous) vs yesterday" }
        return "same as yesterday"
    }

    var sleepTrend: String {
        guard let sleep = todayCheckin?.sleepHours ?? latestCheckin?.sleepHours else { return "—" }
        if sleep >= 8 { return "great" }
        if sleep >= 7 { return "good" }
        if sleep >= 6 { return "fair" }
        return "low"
    }

    func loadHealthData() async {
        let healthKit = HealthKitService.shared
        await healthKit.fetchTodaySteps()
        todaySteps = healthKit.todaySteps
    }

    func loadData() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        let previousCheckin = todayCheckin
        let previousHasCheckedIn = _hasCheckedInToday
        isLoading = true

        todayCheckin = try? await HomeService.shared.fetchTodayCheckin(userId: userId)
        latestCheckin = try? await HomeService.shared.fetchLatestCheckin(userId: userId)
        weekCheckins = (try? await HomeService.shared.fetchWeekCheckins(userId: userId)) ?? []

        if todayCheckin == nil && previousCheckin != nil {
            todayCheckin = previousCheckin
            _hasCheckedInToday = previousHasCheckedIn
            latestCheckin = previousCheckin
        } else {
            _hasCheckedInToday = todayCheckin != nil
        }

        await loadHealthData()

        if let location = LocationManager.shared?.userLocation {
            await WeatherService.shared.fetchWeather(
                lat: location.latitude,
                lng: location.longitude
            )
        }

        let spots = (try? await SpotService.shared.fetchSpots(userId: userId)) ?? []

        let weather = WeatherService.shared
        suggestedRoute = SuggestedRoute.generate(
            energy: energyScore,
            steps: todaySteps,
            weatherTemp: weather.currentTemp,
            weatherCondition: weather.currentCondition,
            isGoodWeather: weather.isGoodForWalking,
            walkingAdvice: weather.walkingAdvice,
            weatherSummary: weather.weatherSummary,
            userSpots: spots
        )

        hasLoadedOnce = true
        isLoading = false
    }
}

struct SuggestedRoute {
    let title: String
    let distanceKm: Double
    let durationMinutes: Int
    let intensity: String
    let description: String
    let icon: String

    static func generate(
        energy: Int,
        steps: Int = 0,
        weatherTemp: Int? = nil,
        weatherCondition: String? = nil,
        isGoodWeather: Bool = true,
        walkingAdvice: String = "",
        weatherSummary: String = "",
        userSpots: [Spot] = []
    ) -> SuggestedRoute {
        let hour = Calendar.current.component(.hour, from: Date())
        let temp = weatherTemp ?? 15
        let weatherStr = weatherSummary

        if energy == 0 {
            return SuggestedRoute(
                title: "Log a check-in first",
                distanceKm: 0,
                durationMinutes: 0,
                intensity: "—",
                description: "We will suggest the perfect route based on your energy and conditions",
                icon: "figure.walk"
            )
        }

        if !isGoodWeather {
            return SuggestedRoute(
                title: "Rest day — poor conditions",
                distanceKm: 0,
                durationMinutes: 0,
                intensity: "—",
                description: walkingAdvice.isEmpty ? "Not ideal for outdoor activity today" : walkingAdvice,
                icon: "cloud.rain.fill"
            )
        }

        let nearbySpot = userSpots.first
        let spotSuffix = nearbySpot != nil ? " via \(nearbySpot!.title)" : ""

        switch (energy, hour) {
        case (80...100, 5..<10):
            return SuggestedRoute(
                title: "Power morning run\(spotSuffix)",
                distanceKm: 5.0,
                durationMinutes: 28,
                intensity: "high",
                description: "Energy at \(energy)\(weatherStr.isEmpty ? "" : " and \(weatherStr)") — perfect for a strong run",
                icon: "figure.run"
            )
        case (80...100, 10..<14):
            return SuggestedRoute(
                title: "Energetic city walk\(spotSuffix)",
                distanceKm: 3.5,
                durationMinutes: 40,
                intensity: "medium",
                description: "\(weatherStr.isEmpty ? "Great energy" : "Great energy and \(weatherStr)") — explore your city",
                icon: "figure.walk"
            )
        case (80...100, 14..<19):
            return SuggestedRoute(
                title: "Afternoon explorer\(spotSuffix)",
                distanceKm: 4.0,
                durationMinutes: 45,
                intensity: "medium",
                description: temp > 22 ? "Warm afternoon — stay hydrated on your walk" : "Good conditions for an afternoon route",
                icon: "figure.walk"
            )
        case (60...79, _):
            return SuggestedRoute(
                title: steps > 5000 ? "Evening wind-down\(spotSuffix)" : "Easy neighbourhood loop\(spotSuffix)",
                distanceKm: steps > 5000 ? 1.5 : 2.0,
                durationMinutes: steps > 5000 ? 18 : 24,
                intensity: "low",
                description: steps > 5000 ? "\(steps.formatted()) steps done — a short walk to finish the day" : "Gentle movement to maintain your energy level",
                icon: "figure.walk"
            )
        case (40...59, _):
            return SuggestedRoute(
                title: "Recovery stroll\(spotSuffix)",
                distanceKm: 1.2,
                durationMinutes: 15,
                intensity: "low",
                description: "Low energy today. \(weatherStr.isEmpty ? "Short walks help recovery." : "\(weatherStr.capitalized) — a short walk outside helps.")",
                icon: "figure.walk"
            )
        default:
            return SuggestedRoute(
                title: "Rest day",
                distanceKm: 0.5,
                durationMinutes: 8,
                intensity: "low",
                description: "Very low energy. Just step outside briefly — fresh air helps recovery.",
                icon: "moon.stars.fill"
            )
        }
    }
}
