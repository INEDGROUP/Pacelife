import SwiftUI
import HealthKit

struct CheckinView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var userManager: UserManager
    @StateObject private var healthKit = HealthKitService.shared
    @State private var energy: Double = 70
    @State private var sleep: Double = 7
    @State private var mood: Int = 3
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var saved = false
    @State private var sleepAutoFilled = false

    var body: some View {
        ZStack {
            Color.plBg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Check-in")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                        Text(Date().formatted(.dateTime.weekday(.wide).day().month()))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if healthKit.isAuthorized {
                            HealthSummaryCard(healthKit: healthKit)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            HealthConnectCard {
                                Task {
                                    let granted = await healthKit.requestAuthorization()
                                    if granted && healthKit.lastNightSleep > 0 {
                                        withAnimation {
                                            sleep = min(healthKit.lastNightSleep, 12)
                                            sleepAutoFilled = true
                                        }
                                    }
                                }
                            }
                        }

                        EnergySliderCard(energy: $energy)

                        SleepSliderCard(
                            sleep: $sleep,
                            autoFilled: sleepAutoFilled,
                            healthSleep: healthKit.lastNightSleep
                        )

                        MoodCard(mood: $mood)

                        NotesCard(notes: $notes)

                        if saved {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.plGreen)
                                Text("Check-in saved!")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(Color.plGreen)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

                        PLPrimaryButton(
                            title: isSaving ? "Saving..." : "Save Check-in",
                            icon: isSaving ? "hourglass" : "checkmark"
                        ) {
                            Task { await saveCheckin() }
                        }
                        .disabled(isSaving)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
        }
        .onAppear {
            if healthKit.isAuthorized && healthKit.lastNightSleep > 0 {
                sleep = min(healthKit.lastNightSleep, 12)
                sleepAutoFilled = true
            }
            Task { await healthKit.fetchAllData() }
        }
    }

    private func saveCheckin() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        isSaving = true
        do {
            _ = try await CheckinService.shared.saveCheckin(
                userId: userId,
                energy: Int(energy),
                sleepHours: sleep,
                mood: mood,
                notes: notes.isEmpty ? nil : notes
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { saved = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try await Task.sleep(nanoseconds: 1_200_000_000)
            await userManager.loadUserData(userId: userId)
            isPresented = false
        } catch {
            print("Checkin error: \(error)")
        }
        isSaving = false
    }
}

struct HealthSummaryCard: View {
    @ObservedObject var healthKit: HealthKitService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.plRed)
                Text("From Apple Health · today")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }

            HStack(spacing: 10) {
                HealthStatPill(
                    icon: "figure.walk",
                    value: healthKit.todaySteps.formatted(),
                    label: "steps",
                    color: .plGreen,
                    progress: healthKit.stepProgress
                )
                HealthStatPill(
                    icon: "moon.stars.fill",
                    value: healthKit.lastNightSleep > 0 ? String(format: "%.1fh", healthKit.lastNightSleep) : "—",
                    label: healthKit.sleepQualityText,
                    color: healthKit.sleepQualityColor,
                    progress: min(healthKit.lastNightSleep / 9.0, 1.0)
                )
                if healthKit.todayActiveEnergy > 0 {
                    HealthStatPill(
                        icon: "flame.fill",
                        value: "\(Int(healthKit.todayActiveEnergy))",
                        label: "kcal",
                        color: .plAmber,
                        progress: min(healthKit.todayActiveEnergy / 500.0, 1.0)
                    )
                }
            }
        }
        .plCard()
    }
}

struct HealthStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.plTextPrimary)

            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(Color.plTextTertiary)
                .multilineTextAlignment(.center)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.plBgTertiary)
                    .frame(height: 3)
                Capsule()
                    .fill(color)
                    .frame(width: max(CGFloat(progress) * 60, 4), height: 3)
            }
            .frame(width: 60)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
        .overlay(RoundedRectangle(cornerRadius: PLRadius.md).strokeBorder(color.opacity(0.15), lineWidth: 0.5))
    }
}

struct HealthConnectCard: View {
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.plRed.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.plRed)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Connect Apple Health")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                Text("Auto-fill sleep and steps")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.plTextTertiary)
            }
            Spacer()
            Button(action: onConnect) {
                Text("Connect")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plBg)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.plRed)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .plCard()
    }
}

struct EnergySliderCard: View {
    @Binding var energy: Double

    var energyColor: Color {
        if energy >= 80 { return .plGreen }
        if energy >= 60 { return .plAmber }
        return .plRed
    }

    var energyLabel: String {
        switch Int(energy) {
        case 80...100: return "High energy 🔥"
        case 60...79: return "Good energy ⚡"
        case 40...59: return "Moderate 😐"
        case 20...39: return "Low energy 😴"
        default: return "Very low 😔"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(energyColor)
                    Text("Energy Level")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(energy))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(energyColor)
                    Text(energyLabel)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                }
            }
            Slider(value: $energy, in: 1...100, step: 1)
                .tint(energyColor)
        }
        .plCard()
    }
}

struct SleepSliderCard: View {
    @Binding var sleep: Double
    let autoFilled: Bool
    let healthSleep: Double

    var sleepColor: Color {
        if sleep >= 8 { return .plGreen }
        if sleep >= 6 { return .plBlue }
        return .plAmber
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(sleepColor)
                    Text("Sleep Hours")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1fh", sleep))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(sleepColor)
                    if autoFilled {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.plRed)
                            Text("Auto-filled")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Color.plRed)
                        }
                    }
                }
            }
            Slider(value: $sleep, in: 0...12, step: 0.5)
                .tint(sleepColor)

            if autoFilled && abs(sleep - healthSleep) > 0.4 {
                Button(action: { sleep = min(healthSleep, 12) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                        Text("Reset to Health data (\(String(format: "%.1fh", healthSleep)))")
                            .font(.system(size: 12, design: .rounded))
                    }
                    .foregroundStyle(Color.plRed.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .plCard()
    }
}

struct MoodCard: View {
    @Binding var mood: Int

    struct MoodOption {
        let value: Int
        let symbol: String
        let label: String
        let colors: [Color]
    }

    let options: [MoodOption] = [
        MoodOption(value: 1, symbol: "cloud.rain.fill", label: "Low", colors: [Color(hex: "FF6B6B"), Color(hex: "FF4444")]),
        MoodOption(value: 2, symbol: "minus.circle.fill", label: "Meh", colors: [Color(hex: "FFB347"), Color(hex: "FF9500")]),
        MoodOption(value: 3, symbol: "checkmark.circle.fill", label: "Good", colors: [Color(hex: "6B8FFF"), Color(hex: "4A6FF5")]),
        MoodOption(value: 4, symbol: "face.smiling.fill", label: "Great", colors: [Color(hex: "4CFFA0"), Color(hex: "00C875")]),
        MoodOption(value: 5, symbol: "star.circle.fill", label: "Amazing", colors: [Color(hex: "FFD700"), Color(hex: "FF9500")])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                PLGradientIcon(symbol: "heart.fill", size: 13, colors: [Color(hex: "FF6B6B"), Color(hex: "FF9500")])
                Text("How do you feel?")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
            }
            HStack(spacing: 8) {
                ForEach(options, id: \.value) { option in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { mood = option.value }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: option.symbol)
                                .font(.system(size: mood == option.value ? 26 : 20, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: mood == option.value ? option.colors : [Color.plTextTertiary, Color.plTextTertiary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(mood == option.value ? 1.1 : 1.0)
                                .shadow(
                                    color: mood == option.value ? option.colors[0].opacity(0.4) : .clear,
                                    radius: 6
                                )
                            Text(option.label)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(mood == option.value ? option.colors[0] : Color.plTextTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            mood == option.value
                            ? LinearGradient(colors: option.colors.map { $0.opacity(0.1) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: PLRadius.md)
                                .strokeBorder(
                                    mood == option.value ? option.colors[0].opacity(0.3) : Color.clear,
                                    lineWidth: 0.5
                                )
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: mood)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .plCard()
    }
}

struct NotesCard: View {
    @Binding var notes: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .foregroundStyle(Color.plTextTertiary)
                Text("Notes (optional)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
            }
            TextField("How are you feeling today?", text: $notes, axis: .vertical)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.plTextPrimary)
                .lineLimit(3...6)
                .focused($isFocused)
        }
        .plCard()
    }
}
