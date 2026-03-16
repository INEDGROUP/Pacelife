import SwiftUI
import Charts

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @EnvironmentObject var userManager: UserManager
    @State private var appeared = false
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.plBg.ignoresSafeArea()

                if !userManager.hasAccess {
                    ProGateView(
                        feature: "Insights & Analytics",
                        icon: "chart.line.uptrend.xyaxis",
                        description: "Unlock your energy patterns, sleep correlations, route stats and AI insights history."
                    )
                    .navigationTitle("Insights")
                    .navigationBarTitleDisplayMode(.large)
                } else if viewModel.isLoading && viewModel.weekCheckins.isEmpty && !isRefreshing {
                    ProgressView()
                        .tint(Color.plGreen)
                } else if viewModel.currentCheckins.isEmpty && !isRefreshing {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            periodPicker
                                .opacity(appeared ? 1 : 0)
                                .animation(PLTheme.springSmooth.delay(0.05), value: appeared)

                            summaryCards
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(PLTheme.springSmooth.delay(0.1), value: appeared)

                            energyChartCard
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(PLTheme.springSmooth.delay(0.15), value: appeared)

                            if viewModel.avgSleep > 0 {
                                sleepChartCard
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 20)
                                    .animation(PLTheme.springSmooth.delay(0.2), value: appeared)
                            }

                            if viewModel.sleepEnergyCorrelation != 0 {
                                correlationCard
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 20)
                                    .animation(PLTheme.springSmooth.delay(0.25), value: appeared)
                            }

                            if !viewModel.routes.isEmpty {
                                routeStatsCard
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 20)
                                    .animation(PLTheme.springSmooth.delay(0.3), value: appeared)
                            }

                            if !viewModel.achievements.isEmpty {
                                achievementsCard
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 20)
                                    .animation(PLTheme.springSmooth.delay(0.35), value: appeared)
                            }

                            if !viewModel.aiInsights.isEmpty {
                                aiInsightsHistoryCard
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 20)
                                    .animation(PLTheme.springSmooth.delay(0.4), value: appeared)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        isRefreshing = true
                        await viewModel.loadData()
                        isRefreshing = false
                    }
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await viewModel.loadData()
            withAnimation(PLTheme.springSmooth) { appeared = true }
        }
        .onChange(of: viewModel.selectedPeriod) { _ in
            withAnimation(PLTheme.springSmooth) {}
        }
    }

    var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56))
                .foregroundStyle(Color.plTextTertiary)
            Text("No insights yet")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.plTextPrimary)
            Text("Log at least 3 check-ins to unlock\nyour personal insights and patterns")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Color.plTextTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(InsightsViewModel.Period.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        viewModel.selectedPeriod = period
                    }
                }) {
                    Text(period.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(viewModel.selectedPeriod == period ? Color.plBg : Color.plTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.selectedPeriod == period
                            ? Color.plGreen
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.plBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: PLRadius.lg)
                .strokeBorder(Color.plBorder, lineWidth: 0.5)
        )
    }

    var summaryCards: some View {
        HStack(spacing: 10) {
            InsightStatCard(
                icon: "bolt.fill",
                label: "Avg Energy",
                value: viewModel.avgEnergy > 0 ? "\(viewModel.avgEnergy)" : "—",
                color: energyColor(viewModel.avgEnergy),
                trend: viewModel.energyTrend
            )
            InsightStatCard(
                icon: "moon.stars.fill",
                label: "Avg Sleep",
                value: viewModel.avgSleep > 0 ? String(format: "%.1fh", viewModel.avgSleep) : "—",
                color: .plBlue,
                trend: "neutral"
            )
            InsightStatCard(
                icon: "face.smiling.fill",
                label: "Avg Mood",
                value: viewModel.avgMood > 0 ? String(format: "%.1f", viewModel.avgMood) : "—",
                color: .plAmber,
                trend: "neutral"
            )
        }
    }

    var energyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Energy")
                        .plSectionLabel()
                    HStack(spacing: 6) {
                        Text("\(viewModel.avgEnergy)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(energyColor(viewModel.avgEnergy))
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 3) {
                                Image(systemName: trendIcon(viewModel.energyTrend))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(trendColor(viewModel.energyTrend))
                                Text(trendText(viewModel.energyTrend))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(trendColor(viewModel.energyTrend))
                            }
                            Text("avg this \(viewModel.selectedPeriod.rawValue.lowercased())")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Color.plTextTertiary)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(energyColor(viewModel.avgEnergy))
                            .frame(width: 8, height: 8)
                            .shadow(color: energyColor(viewModel.avgEnergy).opacity(0.6), radius: 4)
                        Text("Best: \(viewModel.bestEnergyDay)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                    Text("\(viewModel.currentCheckins.count) check-ins")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                }
            }

            if #available(iOS 16.0, *) {
                let checkins = viewModel.currentCheckins.reversed() as [Checkin]
                let maxEnergy = checkins.map { $0.energy }.max() ?? 100
                let minEnergy = max(0, (checkins.map { $0.energy }.min() ?? 0) - 10)

                Chart(checkins) { checkin in
                    AreaMark(
                        x: .value("Date", checkin.checkedInAt, unit: .day),
                        yStart: .value("Min", minEnergy),
                        yEnd: .value("Energy", checkin.energy)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                energyColor(viewModel.avgEnergy).opacity(0.35),
                                energyColor(viewModel.avgEnergy).opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Date", checkin.checkedInAt, unit: .day),
                        y: .value("Energy", checkin.energy)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                energyColor(viewModel.avgEnergy).opacity(0.8),
                                energyColor(viewModel.avgEnergy)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Date", checkin.checkedInAt, unit: .day),
                        y: .value("Energy", checkin.energy)
                    )
                    .foregroundStyle(Color.plBg)
                    .symbolSize(60)

                    PointMark(
                        x: .value("Date", checkin.checkedInAt, unit: .day),
                        y: .value("Energy", checkin.energy)
                    )
                    .foregroundStyle(energyColor(viewModel.avgEnergy))
                    .symbolSize(30)

                    if checkin.energy == (checkins.map { $0.energy }.max() ?? 0) {
                        PointMark(
                            x: .value("Date", checkin.checkedInAt, unit: .day),
                            y: .value("Energy", checkin.energy)
                        )
                        .foregroundStyle(Color.plAmber)
                        .symbolSize(80)
                        .annotation(position: .top, spacing: 4) {
                            Text("\(checkin.energy)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.plAmber)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.plAmber.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    RuleMark(y: .value("Average", viewModel.avgEnergy))
                        .foregroundStyle(Color.plTextTertiary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .trailing, spacing: 2) {
                            Text("avg")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(Color.plTextTertiary)
                        }
                }
                .chartYScale(domain: max(0, minEnergy - 5)...min(105, maxEnergy + 10))
                .chartYAxis {
                    AxisMarks(
                        preset: .aligned,
                        position: .leading,
                        values: .stride(by: 25)
                    ) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                            .foregroundStyle(Color.plBorder.opacity(0.5))
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundStyle(Color.plTextTertiary.opacity(0.7))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(
                        values: .stride(
                            by: .day,
                            count: viewModel.selectedPeriod == .week ? 1 : 7
                        )
                    ) { _ in
                        AxisValueLabel(
                            format: viewModel.selectedPeriod == .week
                                ? .dateTime.weekday(.abbreviated)
                                : .dateTime.day().month(.abbreviated),
                            centered: true
                        )
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary.opacity(0.8))
                    }
                }
                .chartPlotStyle { plot in
                    plot.background(Color.plBgTertiary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 180)
                .id(viewModel.selectedPeriod)
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: PLRadius.lg)
                .fill(Color.plBgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: PLRadius.lg)
                        .strokeBorder(
                            LinearGradient(
                                colors: [energyColor(viewModel.avgEnergy).opacity(0.3), Color.plBorder],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [energyColor(viewModel.avgEnergy), energyColor(viewModel.avgEnergy).opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
        }
    }

    var sleepChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sleep")
                        .plSectionLabel()
                    HStack(spacing: 6) {
                        Text(viewModel.avgSleep > 0 ? String(format: "%.1fh", viewModel.avgSleep) : "—")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(sleepColor(viewModel.avgSleep))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(sleepQualityLabel(viewModel.avgSleep))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(sleepColor(viewModel.avgSleep))
                            Text("avg this \(viewModel.selectedPeriod.rawValue.lowercased())")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Color.plTextTertiary)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.plGreen)
                        Text("Target: 8h")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                    let goodNights = viewModel.currentCheckins.filter { ($0.sleepHours ?? 0) >= 7 }.count
                    let total = viewModel.currentCheckins.filter { $0.sleepHours != nil }.count
                    if total > 0 {
                        Text("\(goodNights)/\(total) good nights")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(goodNights > total / 2 ? Color.plGreen : Color.plAmber)
                    }
                }
            }

            if #available(iOS 16.0, *) {
                let checkins = viewModel.currentCheckins
                    .filter { $0.sleepHours != nil }
                    .reversed() as [Checkin]

                Chart(checkins) { checkin in
                    let hours = checkin.sleepHours ?? 0
                    let barColor: Color = hours >= 7 ? .plBlue : hours >= 6 ? .plAmber : .plRed

                    BarMark(
                        x: .value("Date", checkin.checkedInAt, unit: .day),
                        y: .value("Hours", hours),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [barColor, barColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                    .annotation(position: .top, spacing: 2) {
                        Text(String(format: "%.0fh", hours))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(barColor)
                    }

                    RuleMark(y: .value("Target", 8))
                        .foregroundStyle(Color.plGreen.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .annotation(position: .trailing, spacing: 2) {
                            Text("8h")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.plGreen)
                        }
                }
                .chartYScale(domain: 0...12)
                .chartYAxis {
                    AxisMarks(
                        preset: .aligned,
                        position: .leading,
                        values: [0, 4, 6, 8, 10]
                    ) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                            .foregroundStyle(Color.plBorder.opacity(0.5))
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)h")
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundStyle(Color.plTextTertiary.opacity(0.7))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(
                        values: .stride(
                            by: .day,
                            count: viewModel.selectedPeriod == .week ? 1 : 7
                        )
                    ) { _ in
                        AxisValueLabel(
                            format: viewModel.selectedPeriod == .week
                                ? .dateTime.weekday(.abbreviated)
                                : .dateTime.day().month(.abbreviated),
                            centered: true
                        )
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary.opacity(0.8))
                    }
                }
                .chartPlotStyle { plot in
                    plot.background(Color.plBgTertiary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 160)
                .id(viewModel.selectedPeriod)
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }

            HStack(spacing: 14) {
                ForEach([
                    (Color.plBlue, "7h+ good"),
                    (Color.plAmber, "6-7h fair"),
                    (Color.plRed, "<6h low")
                ], id: \.1) { color, label in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: 14, height: 10)
                        Text(label)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: PLRadius.lg)
                .fill(Color.plBgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: PLRadius.lg)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.plBlue.opacity(0.3), Color.plBorder],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.plBlue, Color.plBlue.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
        }
    }

    var correlationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sleep → Energy correlation")
                .plSectionLabel()

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.plBgTertiary, lineWidth: 6)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: abs(viewModel.sleepEnergyCorrelation))
                        .stroke(
                            correlationColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    Text(String(format: "%.0f%%", abs(viewModel.sleepEnergyCorrelation) * 100))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(correlationColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.correlationText)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                        .lineSpacing(3)

                    if viewModel.sleepEnergyCorrelation > 0.3 {
                        Text("Sleep more tonight for better energy tomorrow")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .plCard()
    }

    var routeStatsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Route activity")
                .plSectionLabel()

            HStack(spacing: 10) {
                RouteStatPill(
                    icon: "figure.walk",
                    value: "\(viewModel.routes.count)",
                    label: "routes",
                    color: .plGreen
                )
                RouteStatPill(
                    icon: "map.fill",
                    value: String(format: "%.1f", viewModel.totalRouteDistance),
                    label: "km total",
                    color: .plBlue
                )
                RouteStatPill(
                    icon: "flame.fill",
                    value: "\(viewModel.totalRouteCalories)",
                    label: "kcal",
                    color: Color(hex: "FF6B35")
                )
            }

            if let longest = viewModel.longestRoute {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "FFD700"))
                    Text("Longest: \(longest.title)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                    Spacer()
                    if let dist = longest.distanceKm {
                        Text(String(format: "%.1f km", dist))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                }
                .padding(10)
                .background(Color(hex: "FFD700").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: PLRadius.md)
                        .strokeBorder(Color(hex: "FFD700").opacity(0.2), lineWidth: 0.5)
                )
            }
        }
        .plCard()
    }

    var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Achievements")
                    .plSectionLabel()
                Spacer()
                Text("\(viewModel.achievements.count) earned")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(viewModel.achievements.prefix(6)) { achievement in
                    AchievementBadge(achievement: achievement)
                }
            }
        }
        .plCard()
    }

    var aiInsightsHistoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AI insights history")
                .plSectionLabel()

            VStack(spacing: 10) {
                ForEach(viewModel.aiInsights.prefix(5)) { insight in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.plGreen)
                                    .frame(width: 5, height: 5)
                                Text("PaceLife AI")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.plGreen)
                            }
                            Spacer()
                            Text(insight.createdAt.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Color.plTextTertiary)
                        }
                        Text(insight.body)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Color.plTextSecondary)
                            .lineSpacing(3)
                    }
                    .padding(12)
                    .background(Color.plBgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))

                    if insight.id != viewModel.aiInsights.prefix(5).last?.id {
                        Divider().background(Color.plBorder)
                    }
                }
            }
        }
        .plCard()
    }

    private func energyColor(_ value: Int) -> Color {
        if value >= 75 { return .plGreen }
        if value >= 55 { return .plAmber }
        return .plRed
    }

    private func sleepColor(_ hours: Double) -> Color {
        if hours >= 8 { return .plGreen }
        if hours >= 7 { return .plBlue }
        if hours >= 6 { return .plAmber }
        return .plRed
    }

    private func sleepQualityLabel(_ hours: Double) -> String {
        if hours >= 8 { return "Excellent" }
        if hours >= 7 { return "Good" }
        if hours >= 6 { return "Fair" }
        if hours > 0 { return "Poor" }
        return "—"
    }

    private func trendIcon(_ trend: String) -> String {
        switch trend {
        case "up": return "arrow.up.right"
        case "down": return "arrow.down.right"
        default: return "minus"
        }
    }

    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "up": return .plGreen
        case "down": return .plRed
        default: return .plTextTertiary
        }
    }

    private func trendText(_ trend: String) -> String {
        switch trend {
        case "up": return "Improving"
        case "down": return "Declining"
        default: return "Stable"
        }
    }

    private var correlationColor: Color {
        let r = viewModel.sleepEnergyCorrelation
        if r > 0.6 { return .plGreen }
        if r > 0.3 { return .plAmber }
        return .plTextTertiary
    }
}

struct InsightStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    let trend: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
                if trend == "up" {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.plGreen)
                } else if trend == "down" {
                    Image(systemName: "arrow.down.right")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.plRed)
                }
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.plTextTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: PLRadius.lg)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
        )
    }
}

struct RouteStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.plTextPrimary)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.plTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: PLRadius.md)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
        )
    }
}

struct AchievementBadge: View {
    let achievement: PLAchievement

    var badgeColor: Color {
        switch achievement.type {
        case let t where t.contains("streak"):
            return Color(hex: "FF6B35")
        case let t where t.contains("route"):
            return Color.plBlue
        case let t where t.contains("steps"):
            return Color.plGreen
        default:
            return Color(hex: "FFD700")
        }
    }

    var badgeIcon: String {
        switch achievement.type {
        case let t where t.contains("streak"):
            return "flame.fill"
        case let t where t.contains("route"):
            return "figure.walk"
        case let t where t.contains("steps"):
            return "shoe.fill"
        default:
            return "star.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: badgeIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(badgeColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(achievement.earnedAt.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }
        }
        .padding(10)
        .background(Color.plBgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
    }
}
