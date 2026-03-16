import SwiftUI
import Supabase

struct NotificationSettingsView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var notificationService = NotificationService.shared
    @State private var settings: NotificationSettingsModel = NotificationSettingsModel()
    @State private var isLoading = true
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Color.plBg.ignoresSafeArea()
            if isLoading {
                ProgressView()
                    .tint(Color.plGreen)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if !notificationService.isAuthorized {
                            permissionBanner
                        }
                        dailySection
                        streakSection
                        routeSection
                        aiSection
                        trialSection
                        achievementsSection
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSettings()
            await notificationService.checkAuthorization()
        }
        .onChange(of: settings.morningCheckin) { _ in Task { await saveSettings() } }
        .onChange(of: settings.morningCheckinTime) { _ in Task { await saveSettings() } }
        .onChange(of: settings.eveningInsight) { _ in Task { await saveSettings() } }
        .onChange(of: settings.eveningInsightTime) { _ in Task { await saveSettings() } }
        .onChange(of: settings.streakReminder) { _ in Task { await saveSettings() } }
        .onChange(of: settings.routeRecording) { _ in Task { await saveSettings() } }
        .onChange(of: settings.achievements) { _ in Task { await saveSettings() } }
        .onChange(of: settings.trialReminders) { _ in Task { await saveSettings() } }
        .onChange(of: settings.aiPatterns) { _ in Task { await saveSettings() } }
        .onChange(of: settings.weatherAlerts) { _ in Task { await saveSettings() } }
    }

    var permissionBanner: some View {
        Button(action: {
            Task {
                let granted = await notificationService.requestAuthorization()
                if granted {
                    await notificationService.scheduleAllLocalNotifications()
                }
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.plAmber.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.plAmber)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Notifications are off")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                    Text("Tap to enable notifications")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.plTextTertiary)
            }
            .padding(14)
            .background(Color.plAmber.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(Color.plAmber.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    var dailySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "sunrise.fill", title: "Daily check-in", color: Color.plAmber)
            VStack(spacing: 0) {
                PLToggleRow(
                    icon: "bell.fill",
                    color: Color.plGreen,
                    title: "Morning reminder",
                    subtitle: "Reminds you to log your daily check-in",
                    isOn: $settings.morningCheckin
                )
                if settings.morningCheckin {
                    Divider().background(Color.plBorder).padding(.leading, 56)
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.plGreen)
                            .frame(width: 28)
                        Text("Reminder time")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                        Spacer()
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { timeStringToDate(settings.morningCheckinTime) },
                                set: { settings.morningCheckinTime = dateToTimeString($0) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .colorScheme(.dark)
                        .tint(Color.plGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Divider().background(Color.plBorder).padding(.leading, 56)
                PLToggleRow(
                    icon: "moon.stars.fill",
                    color: Color.plBlue,
                    title: "Evening insight",
                    subtitle: "Daily summary and tomorrow's forecast",
                    isOn: $settings.eveningInsight
                )
                if settings.eveningInsight {
                    Divider().background(Color.plBorder).padding(.leading, 56)
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.plBlue)
                            .frame(width: 28)
                        Text("Insight time")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                        Spacer()
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { timeStringToDate(settings.eveningInsightTime) },
                                set: { settings.eveningInsightTime = dateToTimeString($0) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .colorScheme(.dark)
                        .tint(Color.plBlue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(Color.plBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(Color.plBorder, lineWidth: 0.5)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.morningCheckin)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.eveningInsight)
        }
    }

    var streakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "flame.fill", title: "Streaks", color: Color(hex: "FF6B35"))
            VStack(spacing: 0) {
                PLToggleRow(
                    icon: "flame.fill",
                    color: Color(hex: "FF6B35"),
                    title: "Streak reminder",
                    subtitle: "Alert at 9pm if you haven't checked in",
                    isOn: $settings.streakReminder
                )
            }
            .background(Color.plBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(Color.plBorder, lineWidth: 0.5)
            )
        }
    }

    var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "figure.walk.circle.fill", title: "Route recording", color: Color.plBlue)
            VStack(spacing: 0) {
                PLToggleRow(
                    icon: "mappin.circle.fill",
                    color: Color.plBlue,
                    title: "Recording alerts",
                    subtitle: "Auto-stop warning and route saved confirmation",
                    isOn: $settings.routeRecording
                )
            }
            .background(Color.plBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(Color.plBorder, lineWidth: 0.5)
            )
        }
    }

    var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "sparkles", title: "AI insights", color: Color(hex: "B088FF"))
            VStack(spacing: 0) {
                PLToggleRow(
                    icon: "brain.head.profile",
                    color: Color(hex: "B088FF"),
                    title: "Pattern detection",
                    subtitle: "Notified when AI spots energy trends",
                    isOn: $settings.aiPatterns
                )
                Divider().background(Color.plBorder).padding(.leading, 56)
                PLToggleRow(
                    icon: "location.fill",
                    color: Color.plGreen,
                    title: "Nearby spots",
                    subtitle: "Alert when you're close to a favourite spot",
                    isOn: $settings.weatherAlerts
                )
            }
            .background(Color.plBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(Color.plBorder, lineWidth: 0.5)
            )
        }
    }

    var trialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "creditcard.fill", title: "Subscription", color: Color.plAmber)
            VStack(spacing: 0) {
                PLToggleRow(
                    icon: "clock.fill",
                    color: Color.plAmber,
                    title: "Trial reminders",
                    subtitle: "Reminder 3 days and 1 day before trial ends",
                    isOn: $settings.trialReminders
                )
            }
            .background(Color.plBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(Color.plBorder, lineWidth: 0.5)
            )
        }
    }

    var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "trophy.fill", title: "Achievements", color: Color(hex: "FFD700"))
            VStack(spacing: 0) {
                PLToggleRow(
                    icon: "star.fill",
                    color: Color(hex: "FFD700"),
                    title: "Achievement unlocked",
                    subtitle: "Notified when you hit milestones and streaks",
                    isOn: $settings.achievements
                )
            }
            .background(Color.plBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.lg)
                    .strokeBorder(Color.plBorder, lineWidth: 0.5)
            )
        }
    }

    private func loadSettings() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        let client = SupabaseManager.shared.client
        do {
            let fetched: NotificationSettingsModel = try await client
                .from("notification_settings")
                .select()
                .eq("user_id", value: userId.supabaseString)
                .single()
                .execute()
                .value
            settings = fetched
        } catch {
            // Row doesn't exist yet — insert defaults
            let defaults = NotificationSettingsModel()
            try? await client
                .from("notification_settings")
                .insert([
                    "user_id": AnyJSON.string(userId.supabaseString),
                    "morning_checkin": AnyJSON.bool(defaults.morningCheckin),
                    "morning_checkin_time": AnyJSON.string(defaults.morningCheckinTime),
                    "evening_insight": AnyJSON.bool(defaults.eveningInsight),
                    "evening_insight_time": AnyJSON.string(defaults.eveningInsightTime),
                    "streak_reminder": AnyJSON.bool(defaults.streakReminder),
                    "route_recording": AnyJSON.bool(defaults.routeRecording),
                    "achievements": AnyJSON.bool(defaults.achievements),
                    "trial_reminders": AnyJSON.bool(defaults.trialReminders),
                    "ai_patterns": AnyJSON.bool(defaults.aiPatterns),
                    "weather_alerts": AnyJSON.bool(defaults.weatherAlerts)
                ])
                .execute()
        }
        isLoading = false
    }

    private func saveSettings() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        isSaving = true
        let client = SupabaseManager.shared.client
        do {
            try await client
                .from("notification_settings")
                .upsert([
                    "user_id": AnyJSON.string(userId.supabaseString),
                    "morning_checkin": AnyJSON.bool(settings.morningCheckin),
                    "morning_checkin_time": AnyJSON.string(settings.morningCheckinTime),
                    "evening_insight": AnyJSON.bool(settings.eveningInsight),
                    "evening_insight_time": AnyJSON.string(settings.eveningInsightTime),
                    "streak_reminder": AnyJSON.bool(settings.streakReminder),
                    "route_recording": AnyJSON.bool(settings.routeRecording),
                    "achievements": AnyJSON.bool(settings.achievements),
                    "trial_reminders": AnyJSON.bool(settings.trialReminders),
                    "ai_patterns": AnyJSON.bool(settings.aiPatterns),
                    "weather_alerts": AnyJSON.bool(settings.weatherAlerts)
                ])
                .execute()
            await notificationService.scheduleAllLocalNotifications()
            await notificationService.checkAndScheduleStreakReminder()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Save notification settings error: \(error)")
        }
        isSaving = false
    }

    private func timeStringToDate(_ timeString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeString) ?? Date()
    }

    private func dateToTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - PLToggleRow

struct PLToggleRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                Text(subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
                    .lineLimit(2)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: isOn) { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - NotificationSettingsModel

struct NotificationSettingsModel: Codable {
    var userId: UUID?
    var morningCheckin: Bool = true
    var morningCheckinTime: String = "08:00"
    var eveningInsight: Bool = true
    var eveningInsightTime: String = "20:00"
    var streakReminder: Bool = true
    var routeRecording: Bool = true
    var achievements: Bool = true
    var trialReminders: Bool = true
    var aiPatterns: Bool = true
    var weatherAlerts: Bool = true

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
