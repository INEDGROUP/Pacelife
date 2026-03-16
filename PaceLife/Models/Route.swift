import Foundation

struct PLRoute: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var title: String
    var distanceKm: Double?
    var durationMinutes: Int?
    var intensity: String?
    var coordinates: [[Double]]
    var completedAt: Date?
    var calories: Int?
    var averagePace: Double?
    var elevationGain: Double?
    var weatherCondition: String?
    var weatherTemp: Int?
    var notes: String?
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case distanceKm = "distance_km"
        case durationMinutes = "duration_minutes"
        case intensity
        case coordinates
        case completedAt = "completed_at"
        case calories
        case averagePace = "average_pace"
        case elevationGain = "elevation_gain"
        case weatherCondition = "weather_condition"
        case weatherTemp = "weather_temp"
        case notes
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        distanceKm = try container.decodeIfPresent(Double.self, forKey: .distanceKm)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        intensity = try container.decodeIfPresent(String.self, forKey: .intensity)
        coordinates = (try? container.decode([[Double]].self, forKey: .coordinates)) ?? []
        calories = try container.decodeIfPresent(Int.self, forKey: .calories)
        averagePace = try container.decodeIfPresent(Double.self, forKey: .averagePace)
        elevationGain = try container.decodeIfPresent(Double.self, forKey: .elevationGain)
        weatherCondition = try container.decodeIfPresent(String.self, forKey: .weatherCondition)
        weatherTemp = try container.decodeIfPresent(Int.self, forKey: .weatherTemp)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isFavorite = (try? container.decode(Bool.self, forKey: .isFavorite)) ?? false

        func parseDate(_ str: String) -> Date {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f1.date(from: str) { return d }
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            if let d = f2.date(from: str) { return d }
            let f3 = DateFormatter()
            f3.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
            f3.locale = Locale(identifier: "en_US_POSIX")
            return f3.date(from: str) ?? Date()
        }

        completedAt = nil
        updatedAt = nil

        if let str = try? container.decode(String.self, forKey: .completedAt) {
            completedAt = parseDate(str)
        }
        if let str = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = parseDate(str)
        }
        if let str = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = parseDate(str)
        } else {
            createdAt = Date()
        }
    }
}
