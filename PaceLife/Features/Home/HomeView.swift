import SwiftUI
import MapKit
import Supabase

struct HomeView: View {
    let locationManager: LocationManager
    @EnvironmentObject var userManager: UserManager
    @StateObject private var viewModel = HomeViewModel()
    @State private var animateCards = false
    @State private var showCheckin = false

    var body: some View {
        ZStack {
            Color.plBg.ignoresSafeArea()
            if viewModel.isLoading && viewModel.weekCheckins.isEmpty {
                LoadingView()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        MapHeaderView(
                            locationManager: locationManager,
                            energyScore: viewModel.energyScore
                        )
                        VStack(spacing: PLSpacing.lg) {
                            GreetingSection(
                                name: userManager.firstName,
                                isTrialActive: userManager.isTrialActive,
                                trialDaysLeft: userManager.trialDaysLeft
                            )

                            if !viewModel.hasLoadedOnce {
                                EmptyView()
                            } else if viewModel.hasCheckedInToday {
                                ScoreRow(
                                    energy: viewModel.energyScore,
                                    sleep: viewModel.sleepHours,
                                    moodText: viewModel.moodText,
                                    moodValue: viewModel.moodValue,
                                    energyTrend: viewModel.energyTrend,
                                    sleepTrend: viewModel.sleepTrend
                                )
                                .opacity(animateCards ? 1 : 0)
                                .offset(y: animateCards ? 0 : 20)
                                .animation(PLTheme.springSmooth.delay(0.05), value: animateCards)
                            } else {
                                NoCheckinBanner(showCheckin: $showCheckin)
                                    .opacity(animateCards ? 1 : 0)
                                    .offset(y: animateCards ? 0 : 20)
                                    .animation(PLTheme.springSmooth.delay(0.05), value: animateCards)
                            }

                            StreakPill(days: userManager.profile?.streakDays ?? 0)
                                .opacity(animateCards ? 1 : 0)
                                .offset(y: animateCards ? 0 : 20)
                                .animation(PLTheme.springSmooth.delay(0.1), value: animateCards)

                            if HealthKitService.shared.isAuthorized && viewModel.todaySteps > 0 {
                                StepsCard(
                                    steps: viewModel.todaySteps,
                                    progress: HealthKitService.shared.stepProgress,
                                    statusText: HealthKitService.shared.stepStatusText
                                )
                                .opacity(animateCards ? 1 : 0)
                                .offset(y: animateCards ? 0 : 20)
                                .animation(PLTheme.springSmooth.delay(0.13), value: animateCards)
                            }

                            WeekEnergyChart(checkins: viewModel.weekCheckins)
                                .opacity(animateCards ? 1 : 0)
                                .offset(y: animateCards ? 0 : 20)
                                .animation(PLTheme.springSmooth.delay(0.15), value: animateCards)

                            AIInsightCard(
                                hasCheckin: viewModel.hasCheckedInToday,
                                energy: viewModel.energyScore,
                                sleep: viewModel.sleepHours,
                                mood: viewModel.moodValue,
                                weather: WeatherService.shared,
                                steps: viewModel.todaySteps,
                                hasAccess: userManager.hasAccess
                            )
                            .opacity(animateCards ? 1 : 0)
                            .offset(y: animateCards ? 0 : 20)
                            .animation(PLTheme.springSmooth.delay(0.2), value: animateCards)

                            if let route = viewModel.suggestedRoute {
                                SuggestedRouteCard(route: route, weather: WeatherService.shared)
                                    .opacity(animateCards ? 1 : 0)
                                    .offset(y: animateCards ? 0 : 20)
                                    .animation(PLTheme.springSmooth.delay(0.25), value: animateCards)
                            }

                            if !viewModel.hasCheckedInToday {
                                CheckinButton(showCheckin: $showCheckin)
                                    .opacity(animateCards ? 1 : 0)
                                    .offset(y: animateCards ? 0 : 20)
                                    .animation(PLTheme.springSmooth.delay(0.3), value: animateCards)
                            }
                        }
                        .padding(.horizontal, PLSpacing.xl)
                        .padding(.bottom, 120)
                    }
                }
                .refreshable {
                    guard let userId = AuthService.shared.currentUser?.id else { return }
                    await viewModel.loadData()
                    await userManager.loadUserData(userId: userId)
                }
            }
        }
        .sheet(isPresented: $showCheckin) {
            CheckinView(isPresented: $showCheckin)
                .environmentObject(userManager)
        }
        .task {
            if !viewModel.hasLoadedOnce {
                await viewModel.loadData()
                withAnimation(PLTheme.springSmooth) {
                    animateCards = true
                }
            }
        }
        .onChange(of: showCheckin) { isShowing in
            if !isShowing && viewModel.hasLoadedOnce {
                Task { await viewModel.loadData() }
            }
        }
    }
}

struct LoadingView: View {
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.plGreen.opacity(0.2))
                .frame(width: 60, height: 60)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
                .overlay(
                    Image(systemName: "figure.walk")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.plGreen)
                )
            Text("Loading your day...")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.plTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true }
    }
}

struct NoCheckinBanner: View {
    @Binding var showCheckin: Bool

    var body: some View {
        Button(action: { showCheckin = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.plGreen.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.plGreen)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Log today's check-in")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                    Text("Track energy, sleep and mood to unlock AI insights")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.plTextTertiary)
            }
            .plAccentCard(color: .plGreen)
        }
        .buttonStyle(.plain)
    }
}

struct ScoreRow: View {
    let energy: Int
    let sleep: Double
    let moodText: String
    let moodValue: Int
    let energyTrend: String
    let sleepTrend: String

    var body: some View {
        HStack(spacing: PLSpacing.sm) {
            ScoreCard(
                label: "Energy",
                value: "\(energy)",
                sub: energyTrend.isEmpty ? "today" : energyTrend,
                accentColor: energyColor,
                icon: "bolt.fill"
            )
            ScoreCard(
                label: "Sleep",
                value: sleep > 0 ? String(format: "%.1f", sleep) : "—",
                sub: sleep > 0 ? sleepTrend : "not logged",
                accentColor: .plBlue,
                icon: "moon.stars.fill"
            )
            MoodScoreCard(mood: moodValue)
        }
    }

    var energyColor: Color {
        if energy >= 80 { return .plGreen }
        if energy >= 60 { return .plAmber }
        return .plRed
    }
}

struct MoodScoreCard: View {
    let mood: Int

    var moodConfig: (symbol: String, colors: [Color], label: String) {
        switch mood {
        case 5: return ("star.circle.fill", [Color(hex: "FFD700"), Color(hex: "FF9500")], "Amazing")
        case 4: return ("face.smiling.fill", [Color(hex: "4CFFA0"), Color(hex: "00C875")], "Great")
        case 3: return ("checkmark.circle.fill", [Color(hex: "6B8FFF"), Color(hex: "4A6FF5")], "Good")
        case 2: return ("minus.circle.fill", [Color(hex: "FFB347"), Color(hex: "FF9500")], "Meh")
        case 1: return ("cloud.rain.fill", [Color(hex: "FF6B6B"), Color(hex: "FF4444")], "Low")
        default: return ("circle.dashed", [Color.plTextTertiary, Color.plTextTertiary], "—")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Mood")
                .font(.plMicro)
                .foregroundColor(.plTextTertiary)
                .tracking(0.8)
                .textCase(.uppercase)

            Image(systemName: moodConfig.symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: moodConfig.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: moodConfig.colors[0].opacity(0.35), radius: 6)
                .frame(height: 32)

            Text(moodConfig.label)
                .font(.plMicro)
                .foregroundColor(.plTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard()
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [moodConfig.colors[0], moodConfig.colors[0].opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
        }
    }
}

struct ScoreCard: View {
    let label: String
    let value: String
    let sub: String
    let accentColor: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.plMicro)
                .foregroundColor(.plTextTertiary)
                .tracking(0.8)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accentColor.opacity(0.7))
                Text(value)
                    .font(.plSans(24, weight: .medium))
                    .foregroundColor(accentColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            Text(sub)
                .font(.plMicro)
                .foregroundColor(.plTextTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard()
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
        }
    }
}

struct WeekEnergyChart: View {
    let checkins: [Checkin]

    var chartData: [(String, Int)] {
        let calendar = Calendar.current
        let last7 = (0..<7).map { i -> Date in
            calendar.date(byAdding: .day, value: -(6 - i), to: Date()) ?? Date()
        }
        return last7.map { date in
            let dayStr = date.formatted(.dateTime.weekday(.abbreviated))
            let checkin = checkins.first { calendar.isDate($0.checkedInAt, inSameDayAs: date) }
            return (dayStr, checkin?.energy ?? 0)
        }
    }

    var maxValue: Int { max(chartData.map { $0.1 }.max() ?? 100, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy this week")
                .plSectionLabel()

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(chartData, id: \.0) { day, value in
                    VStack(spacing: 4) {
                        if value > 0 {
                            Text("\(value)")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(barColor(value))
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(value > 0 ? barColor(value) : Color.plBgTertiary)
                            .frame(
                                height: value > 0
                                    ? max(CGFloat(value) / CGFloat(maxValue) * 80, 8)
                                    : 8
                            )
                        Text(day)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110)
        }
        .plCard()
    }

    func barColor(_ value: Int) -> Color {
        if value >= 80 { return .plGreen }
        if value >= 60 { return .plAmber }
        return .plRed
    }
}

struct AIInsightCard: View {
    let hasCheckin: Bool
    let energy: Int
    let sleep: Double
    let mood: Int
    @ObservedObject var weather: WeatherService
    let steps: Int
    var hasAccess: Bool = true
    @State private var showPaywall = false
    @State private var aiInsight: String = ""
    @State private var isLoadingInsight = false

    var staticInsight: String {
        if !hasCheckin {
            return "Log your first check-in today to unlock personalised AI insights based on your energy patterns."
        }
        let weatherContext = weather.currentTemp != nil ? " It's \(weather.weatherSummary) outside." : ""
        if energy >= 80 && sleep >= 7 {
            return "You're in peak condition today — energy at \(energy) and great sleep.\(weatherContext) This is your window for deep work or a strong workout."
        }
        if energy >= 80 && sleep < 7 {
            return "High energy despite lower sleep — stay hydrated and plan an earlier night tonight to sustain this momentum.\(weatherContext)"
        }
        if energy < 50 {
            return "Low energy today.\(weatherContext) Skip intense exercise and opt for a short walk instead. Focus on one key task."
        }
        if sleep < 6 {
            return "Poor sleep is showing.\(weatherContext) Your cognitive performance is reduced — block time for deep work in the morning."
        }
        return "Energy at \(energy) — a solid day.\(weatherContext) Aim to move for at least 20 minutes to keep your rhythm stable."
    }

    var displayInsight: String {
        aiInsight.isEmpty ? staticInsight : aiInsight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.sm) {
            Text("AI insight · today")
                .plSectionLabel()
            VStack(alignment: .leading, spacing: PLSpacing.sm) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.plGreen)
                        .frame(width: 6, height: 6)
                    Text("PaceLife AI")
                        .font(.plMicro)
                        .foregroundColor(.plGreen)
                        .tracking(0.5)
                    Spacer()
                    if let temp = weather.currentTemp, let icon = weather.weatherIcon {
                        HStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.plTextTertiary)
                            Text("\(temp)°C")
                                .font(.plMicro)
                                .foregroundStyle(Color.plTextTertiary)
                        }
                    }
                    if isLoadingInsight {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(Color.plGreen)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.plGreen.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: PLRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: PLRadius.sm)
                        .strokeBorder(Color.plGreen.opacity(0.2), lineWidth: 0.5)
                )

                if hasAccess {
                    Text(displayInsight)
                        .font(.plSans(14, weight: .light))
                        .foregroundColor(.plTextSecondary)
                        .lineSpacing(4)
                        .animation(.easeInOut(duration: 0.3), value: displayInsight)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Log 3 check-ins to unlock personalised AI insights about your energy patterns.")
                            .font(.plSans(13, weight: .light))
                            .foregroundColor(.plTextSecondary)
                            .lineSpacing(3)

                        Button(action: { showPaywall = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                Text("Unlock AI Insights")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(Color.plBg)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.plGreen)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showPaywall) {
                            PaywallView(isPresented: $showPaywall)
                                .environmentObject(UserManager.shared)
                        }
                    }
                }
            }
            .plAccentCard(color: .plGreen)
        }
        .task {
            if hasCheckin {
                await fetchAIInsight()
            }
        }
        .onChange(of: hasCheckin) { newValue in
            if newValue {
                Task { await fetchAIInsight() }
            }
        }
    }

    private func fetchAIInsight() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        guard let session = try? await SupabaseManager.shared.client.auth.session else { return }
        let client = SupabaseManager.shared.client

        if let cached: [AIInsight] = try? await client
            .from("ai_insights")
            .select()
            .eq("user_id", value: userId.supabaseString)
            .eq("type", value: "daily")
            .gte("created_at", value: ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date())))
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value,
           let todayInsight = cached.first {
            aiInsight = todayInsight.body
            return
        }

        isLoadingInsight = true
        let supabaseURL = "https://vhgnnujzcjjugbneuwhn.supabase.co"
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoZ25udWp6Y2pqdWdibmV1d2huIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1ODg5MDgsImV4cCI6MjA4OTE2NDkwOH0.JjtPfC3P1V-pAZ4UrHDSbTNvxIlNHlrL3TCKqfWo4EA"
        if let url = URL(string: "\(supabaseURL)/functions/v1/ai-daily-insight") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.timeoutInterval = 30
            var body: [String: Any] = ["user_id": userId.supabaseString, "steps": steps]
            if let temp = weather.currentTemp { body["weather_temp"] = temp }
            if let condition = weather.currentCondition { body["weather_condition"] = condition }
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let decoded = try? JSONDecoder().decode([String: String].self, from: data),
                   let insight = decoded["insight"] {
                    aiInsight = insight
                }
            } catch {
                print("AI insight error: \(error)")
            }
        }
        isLoadingInsight = false
    }
}


struct SuggestedRouteCard: View {
    let route: SuggestedRoute
    @ObservedObject var weather: WeatherService

    var intensityColor: Color {
        switch route.intensity {
        case "high": return .plRed
        case "medium": return .plAmber
        default: return .plGreen
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.sm) {
            HStack {
                Text("Suggested for you")
                    .plSectionLabel()
                Spacer()
                if let temp = weather.currentTemp, let icon = weather.weatherIcon {
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.plTextTertiary)
                        Text("\(temp)°C")
                            .font(.plMicro)
                            .foregroundStyle(Color.plTextTertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.plBgTertiary)
                    .clipShape(Capsule())
                }
            }

            if !weather.isGoodForWalking {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.plAmber)
                    Text(weather.walkingAdvice)
                        .font(.plSans(11))
                        .foregroundStyle(Color.plAmber)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.plAmber.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PLRadius.sm))
                .overlay(RoundedRectangle(cornerRadius: PLRadius.sm).strokeBorder(Color.plAmber.opacity(0.2), lineWidth: 0.5))
            }

            HStack(spacing: PLSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: PLRadius.md)
                        .fill(intensityColor.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: PLRadius.md).strokeBorder(intensityColor.opacity(0.2), lineWidth: 0.5))
                        .frame(width: 46, height: 46)
                    Image(systemName: route.icon)
                        .font(.system(size: 18))
                        .foregroundColor(intensityColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(route.title)
                        .font(.plSans(14, weight: .medium))
                        .foregroundColor(.plTextPrimary)
                    if route.distanceKm > 0 {
                        Text(String(format: "%.1f km · %d min · %@ intensity", route.distanceKm, route.durationMinutes, route.intensity))
                            .font(.plSans(12))
                            .foregroundColor(.plTextTertiary)
                    } else {
                        Text(route.description)
                            .font(.plSans(12))
                            .foregroundColor(.plTextTertiary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            if route.distanceKm > 0 {
                Text(route.description)
                    .font(.plSans(12, weight: .light))
                    .foregroundColor(.plTextTertiary)
                    .lineSpacing(3)
            }
        }
        .plCard()
    }
}

struct StreakPill: View {
    let days: Int
    let values: [CGFloat] = [0.4, 0.6, 0.5, 0.75, 0.9, 0.85, 1.0]

    var body: some View {
        HStack(spacing: 12) {
            PLAnimatedFlame(size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(days == 0 ? "Start your streak" : "\(days) day streak")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                Text(days == 0 ? "Check in daily to build momentum" : "Keep going — you are on a roll")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }

            Spacer()

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<values.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            i >= 4
                            ? LinearGradient(colors: [Color(hex: "FF6B35"), Color(hex: "FF9500")], startPoint: .bottom, endPoint: .top)
                            : LinearGradient(colors: [Color(hex: "FF9500").opacity(0.25), Color(hex: "FF9500").opacity(0.25)], startPoint: .bottom, endPoint: .top)
                        )
                        .frame(width: 4, height: 28 * values[i])
                }
            }
        }
        .padding(.horizontal, PLSpacing.lg)
        .padding(.vertical, PLSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PLRadius.lg)
                .fill(Color(hex: "FF6B35").opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: PLRadius.lg)
                        .strokeBorder(Color(hex: "FF6B35").opacity(0.15), lineWidth: 0.5)
                )
        )
    }
}

struct MapHeaderView: View {
    @ObservedObject var locationManager: LocationManager
    let energyScore: Int
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
    )

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(coordinateRegion: $region, showsUserLocation: true)
                .frame(height: 220)
                .disabled(true)
                .overlay(LinearGradient(colors: [.clear, Color.plBg], startPoint: .center, endPoint: .bottom))
                .onReceive(locationManager.$userLocation.compactMap { $0 }) { coord in
                    withAnimation(.easeInOut(duration: 1.0)) { region.center = coord }
                }
            EnergyBadge(score: energyScore)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .onAppear { locationManager.startTracking() }
    }
}

struct CheckinButton: View {
    @Binding var showCheckin: Bool
    var body: some View {
        Button(action: { showCheckin = true }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.system(size: 18))
                Text("Log today's check-in").font(.system(size: 15, weight: .medium, design: .rounded))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Color.plTextTertiary)
            }
            .foregroundStyle(Color.plGreen)
            .plAccentCard(color: .plGreen)
        }
        .buttonStyle(.plain)
    }
}

struct EnergyBadge: View {
    let score: Int
    @State private var pulse = false
    var badgeColor: Color { score >= 80 ? .plGreen : score >= 60 ? .plAmber : score > 0 ? .plRed : .plGreen }
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(badgeColor)
                .frame(width: 8, height: 8)
                .scaleEffect(pulse ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            Text(score > 0 ? "Energy \(score)" : "Log check-in")
                .font(.plSans(12, weight: .medium))
                .foregroundColor(.plTextPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.plBorder, lineWidth: 0.5))
        .onAppear { pulse = true }
    }
}

struct GreetingSection: View {
    let name: String
    let isTrialActive: Bool
    let trialDaysLeft: Int

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Date().formatted(.dateTime.weekday(.wide))) · \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.plMicro)
                        .foregroundColor(.plTextTertiary)
                        .tracking(0.8)
                        .textCase(.uppercase)
                    HStack(spacing: 0) {
                        Text("\(timeGreeting), ")
                            .font(.system(size: 26, weight: .regular, design: .serif))
                            .foregroundColor(.plTextPrimary)
                        Text("\(name).")
                            .font(.system(size: 26, weight: .regular, design: .serif))
                            .foregroundColor(.plGreen)
                    }
                }
                Spacer()
                if isTrialActive && trialDaysLeft <= 3 {
                    VStack(spacing: 2) {
                        Text("\(trialDaysLeft)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.plAmber)
                        Text("days left")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                    .padding(10)
                    .background(Color.plAmber.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: PLRadius.md).strokeBorder(Color.plAmber.opacity(0.2), lineWidth: 0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, PLSpacing.lg)
    }
}

struct StepsCard: View {
    let steps: Int
    let progress: Double
    let statusText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.plGreen)
                    Text("Steps today")
                        .plSectionLabel()
                }
                Spacer()
                Text(statusText)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }

            HStack(alignment: .bottom, spacing: 12) {
                Text(steps.formatted())
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.plGreen)
                Text("/ 10,000")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
                    .padding(.bottom, 4)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.plBgTertiary)
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.plGreen.opacity(0.7), Color.plGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * CGFloat(progress), 8), height: 6)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 6)
        }
        .plCard()
    }
}
