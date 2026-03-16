import Foundation
import WeatherKit
import CoreLocation

@MainActor
class WeatherService: ObservableObject {
    static let shared = WeatherService()

    @Published var currentTemp: Int?
    @Published var currentCondition: String?
    @Published var weatherIcon: String?
    @Published var isGoodForWalking: Bool = true
    @Published var feelsLike: Int?
    @Published var uvIndex: Int?

    private init() {}

    func fetchWeather(lat: Double, lng: Double) async {
        let location = CLLocation(latitude: lat, longitude: lng)
        do {
            let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            currentTemp = Int(current.temperature.converted(to: .celsius).value)
            feelsLike = Int(current.apparentTemperature.converted(to: .celsius).value)
            uvIndex = Int(current.uvIndex.value)
            currentCondition = current.condition.description
            weatherIcon = current.symbolName

            let badConditions: [WeatherCondition] = [
                .heavyRain, .rain, .drizzle, .heavySnow, .snow,
                .thunderstorms, .tropicalStorm, .hurricane, .hail
            ]
            let temp = currentTemp ?? 15
            isGoodForWalking = !badConditions.contains(current.condition) && temp > 5 && temp < 35
        } catch {
            print("WeatherKit error: \(error)")
        }
    }

    var weatherSummary: String {
        guard let temp = currentTemp, let condition = currentCondition else {
            return "weather unknown"
        }
        return "\(temp)°C, \(condition.lowercased())"
    }

    var walkingAdvice: String {
        guard let temp = currentTemp else { return "" }
        if !isGoodForWalking {
            return "Poor conditions for outdoor activity"
        }
        if temp < 10 { return "Cold but fine for a brisk walk — dress warm" }
        if temp > 28 { return "Hot outside — walk early morning or evening" }
        return "Great conditions for outdoor activity"
    }
}
