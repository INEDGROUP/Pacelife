import Foundation
import Supabase
import SwiftUI

@MainActor
class UserManager: ObservableObject {
    static let shared = UserManager()
    private let client = SupabaseManager.shared.client

    @Published var profile: UserProfile?
    @Published var subscription: Subscription?
    @Published var isLoading = false
    @Published var hasLoadedOnce = false

    private init() {}

    func loadUserData(userId: UUID) async {
        isLoading = true
        do {
            let fetchedProfile: UserProfile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId.supabaseString)
                .single()
                .execute()
                .value
            self.profile = fetchedProfile

            if let fetchedSub: Subscription = try? await client
                .from("subscriptions")
                .select()
                .eq("user_id", value: userId.supabaseString)
                .single()
                .execute()
                .value {
                self.subscription = fetchedSub
            }

            self.hasLoadedOnce = true
            print("UserManager: loaded profile for \(fetchedProfile.name ?? "unknown")")
        } catch {
            print("UserManager error: \(error)")
        }
        isLoading = false
    }

    func uploadAvatar(imageData: Data, userId: UUID) async throws -> String {
        let fileName = "\(userId.supabaseString)/avatar.jpg"
        let supabaseURL = "https://vhgnnujzcjjugbneuwhn.supabase.co"
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoZ25udWp6Y2pqdWdibmV1d2huIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1ODg5MDgsImV4cCI6MjA4OTE2NDkwOH0.JjtPfC3P1V-pAZ4UrHDSbTNvxIlNHlrL3TCKqfWo4EA"

        guard let session = try? await client.auth.session else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let accessToken = session.accessToken

        let uploadURLString = "\(supabaseURL)/storage/v1/object/avatars/\(fileName)"
        guard let uploadURL = URL(string: uploadURLString) else {
            throw NSError(domain: "URL", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("3600", forHTTPHeaderField: "x-upsert")
        request.httpBody = imageData
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("Avatar upload status: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 409 {
                var upsertRequest = URLRequest(url: uploadURL)
                upsertRequest.httpMethod = "PUT"
                upsertRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                upsertRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
                upsertRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                upsertRequest.httpBody = imageData
                upsertRequest.timeoutInterval = 30
                let (_, _) = try await URLSession.shared.data(for: upsertRequest)
            }
        }

        let publicURL = "\(supabaseURL)/storage/v1/object/public/avatars/\(fileName)?t=\(Int(Date().timeIntervalSince1970))"

        try await client
            .from("profiles")
            .update(["avatar_url": AnyJSON.string(publicURL)])
            .eq("id", value: userId.supabaseString)
            .execute()

        if let p = profile {
            profile = UserProfile(
                id: p.id, name: p.name, goals: p.goals,
                energyBaseline: p.energyBaseline, avatarUrl: publicURL,
                dateOfBirth: p.dateOfBirth, gender: p.gender,
                heightCm: p.heightCm, weightKg: p.weightKg,
                city: p.city, country: p.country, timezone: p.timezone,
                lastLocationLat: p.lastLocationLat, lastLocationLng: p.lastLocationLng,
                lastSeenAt: p.lastSeenAt, streakDays: p.streakDays,
                totalCheckins: p.totalCheckins, totalDistanceKm: p.totalDistanceKm,
                createdAt: p.createdAt, updatedAt: Date()
            )
        }

        return publicURL
    }

    func deleteAvatar(userId: UUID) async throws {
        let fileName = "\(userId.supabaseString)/avatar.jpg"
        try await client.storage
            .from("avatars")
            .remove(paths: [fileName])
        try await client
            .from("profiles")
            .update(["avatar_url": AnyJSON.string("")])
            .eq("id", value: userId.supabaseString)
            .execute()
        if var updatedProfile = profile {
            updatedProfile = UserProfile(
                id: updatedProfile.id,
                name: updatedProfile.name,
                goals: updatedProfile.goals,
                energyBaseline: updatedProfile.energyBaseline,
                avatarUrl: nil,
                dateOfBirth: updatedProfile.dateOfBirth,
                gender: updatedProfile.gender,
                heightCm: updatedProfile.heightCm,
                weightKg: updatedProfile.weightKg,
                city: updatedProfile.city,
                country: updatedProfile.country,
                timezone: updatedProfile.timezone,
                lastLocationLat: updatedProfile.lastLocationLat,
                lastLocationLng: updatedProfile.lastLocationLng,
                lastSeenAt: updatedProfile.lastSeenAt,
                streakDays: updatedProfile.streakDays,
                totalCheckins: updatedProfile.totalCheckins,
                totalDistanceKm: updatedProfile.totalDistanceKm,
                createdAt: updatedProfile.createdAt,
                updatedAt: Date()
            )
            profile = updatedProfile
        }
    }

    func updateLocation(lat: Double, lng: Double) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        try? await client
            .from("profiles")
            .update([
                "last_location_lat": AnyJSON.double(lat),
                "last_location_lng": AnyJSON.double(lng),
                "last_seen_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
            ])
            .eq("id", value: userId.supabaseString)
            .execute()
    }

    func clearData() {
        profile = nil
        subscription = nil
        hasLoadedOnce = false
    }

    var firstName: String {
        guard let name = profile?.name, !name.isEmpty else { return "there" }
        return name.components(separatedBy: " ").first ?? name
    }

    var isTrialActive: Bool {
        guard let sub = subscription else { return false }
        guard sub.status == "trial" else { return false }
        guard let trialEnd = sub.trialEndsAt else { return false }
        return trialEnd > Date()
    }

    var trialDaysLeft: Int {
        guard let trialEnd = subscription?.trialEndsAt else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: trialEnd).day ?? 0)
    }

    var isSubscribed: Bool {
        guard let sub = subscription else { return false }
        return sub.status == "active" || sub.status == "trial"
    }

    var isProUser: Bool {
        if StoreKitService.shared.isSubscribed { return true }
        if subscription?.status == "active" { return true }
        return false
    }

    var hasAccess: Bool {
        return isProUser || isTrialActive
    }

    var subscriptionStatusText: String {
        if isProUser {
            let plan = subscription?.plan ?? "pro"
            return plan == "annual" ? "Annual · Active" : "Monthly · Active"
        }
        if isTrialActive {
            return "Trial · \(trialDaysLeft) days left"
        }
        return "Expired"
    }
}
