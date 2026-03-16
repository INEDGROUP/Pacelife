import Foundation

struct Subscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var status: String
    var plan: String
    var trialStartedAt: Date?
    var trialEndsAt: Date?
    var currentPeriodStart: Date?
    var currentPeriodEnd: Date?
    var appleOriginalTransactionId: String?
    var appleProductId: String?
    var cancelAtPeriodEnd: Bool
    var cancelledAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case status
        case plan
        case trialStartedAt = "trial_started_at"
        case trialEndsAt = "trial_ends_at"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case appleOriginalTransactionId = "apple_original_transaction_id"
        case appleProductId = "apple_product_id"
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case cancelledAt = "cancelled_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        status = try container.decode(String.self, forKey: .status)
        plan = try container.decode(String.self, forKey: .plan)
        appleOriginalTransactionId = try container.decodeIfPresent(String.self, forKey: .appleOriginalTransactionId)
        appleProductId = try container.decodeIfPresent(String.self, forKey: .appleProductId)
        cancelAtPeriodEnd = (try? container.decode(Bool.self, forKey: .cancelAtPeriodEnd)) ?? false
        cancelledAt = nil

        func parseDate(_ key: CodingKeys) -> Date? {
            guard let s = (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil else { return nil }
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f1.date(from: s) { return d }
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            if let d = f2.date(from: s) { return d }
            let f3 = DateFormatter()
            f3.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
            f3.locale = Locale(identifier: "en_US_POSIX")
            return f3.date(from: s)
        }

        trialStartedAt = parseDate(.trialStartedAt)
        trialEndsAt = parseDate(.trialEndsAt)
        currentPeriodStart = parseDate(.currentPeriodStart)
        currentPeriodEnd = parseDate(.currentPeriodEnd)
        createdAt = parseDate(.createdAt) ?? Date()
        updatedAt = parseDate(.updatedAt) ?? Date()
    }
}
