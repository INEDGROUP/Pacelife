import Foundation

struct Checkin: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var energy: Int
    var sleepHours: Double?
    var mood: Int?
    var notes: String?
    var checkedInAt: Date
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case energy
        case sleepHours = "sleep_hours"
        case mood
        case notes
        case checkedInAt = "checked_in_at"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        energy = try container.decode(Int.self, forKey: .energy)
        sleepHours = try container.decodeIfPresent(Double.self, forKey: .sleepHours)
        mood = try container.decodeIfPresent(Int.self, forKey: .mood)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoFormatterNoFraction = ISO8601DateFormatter()
        isoFormatterNoFraction.formatOptions = [.withInternetDateTime]

        func parseDate(_ string: String) -> Date {
            if let date = isoFormatter.date(from: string) { return date }
            if let date = isoFormatterNoFraction.date(from: string) { return date }
            let spaceFormatter = DateFormatter()
            spaceFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
            spaceFormatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = spaceFormatter.date(from: string) { return date }
            spaceFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
            if let date = spaceFormatter.date(from: string) { return date }
            return Date()
        }

        let checkedInStr = try container.decode(String.self, forKey: .checkedInAt)
        checkedInAt = parseDate(checkedInStr)

        let createdStr = try container.decode(String.self, forKey: .createdAt)
        createdAt = parseDate(createdStr)
    }
}
