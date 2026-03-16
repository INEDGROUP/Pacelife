import Foundation
import Supabase

class ProfileService {
    static let shared = ProfileService()
    private let client = SupabaseManager.shared.client

    func fetchProfile(userId: UUID) async throws -> UserProfile {
        let profile: UserProfile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.supabaseString)
            .single()
            .execute()
            .value
        return profile
    }

    func updateProfile(userId: UUID, name: String, goals: [String]) async throws {
        try await client
            .from("profiles")
            .update([
                "name": AnyJSON.string(name),
                "goals": AnyJSON.array(goals.map { AnyJSON.string($0) })
            ])
            .eq("id", value: userId.supabaseString)
            .execute()
    }
}
