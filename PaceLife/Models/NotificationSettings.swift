import Foundation

struct NotificationSettings: Codable {
    var userId: UUID
    var morningCheckin: Bool
    var morningCheckinTime: String
    var eveningInsight: Bool
    var eveningInsightTime: String
    var streakReminder: Bool
    var routeRecording: Bool
    var achievements: Bool
    var trialReminders: Bool
    var aiPatterns: Bool
    var weatherAlerts: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case morningCheckin = "morning_checkin"
        case morningCheckinTime = "morning_checkin_time"
        case eveningInsight = "evening_insight"
        case eveningInsightTime = "evening_insight_time"
        case streakReminder = "streak_reminder"
        case routeRecording = "route_recording"
        case achievements = "achievements"
        case trialReminders = "trial_reminders"
        case aiPatterns = "ai_patterns"
        case weatherAlerts = "weather_alerts"
    }
}
