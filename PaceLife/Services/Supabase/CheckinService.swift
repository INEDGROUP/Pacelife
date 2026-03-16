import Foundation
import Supabase

class CheckinService {
    static let shared = CheckinService()
    private let client = SupabaseManager.shared.client

    func saveCheckin(userId: UUID, energy: Int, sleepHours: Double?, mood: Int?, notes: String?) async throws -> Checkin {
        struct NewCheckin: Encodable {
            let user_id: String
            let energy: Int
            let sleep_hours: Double?
            let mood: Int?
            let notes: String?
        }

        let checkin: Checkin = try await client
            .from("checkins")
            .insert(NewCheckin(
                user_id: userId.supabaseString,
                energy: energy,
                sleep_hours: sleepHours,
                mood: mood,
                notes: notes
            ))
            .select()
            .single()
            .execute()
            .value
        return checkin
    }

    func fetchRecentCheckins(userId: UUID, limit: Int = 7) async throws -> [Checkin] {
        let checkins: [Checkin] = try await client
            .from("checkins")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .order("checked_in_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return checkins
    }

    func hasTodayCheckin(userId: UUID) async throws -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        let todayStr = formatter.string(from: today)

        let checkins: [Checkin] = try await client
            .from("checkins")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .gte("checked_in_at", value: todayStr)
            .execute()
            .value
        return !checkins.isEmpty
    }
}
