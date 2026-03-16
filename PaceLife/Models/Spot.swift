import Foundation
import CoreLocation

struct Spot: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var title: String
    var category: String?
    var latitude: Double
    var longitude: Double
    var notes: String?
    var emoji: String?
    var visitCount: Int
    var lastVisitedAt: Date?
    var createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case category
        case latitude
        case longitude
        case notes
        case emoji
        case visitCount = "visit_count"
        case lastVisitedAt = "last_visited_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        visitCount = (try? container.decode(Int.self, forKey: .visitCount)) ?? 0
        lastVisitedAt = nil
        updatedAt = nil

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterNoFraction = ISO8601DateFormatter()
        isoFormatterNoFraction.formatOptions = [.withInternetDateTime]

        func parseDate(_ str: String) -> Date {
            if let d = isoFormatter.date(from: str) { return d }
            if let d = isoFormatterNoFraction.date(from: str) { return d }
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f.date(from: str) ?? Date()
        }

        if let str = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = parseDate(str)
        } else {
            createdAt = Date()
        }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
