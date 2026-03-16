import Foundation
import Supabase

class SpotService {
    static let shared = SpotService()
    private let client = SupabaseManager.shared.client

    func fetchSpots(userId: UUID) async throws -> [Spot] {
        let spots: [Spot] = try await client
            .from("spots")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return spots
    }

    func saveSpot(userId: UUID, title: String, category: String, latitude: Double, longitude: Double, notes: String?) async throws -> Spot {
        struct NewSpot: Encodable {
            let user_id: String
            let title: String
            let category: String
            let latitude: Double
            let longitude: Double
            let notes: String?
        }
        let spot: Spot = try await client
            .from("spots")
            .insert(NewSpot(
                user_id: userId.supabaseString,
                title: title,
                category: category,
                latitude: latitude,
                longitude: longitude,
                notes: notes
            ))
            .select()
            .single()
            .execute()
            .value
        return spot
    }

    func deleteSpot(spotId: UUID, userId: UUID) async throws {
        try await client
            .from("spots")
            .delete()
            .eq("id", value: spotId.supabaseString)
            .eq("user_id", value: userId.supabaseString)
            .execute()
    }

    func renameSpot(spotId: UUID, userId: UUID, title: String) async throws {
        try await client
            .from("spots")
            .update(["title": AnyJSON.string(title)])
            .eq("id", value: spotId.supabaseString)
            .eq("user_id", value: userId.supabaseString)
            .execute()
    }

    func incrementVisitCount(spotId: UUID, userId: UUID) async throws {
        try await client
            .from("spots")
            .update([
                "visit_count": AnyJSON.double(1),
                "last_visited_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
            ])
            .eq("id", value: spotId.supabaseString)
            .eq("user_id", value: userId.supabaseString)
            .execute()
    }
}
