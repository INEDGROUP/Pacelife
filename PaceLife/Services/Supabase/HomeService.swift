import Foundation
import Supabase

class HomeService {
    static let shared = HomeService()
    private let client = SupabaseManager.shared.client

    func fetchTodayCheckin(userId: UUID) async throws -> Checkin? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current

        let startStr = formatter.string(from: startOfDay)
        let endStr = formatter.string(from: endOfDay)

        let checkins: [Checkin] = try await client
            .from("checkins")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .gte("checked_in_at", value: startStr)
            .lt("checked_in_at", value: endStr)
            .order("checked_in_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return checkins.first
    }

    func fetchLatestCheckin(userId: UUID) async throws -> Checkin? {
        let checkins: [Checkin] = try await client
            .from("checkins")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .order("checked_in_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return checkins.first
    }

    func fetchWeekCheckins(userId: UUID) async throws -> [Checkin] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current

        let checkins: [Checkin] = try await client
            .from("checkins")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .gte("checked_in_at", value: formatter.string(from: weekAgo))
            .order("checked_in_at", ascending: true)
            .execute()
            .value
        return checkins
    }
}
