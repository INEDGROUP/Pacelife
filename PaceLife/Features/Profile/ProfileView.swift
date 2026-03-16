import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var authService: AuthService
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.plBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ProfileHeaderCard()
                            .environmentObject(userManager)

                        SubscriptionCard()
                            .environmentObject(userManager)

                        StatsCard()
                            .environmentObject(userManager)

                        VStack(spacing: 0) {
                            NavigationLink(destination: NotificationSettingsView().environmentObject(userManager)) {
                                HStack(spacing: 14) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.plBlue)
                                        .frame(width: 28)
                                    Text("Notifications")
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundStyle(Color.plTextPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.plTextTertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                            Divider().background(Color.plBorder).padding(.leading, 56)
                            ProfileMenuItem(icon: "lock.fill", color: .plAmber, title: "Privacy") {}
                            Divider().background(Color.plBorder).padding(.leading, 56)
                            ProfileMenuItem(icon: "questionmark.circle.fill", color: .plGreen, title: "Help & Support") {}
                            Divider().background(Color.plBorder).padding(.leading, 56)
                            ProfileMenuItem(icon: "arrow.right.circle.fill", color: .plRed, title: "Sign Out", destructive: true) {
                                showSignOutAlert = true
                            }
                        }
                        .plCard(padding: 0)
                        .padding(.bottom, 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Profile")
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task { await authService.signOut() }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

struct ProfileHeaderCard: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showCompleteProfile = false

    var completionPercent: Int {
        guard let profile = userManager.profile else { return 0 }
        var count = 0
        if let name = profile.name, !name.isEmpty { count += 1 }
        if profile.gender != nil { count += 1 }
        if profile.heightCm != nil { count += 1 }
        if profile.weightKg != nil { count += 1 }
        if profile.city != nil { count += 1 }
        return Int(Double(count) / 5.0 * 100)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                PLAvatarPicker(size: 72)
                    .environmentObject(userManager)

                VStack(alignment: .leading, spacing: 6) {
                    Text(userManager.profile?.name ?? userManager.firstName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)

                    if let city = userManager.profile?.city, !city.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.plBlue)
                            Text(city)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Color.plTextTertiary)
                        }
                    }

                    if let dob = userManager.profile?.dateOfBirth {
                        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
                        HStack(spacing: 4) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "FF6B6B"))
                            Text("\(age) years old")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Color.plTextTertiary)
                        }
                    }

                    Text("Member since \(userManager.profile?.createdAt.formatted(.dateTime.month().year()) ?? "")")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary.opacity(0.7))
                }

                Spacer()
            }

            if completionPercent < 100 {
                Button(action: { showCompleteProfile = true }) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Complete your profile")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.plTextPrimary)
                                Spacer()
                                Text("\(completionPercent)%")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.plAmber)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.plBgTertiary)
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.plAmber, Color.plGreen],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * CGFloat(completionPercent) / 100, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                    .padding(12)
                    .background(Color.plAmber.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: PLRadius.md)
                            .strokeBorder(Color.plAmber.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .plCard()
        .navigationDestination(isPresented: $showCompleteProfile) {
            CompleteProfileView()
                .environmentObject(userManager)
        }
    }
}

struct SubscriptionCard: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var storeKit = StoreKitService.shared
    @State private var showPaywall = false

    var isActive: Bool {
        storeKit.isSubscribed || userManager.subscription?.status == "active"
    }

    var statusColor: Color {
        if isActive { return .plGreen }
        if userManager.isTrialActive { return .plAmber }
        return .plRed
    }

    var statusText: String {
        if storeKit.isSubscribed { return "\(storeKit.activeSubscriptionName) · Active" }
        if userManager.isTrialActive { return "Trial · \(userManager.trialDaysLeft) days left" }
        return "No active plan"
    }

    var planText: String {
        if storeKit.isSubscribed { return "PaceLife Pro" }
        if userManager.isTrialActive { return "Free trial" }
        return "Subscribe to unlock Pro"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Subscription")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                    Text(planText)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.plTextTertiary)
                }
                Spacer()
                Text(statusText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            if !isActive {
                Button(action: { showPaywall = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text(userManager.isTrialActive ? "Upgrade to Pro" : "Subscribe Now")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Spacer()
                        if userManager.isTrialActive {
                            Text("\(userManager.trialDaysLeft) days left")
                                .font(.system(size: 11, design: .rounded))
                                .opacity(0.8)
                        }
                    }
                    .foregroundStyle(Color.plBg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.plGreen, Color(hex: "00C875")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
                    .shadow(color: Color.plGreen.opacity(0.3), radius: 8)
                }
                .buttonStyle(.plain)
            }
        }
        .plCard()
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
                .environmentObject(userManager)
        }
    }
}

struct StatsCard: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var healthKit = HealthKitService.shared
    @State private var showCompleteProfile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your Stats")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plTextPrimary)
                Spacer()
                Button(action: { showCompleteProfile = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .medium))
                        Text("Edit")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.plGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.plGreen.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.plGreen.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                StatItem(
                    value: "\(userManager.profile?.streakDays ?? 0)",
                    label: "Day streak",
                    color: Color(hex: "FF6B35"),
                    icon: "flame.fill"
                )
                StatItem(
                    value: "\(userManager.profile?.totalCheckins ?? 0)",
                    label: "Check-ins",
                    color: .plGreen,
                    icon: "checkmark.circle.fill"
                )
                StatItem(
                    value: healthKit.todaySteps == 0 ? "—" :
                           healthKit.todaySteps >= 1000 ?
                           String(format: "%.1fk", Double(healthKit.todaySteps) / 1000.0) :
                           "\(healthKit.todaySteps)",
                    label: "Steps today",
                    color: .plBlue,
                    icon: "figure.walk"
                )
            }

            if userManager.profile?.heightCm != nil ||
               userManager.profile?.weightKg != nil ||
               userManager.profile?.dateOfBirth != nil {

                Divider()
                    .background(Color.plBorder)

                HStack(spacing: 10) {
                    if let height = userManager.profile?.heightCm {
                        BodyStatPill(
                            label: "Height",
                            value: "\(height) cm",
                            icon: "ruler.fill",
                            color: Color.plAmber
                        )
                    }
                    if let weight = userManager.profile?.weightKg {
                        BodyStatPill(
                            label: "Weight",
                            value: "\(Int(weight)) kg",
                            icon: "scalemass",
                            color: Color(hex: "6B8FFF")
                        )
                    }
                    if let dob = userManager.profile?.dateOfBirth {
                        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
                        BodyStatPill(
                            label: "Age",
                            value: "\(age) yrs",
                            icon: "gift.fill",
                            color: Color(hex: "FF6B6B")
                        )
                    }
                }
            }
        }
        .plCard()
        .navigationDestination(isPresented: $showCompleteProfile) {
            CompleteProfileView()
                .environmentObject(userManager)
        }
        .task {
            await healthKit.fetchTodaySteps()
        }
    }
}

struct BodyStatPill: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.plTextPrimary)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.plTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: PLRadius.md)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
        )
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            PLIcon(symbol: icon, size: 16, color: color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.plTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: PLRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: PLRadius.md)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
        )
    }
}

struct ProfileMenuItem: View {
    let icon: String
    let color: Color
    let title: String
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(destructive ? Color.plRed : color)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(destructive ? Color.plRed : Color.plTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.plTextTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}
