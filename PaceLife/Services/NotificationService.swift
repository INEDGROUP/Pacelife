import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    @Published var isAuthorized = false
    @Published var deviceToken: String?

    override private init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound, .criticalAlert]
            )
            isAuthorized = granted
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("Notification auth error: \(error)")
            return false
        }
    }

    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func saveDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        guard let userId = AuthService.shared.currentUser?.id else { return }
        let client = SupabaseManager.shared.client
        let device = UIDevice.current
        struct PushToken: Encodable {
            let user_id: String
            let token: String
            let device_model: String
            let os_version: String
            let app_version: String
            let is_production: Bool
        }
        let isProduction: Bool
        #if DEBUG
        isProduction = false
        #else
        isProduction = true
        #endif
        do {
            try await client
                .from("push_tokens")
                .upsert(
                    PushToken(
                        user_id: userId.supabaseString,
                        token: token,
                        device_model: device.model,
                        os_version: device.systemVersion,
                        app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                        is_production: isProduction
                    ),
                    onConflict: "token"
                )
                .execute()
            print("Push token saved: \(token.prefix(20))...")
        } catch {
            print("Push token save error: \(error)")
        }
    }

    func scheduleAllLocalNotifications() async {
        guard isAuthorized else { return }
        await center.removeAllPendingNotificationRequests()
        let settings = await fetchNotificationSettings()
        if settings?.morningCheckin ?? true {
            await scheduleMorningCheckin(time: settings?.morningCheckinTime ?? "08:00")
        }
        if settings?.morningCheckin ?? true {
            await scheduleMissedCheckinReminder()
        }
        if settings?.eveningInsight ?? true {
            await scheduleEveningInsight(time: settings?.eveningInsightTime ?? "20:00")
        }
        if settings?.trialReminders ?? true {
            await scheduleTrialReminders()
        }
    }

    private func scheduleMorningCheckin(time: String) async {
        let components = time.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return }
        var dateComponents = DateComponents()
        dateComponents.hour = components[0]
        dateComponents.minute = components[1]
        let name = UserManager.shared.firstName
        let greetings = [
            "Good morning, \(name). How's your energy today?",
            "Morning \(name)! Time for your daily check-in 🌅",
            "Rise and shine, \(name). Log your energy to unlock today's insights",
            "Hey \(name), start your day with a quick check-in ⚡"
        ]
        let content = UNMutableNotificationContent()
        content.title = "PaceLife"
        content.body = greetings[Calendar.current.component(.weekday, from: Date()) % greetings.count]
        content.sound = .default
        content.categoryIdentifier = "MORNING_CHECKIN"
        content.userInfo = ["type": "morning_checkin"]
        content.badge = 1
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_checkin", content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func scheduleMissedCheckinReminder() async {
        var dateComponents = DateComponents()
        dateComponents.hour = 12
        dateComponents.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak! 🔥"
        content.body = "You haven't logged today's check-in yet. It takes 30 seconds."
        content.sound = .default
        content.categoryIdentifier = "MISSED_CHECKIN"
        content.userInfo = ["type": "missed_checkin"]
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "missed_checkin_reminder", content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func scheduleEveningInsight(time: String) async {
        let components = time.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return }
        var dateComponents = DateComponents()
        dateComponents.hour = components[0]
        dateComponents.minute = components[1]
        let content = UNMutableNotificationContent()
        content.title = "Your evening insight 🌙"
        content.body = "See how your energy compared to yesterday and what to expect tomorrow."
        content.sound = .default
        content.categoryIdentifier = "EVENING_INSIGHT"
        content.userInfo = ["type": "evening_insight"]
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "evening_insight", content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func scheduleTrialReminders() async {
        guard let trialEnd = UserManager.shared.subscription?.trialEndsAt else { return }
        let threeDaysBefore = Calendar.current.date(byAdding: .day, value: -3, to: trialEnd) ?? trialEnd
        let oneDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: trialEnd) ?? trialEnd
        if threeDaysBefore > Date() {
            let content = UNMutableNotificationContent()
            content.title = "3 days left in your trial"
            content.body = "Upgrade to keep your streaks, insights and routes. Don't lose your progress!"
            content.sound = .default
            content.userInfo = ["type": "trial_3days"]
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour], from: threeDaysBefore),
                repeats: false
            )
            try? await center.add(UNNotificationRequest(identifier: "trial_3days", content: content, trigger: trigger))
        }
        if oneDayBefore > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Last day of your trial ⏰"
            content.body = "Don't lose your \(UserManager.shared.profile?.streakDays ?? 0)-day streak. Upgrade today."
            content.sound = .default
            content.userInfo = ["type": "trial_1day"]
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour], from: oneDayBefore),
                repeats: false
            )
            try? await center.add(UNNotificationRequest(identifier: "trial_1day", content: content, trigger: trigger))
        }
    }

    func scheduleRouteAutoStop() async {
        let content = UNMutableNotificationContent()
        content.title = "Still recording? 🗺️"
        content.body = "You haven't moved in 4 minutes. Tap to save or discard your route."
        content.sound = .default
        content.categoryIdentifier = "ROUTE_AUTOSTOP"
        content.userInfo = ["type": "route_autostop"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 240, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "route_autostop", content: content, trigger: trigger))
    }

    func cancelRouteAutoStop() {
        center.removePendingNotificationRequests(withIdentifiers: ["route_autostop"])
    }

    func scheduleRouteLongSession() async {
        let content = UNMutableNotificationContent()
        content.title = "Long session! 💪"
        content.body = "You've been recording for 2 hours. Don't forget to save your route."
        content.sound = .default
        content.userInfo = ["type": "route_long_session"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 7200, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "route_long_session", content: content, trigger: trigger))
    }

    func cancelRouteLongSession() {
        center.removePendingNotificationRequests(withIdentifiers: ["route_long_session"])
    }

    func scheduleRouteSaved(title: String, distanceKm: Double, durationMinutes: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Route saved! 🎉"
        content.body = "\(title) · \(String(format: "%.1f", distanceKm))km · \(durationMinutes)min"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("success.aiff"))
        content.userInfo = ["type": "route_saved"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "route_saved_\(UUID().uuidString)", content: content, trigger: trigger))
    }

    func scheduleAchievement(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("achievement.aiff"))
        content.userInfo = ["type": "achievement"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "achievement_\(UUID().uuidString)", content: content, trigger: trigger))
    }

    func checkAndScheduleStreakReminder() async {
        guard isAuthorized else { return }
        let streakDays = UserManager.shared.profile?.streakDays ?? 0
        guard streakDays > 0 else { return }
        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "Don't lose your \(streakDays)-day streak! 🔥"
        content.body = "Log today's check-in before midnight to keep your streak alive."
        content.sound = .default
        content.categoryIdentifier = "STREAK_REMINDER"
        content.userInfo = ["type": "streak_reminder", "streak_days": streakDays]
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: "streak_reminder", content: content, trigger: trigger))
    }

    func setupNotificationCategories() {
        let checkinAction = UNNotificationAction(
            identifier: "LOG_CHECKIN",
            title: "Log Check-in",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )
        let saveRouteAction = UNNotificationAction(
            identifier: "SAVE_ROUTE",
            title: "Save Route",
            options: [.foreground]
        )
        let discardRouteAction = UNNotificationAction(
            identifier: "DISCARD_ROUTE",
            title: "Discard",
            options: [.destructive]
        )
        let upgradeAction = UNNotificationAction(
            identifier: "UPGRADE",
            title: "Upgrade Now",
            options: [.foreground]
        )
        let morningCheckinCategory = UNNotificationCategory(
            identifier: "MORNING_CHECKIN",
            actions: [checkinAction, dismissAction],
            intentIdentifiers: []
        )
        let missedCheckinCategory = UNNotificationCategory(
            identifier: "MISSED_CHECKIN",
            actions: [checkinAction, dismissAction],
            intentIdentifiers: []
        )
        let routeAutoStopCategory = UNNotificationCategory(
            identifier: "ROUTE_AUTOSTOP",
            actions: [saveRouteAction, discardRouteAction],
            intentIdentifiers: []
        )
        let streakReminderCategory = UNNotificationCategory(
            identifier: "STREAK_REMINDER",
            actions: [checkinAction, dismissAction],
            intentIdentifiers: []
        )
        let trialCategory = UNNotificationCategory(
            identifier: "TRIAL_REMINDER",
            actions: [upgradeAction, dismissAction],
            intentIdentifiers: []
        )
        let eveningInsightCategory = UNNotificationCategory(
            identifier: "EVENING_INSIGHT",
            actions: [UNNotificationAction(identifier: "VIEW_INSIGHTS", title: "View Insights", options: [.foreground]), dismissAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([
            morningCheckinCategory,
            missedCheckinCategory,
            routeAutoStopCategory,
            streakReminderCategory,
            trialCategory,
            eveningInsightCategory
        ])
    }

    private func fetchNotificationSettings() async -> NotificationSettings? {
        guard let userId = AuthService.shared.currentUser?.id else { return nil }
        let client = SupabaseManager.shared.client
        return try? await client
            .from("notification_settings")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .single()
            .execute()
            .value
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String ?? ""
        switch response.actionIdentifier {
        case "LOG_CHECKIN":
            NotificationCenter.default.post(name: .openCheckin, object: nil)
        case "SAVE_ROUTE":
            NotificationCenter.default.post(name: .saveRoute, object: nil)
        case "DISCARD_ROUTE":
            NotificationCenter.default.post(name: .discardRoute, object: nil)
        case "UPGRADE":
            NotificationCenter.default.post(name: .openPaywall, object: nil)
        case "VIEW_INSIGHTS":
            NotificationCenter.default.post(name: .openInsights, object: nil)
        default:
            switch type {
            case "morning_checkin", "missed_checkin", "streak_reminder":
                NotificationCenter.default.post(name: .openCheckin, object: nil)
            case "evening_insight":
                NotificationCenter.default.post(name: .openInsights, object: nil)
            case "trial_3days", "trial_1day":
                NotificationCenter.default.post(name: .openPaywall, object: nil)
            case "achievement":
                NotificationCenter.default.post(name: .openProfile, object: nil)
            default:
                break
            }
        }
        completionHandler()
    }
}
