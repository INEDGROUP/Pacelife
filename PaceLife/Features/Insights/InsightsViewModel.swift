import Foundation
import SwiftUI

@MainActor
class InsightsViewModel: ObservableObject {
    @Published var weekCheckins: [Checkin] = []
    @Published var monthCheckins: [Checkin] = []
    @Published var aiInsights: [AIInsight] = []
    @Published var achievements: [PLAchievement] = []
    @Published var routes: [PLRoute] = []
    @Published var isLoading = false
    @Published var selectedPeriod: Period = .week

    enum Period: String, CaseIterable {
        case week = "Week"
        case month = "Month"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            }
        }
    }

    var currentCheckins: [Checkin] {
        selectedPeriod == .week ? weekCheckins : monthCheckins
    }

    var avgEnergy: Int {
        guard !currentCheckins.isEmpty else { return 0 }
        return Int(currentCheckins.map { Double($0.energy) }.reduce(0, +) / Double(currentCheckins.count))
    }

    var avgSleep: Double {
        let withSleep = currentCheckins.compactMap { $0.sleepHours }
        guard !withSleep.isEmpty else { return 0 }
        return withSleep.reduce(0, +) / Double(withSleep.count)
    }

    var avgMood: Double {
        let withMood = currentCheckins.compactMap { $0.mood }.map { Double($0) }
        guard !withMood.isEmpty else { return 0 }
        return withMood.reduce(0, +) / Double(withMood.count)
    }

    var energyTrend: String {
        guard currentCheckins.count >= 4 else { return "neutral" }
        let recent = currentCheckins.prefix(3).map { Double($0.energy) }.reduce(0, +) / 3
        let older = currentCheckins.suffix(3).map { Double($0.energy) }.reduce(0, +) / 3
        if recent > older + 5 { return "up" }
        if recent < older - 5 { return "down" }
        return "neutral"
    }

    var sleepEnergyCorrelation: Double {
        let pairs = currentCheckins.compactMap { checkin -> (Double, Double)? in
            guard let sleep = checkin.sleepHours else { return nil }
            return (sleep, Double(checkin.energy))
        }
        guard pairs.count >= 3 else { return 0 }
        let n = Double(pairs.count)
        let sumX = pairs.map { $0.0 }.reduce(0, +)
        let sumY = pairs.map { $0.1 }.reduce(0, +)
        let sumXY = pairs.map { $0.0 * $0.1 }.reduce(0, +)
        let sumX2 = pairs.map { $0.0 * $0.0 }.reduce(0, +)
        let sumY2 = pairs.map { $0.1 * $0.1 }.reduce(0, +)
        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    var correlationText: String {
        let r = sleepEnergyCorrelation
        if r > 0.6 { return "Strong positive — more sleep = higher energy" }
        if r > 0.3 { return "Moderate — sleep improves your energy" }
        if r > 0 { return "Weak — slight connection between sleep and energy" }
        if r == 0 { return "Not enough data yet" }
        return "No clear pattern found yet"
    }

    var bestEnergyDay: String {
        guard !currentCheckins.isEmpty else { return "—" }
        let best = currentCheckins.max(by: { $0.energy < $1.energy })
        guard let best = best else { return "—" }
        return best.checkedInAt.formatted(.dateTime.weekday(.wide))
    }

    var bestSleepCheckin: Checkin? {
        currentCheckins.max(by: { ($0.sleepHours ?? 0) < ($1.sleepHours ?? 0) })
    }

    var totalRouteDistance: Double {
        routes.compactMap { $0.distanceKm }.reduce(0, +)
    }

    var totalRouteCalories: Int {
        routes.compactMap { $0.calories }.reduce(0, +)
    }

    var longestRoute: PLRoute? {
        routes.max(by: { ($0.distanceKm ?? 0) < ($1.distanceKm ?? 0) })
    }

    func loadData() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        isLoading = true
        let client = SupabaseManager.shared.client

        async let weekTask: [Checkin] = (try? client
            .from("checkins")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .gte("checked_in_at", value: ISO8601DateFormatter().string(
                from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            ))
            .order("checked_in_at", ascending: false)
            .execute()
            .value) ?? []

        async let monthTask: [Checkin] = (try? client
            .from("checkins")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .gte("checked_in_at", value: ISO8601DateFormatter().string(
                from: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            ))
            .order("checked_in_at", ascending: false)
            .execute()
            .value) ?? []

        async let insightsTask: [AIInsight] = (try? client
            .from("ai_insights")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .order("created_at", ascending: false)
            .limit(10)
            .execute()
            .value) ?? []

        async let routesTask: [PLRoute] = (try? client
            .from("routes")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .order("created_at", ascending: false)
            .execute()
            .value) ?? []

        async let achievementsTask: [PLAchievement] = (try? client
            .from("achievements")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .order("earned_at", ascending: false)
            .execute()
            .value) ?? []

        weekCheckins = await weekTask
        monthCheckins = await monthTask
        aiInsights = await insightsTask
        routes = await routesTask
        achievements = await achievementsTask
        isLoading = false
    }
}

struct PLAchievement: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let type: String
    let title: String
    let earnedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case earnedAt = "earned_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        let dateStr = try container.decode(String.self, forKey: .earnedAt)
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        earnedAt = f.date(from: dateStr) ?? Date()
    }
}
