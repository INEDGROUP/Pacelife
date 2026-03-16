import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var name: String?
    var goals: [String]
    var energyBaseline: Int
    var avatarUrl: String?
    var dateOfBirth: Date?
    var gender: String?
    var heightCm: Int?
    var weightKg: Double?
    var city: String?
    var country: String?
    var timezone: String?
    var lastLocationLat: Double?
    var lastLocationLng: Double?
    var lastSeenAt: Date?
    var streakDays: Int
    var totalCheckins: Int
    var totalDistanceKm: Double
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case goals
        case energyBaseline = "energy_baseline"
        case avatarUrl = "avatar_url"
        case dateOfBirth = "date_of_birth"
        case gender
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case city
        case country
        case timezone
        case lastLocationLat = "last_location_lat"
        case lastLocationLng = "last_location_lng"
        case lastSeenAt = "last_seen_at"
        case streakDays = "streak_days"
        case totalCheckins = "total_checkins"
        case totalDistanceKm = "total_distance_km"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        goals = (try? container.decode([String].self, forKey: .goals)) ?? []
        energyBaseline = (try? container.decode(Int.self, forKey: .energyBaseline)) ?? 70
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        heightCm = try container.decodeIfPresent(Int.self, forKey: .heightCm)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        lastLocationLat = try container.decodeIfPresent(Double.self, forKey: .lastLocationLat)
        lastLocationLng = try container.decodeIfPresent(Double.self, forKey: .lastLocationLng)
        streakDays = (try? container.decode(Int.self, forKey: .streakDays)) ?? 0
        totalCheckins = (try? container.decode(Int.self, forKey: .totalCheckins)) ?? 0
        totalDistanceKm = (try? container.decode(Double.self, forKey: .totalDistanceKm)) ?? 0

        if let dobString = try container.decodeIfPresent(String.self, forKey: .dateOfBirth) {
            let shortFormatter = DateFormatter()
            shortFormatter.dateFormat = "yyyy-MM-dd"
            shortFormatter.locale = Locale(identifier: "en_US_POSIX")
            shortFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

            if let date = shortFormatter.date(from: dobString) {
                dateOfBirth = date
            } else if let date = isoFormatter.date(from: dobString) {
                dateOfBirth = date
            } else {
                dateOfBirth = nil
            }
        } else {
            dateOfBirth = nil
        }

        if let lastSeenString = try container.decodeIfPresent(String.self, forKey: .lastSeenAt) {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            lastSeenAt = isoFormatter.date(from: lastSeenString)
        } else {
            lastSeenAt = nil
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let createdStr = try? container.decode(String.self, forKey: .createdAt),
           let date = isoFormatter.date(from: createdStr) {
            createdAt = date
        } else {
            createdAt = Date()
        }

        if let updatedStr = try? container.decode(String.self, forKey: .updatedAt),
           let date = isoFormatter.date(from: updatedStr) {
            updatedAt = date
        } else {
            updatedAt = Date()
        }
    }

    init(id: UUID, name: String?, goals: [String], energyBaseline: Int,
         avatarUrl: String?, dateOfBirth: Date?, gender: String?,
         heightCm: Int?, weightKg: Double?, city: String?, country: String?,
         timezone: String?, lastLocationLat: Double?, lastLocationLng: Double?,
         lastSeenAt: Date?, streakDays: Int, totalCheckins: Int,
         totalDistanceKm: Double, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.goals = goals
        self.energyBaseline = energyBaseline
        self.avatarUrl = avatarUrl
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.city = city
        self.country = country
        self.timezone = timezone
        self.lastLocationLat = lastLocationLat
        self.lastLocationLng = lastLocationLng
        self.lastSeenAt = lastSeenAt
        self.streakDays = streakDays
        self.totalCheckins = totalCheckins
        self.totalDistanceKm = totalDistanceKm
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
