import Foundation
import Supabase

class RouteService {
    static let shared = RouteService()
    private let client = SupabaseManager.shared.client

    func fetchRoutes(userId: UUID) async throws -> [PLRoute] {
        let routes: [PLRoute] = try await client
            .from("routes")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return routes
    }

    func saveRoute(userId: UUID, title: String, distanceKm: Double, durationMinutes: Int, intensity: String, coordinates: [[Double]]) async throws -> PLRoute {
        struct NewRoute: Encodable {
            let user_id: String
            let title: String
            let distance_km: Double
            let duration_minutes: Int
            let intensity: String
            let coordinates: [[Double]]
            let completed_at: String
            let calories: Int
        }
        let weightKg = await MainActor.run { UserManager.shared.profile?.weightKg ?? 70 }
        let caloriesBurned = Int(distanceKm * weightKg * 1.036)
        let route: PLRoute = try await client
            .from("routes")
            .insert(NewRoute(
                user_id: userId.supabaseString,
                title: title,
                distance_km: distanceKm,
                duration_minutes: durationMinutes,
                intensity: intensity,
                coordinates: coordinates,
                completed_at: ISO8601DateFormatter().string(from: Date()),
                calories: caloriesBurned
            ))
            .select()
            .single()
            .execute()
            .value
        return route
    }

    func deleteRoute(routeId: UUID, userId: UUID) async throws {
        try await client
            .from("routes")
            .delete()
            .eq("id", value: routeId.supabaseString)
            .eq("user_id", value: userId.supabaseString)
            .execute()
    }

    func renameRoute(routeId: UUID, userId: UUID, title: String) async throws {
        try await client
            .from("routes")
            .update(["title": AnyJSON.string(title)])
            .eq("id", value: routeId.supabaseString)
            .eq("user_id", value: userId.supabaseString)
            .execute()
    }
}
