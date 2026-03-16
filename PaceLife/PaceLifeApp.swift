import SwiftUI

@main
struct PaceLifeApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var authService = AuthService.shared
    @StateObject private var userManager = UserManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            Group {
                if !authService.isInitialized {
                    SplashView()
                } else if !hasCompletedOnboarding {
                    OnboardingView()
                        .environmentObject(authService)
                        .environmentObject(userManager)
                } else if authService.isAuthenticated && userManager.hasLoadedOnce {
                    ContentView()
                        .environmentObject(authService)
                        .environmentObject(userManager)
                        .environmentObject(notificationService)
                } else if authService.isAuthenticated && !userManager.hasLoadedOnce {
                    SplashView()
                        .task {
                            if let userId = authService.currentUser?.id {
                                await userManager.loadUserData(userId: userId)
                            }
                        }
                } else {
                    AuthView()
                        .environmentObject(authService)
                        .environmentObject(userManager)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: authService.isInitialized)
            .animation(.easeInOut(duration: 0.25), value: authService.isAuthenticated)
            .animation(.easeInOut(duration: 0.25), value: userManager.hasLoadedOnce)
            .task {
                notificationService.setupNotificationCategories()
                await notificationService.checkAuthorization()
                await StoreKitService.shared.updateSubscriptionStatus()
            }
            .onChange(of: authService.isAuthenticated) { isAuth in
                if isAuth {
                    Task {
                        let granted = await notificationService.requestAuthorization()
                        if granted {
                            await notificationService.scheduleAllLocalNotifications()
                            await notificationService.checkAndScheduleStreakReminder()
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: {
                    guard let sub = userManager.subscription else { return false }
                    if StoreKitService.shared.isSubscribed { return false }
                    if sub.status == "trial" {
                        if let trialEnd = sub.trialEndsAt {
                            return trialEnd < Date()
                        }
                    }
                    if sub.status == "expired" { return true }
                    return false
                },
                set: { _ in }
            )) {
                PaywallView(isPresented: .constant(true))
                    .environmentObject(userManager)
                    .interactiveDismissDisabled(true)
            }
            .onOpenURL { url in
                Task {
                    if url.host == "reset-password" {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                           let fragment = components.fragment {
                            let params = fragment.split(separator: "&").reduce(into: [String: String]()) { dict, pair in
                                let parts = pair.split(separator: "=", maxSplits: 1)
                                if parts.count == 2 {
                                    dict[String(parts[0])] = String(parts[1])
                                }
                            }
                            if let accessToken = params["access_token"],
                               let refreshToken = params["refresh_token"] {
                                try? await SupabaseManager.shared.client.auth.setSession(
                                    accessToken: accessToken,
                                    refreshToken: refreshToken
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
