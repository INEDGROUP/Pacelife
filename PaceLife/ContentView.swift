import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab: Int = 0
    @State private var showCheckin = false
    @State private var showPaywall = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView(locationManager: locationManager)
                    .environmentObject(userManager)
                    .sheet(isPresented: $showCheckin) {
                        CheckinView(isPresented: $showCheckin)
                            .environmentObject(userManager)
                    }
            }
            Tab("Map", systemImage: "map.fill", value: 1) {
                MapView()
                    .environmentObject(userManager)
            }
            Tab("Insights", systemImage: "sparkles", value: 2) {
                InsightsView()
                    .environmentObject(userManager)
            }
            Tab("Profile", systemImage: "person.fill", value: 3) {
                ProfileView()
                    .environmentObject(userManager)
                    .environmentObject(authService)
            }
        }
        .preferredColorScheme(.dark)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCheckin)) { _ in
            selectedTab = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCheckin = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openInsights)) { _ in
            selectedTab = 2
        }
        .onReceive(NotificationCenter.default.publisher(for: .openProfile)) { _ in
            selectedTab = 3
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMap)) { _ in
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPaywall)) { _ in
            showPaywall = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveRoute)) { _ in
            selectedTab = 1
            NotificationCenter.default.post(name: .saveRouteAction, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .discardRoute)) { _ in
            selectedTab = 1
            NotificationCenter.default.post(name: .discardRouteAction, object: nil)
        }
        .onChange(of: locationManager.userLocation) { coord in
            guard let coord = coord else { return }
            Task {
                await userManager.updateLocation(
                    lat: coord.latitude,
                    lng: coord.longitude
                )
            }
        }
        .onAppear {
            locationManager.startTracking()
        }
    }
}

