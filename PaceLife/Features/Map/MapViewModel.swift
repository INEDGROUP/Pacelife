import Foundation
import MapKit
import SwiftUI
import CoreLocation

@MainActor
class MapViewModel: NSObject, ObservableObject {
    @Published var spots: [Spot] = []
    @Published var routes: [PLRoute] = []
    @Published var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var activeLayer: MapLayer = .spots
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentRouteCoordinates: [[Double]] = []
    @Published var recordingDistance: Double = 0
    @Published var recordingDuration: Int = 0
    @Published var autoStopWarning = false

    private let locationManager = CLLocationManager()
    private var lastRecordedLocation: CLLocation?
    private var recordingTimer: Timer?
    private var autoStopTimer: Timer?
    private var lastMovementTime: Date?
    private let autoStopInterval: TimeInterval = 300

    enum MapLayer: CaseIterable {
        case spots, routes, all

        var title: String {
            switch self {
            case .spots: return "Spots"
            case .routes: return "Routes"
            case .all: return "All"
            }
        }

        var icon: String {
            switch self {
            case .spots: return "mappin.circle.fill"
            case .routes: return "figure.walk.circle.fill"
            case .all: return "map.circle.fill"
            }
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .fitness
    }

    func startLocationTracking() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func loadData() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        do {
            spots = try await SpotService.shared.fetchSpots(userId: userId)
            routes = try await RouteService.shared.fetchRoutes(userId: userId)
        } catch {
            print("Map load error: \(error)")
        }
    }

    func addSpot(title: String, category: String, notes: String?) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        guard let location = locationManager.location else { return }
        let lat = location.coordinate.latitude + Double.random(in: -0.000005...0.000005)
        let lng = location.coordinate.longitude + Double.random(in: -0.000005...0.000005)
        do {
            let spot = try await SpotService.shared.saveSpot(
                userId: userId,
                title: title,
                category: category,
                latitude: lat,
                longitude: lng,
                notes: notes
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                spots.append(spot)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Add spot error: \(error)")
        }
    }

    func incrementVisit(_ spot: Spot) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        do {
            try await SpotService.shared.incrementVisitCount(spotId: spot.id, userId: userId)
            if let idx = spots.firstIndex(where: { $0.id == spot.id }) {
                spots[idx].visitCount += 1
                spots[idx].lastVisitedAt = Date()
            }
        } catch {
            print("Increment visit error: \(error)")
        }
    }

    func deleteRoute(_ route: PLRoute) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        do {
            try await RouteService.shared.deleteRoute(routeId: route.id, userId: userId)
            withAnimation {
                routes.removeAll { $0.id == route.id }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Delete route error: \(error)")
        }
    }

    func renameRoute(_ route: PLRoute, title: String) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        do {
            try await RouteService.shared.renameRoute(routeId: route.id, userId: userId, title: title)
            if let index = routes.firstIndex(where: { $0.id == route.id }) {
                routes[index].title = title
            }
        } catch {
            print("Rename route error: \(error)")
        }
    }

    func renameSpot(_ spot: Spot, title: String) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        do {
            try await SpotService.shared.renameSpot(spotId: spot.id, userId: userId, title: title)
            if let index = spots.firstIndex(where: { $0.id == spot.id }) {
                spots[index].title = title
            }
        } catch {
            print("Rename spot error: \(error)")
        }
    }

    func deleteSpot(_ spot: Spot) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        do {
            try await SpotService.shared.deleteSpot(spotId: spot.id, userId: userId)
            withAnimation { spots.removeAll { $0.id == spot.id } }
        } catch {
            print("Delete spot error: \(error)")
        }
    }

    func startRecording() {
        isRecording = true
        isPaused = false
        currentRouteCoordinates = []
        recordingDistance = 0
        recordingDuration = 0
        lastRecordedLocation = nil
        lastMovementTime = Date()
        autoStopWarning = false

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.startUpdatingLocation()

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isRecording && !self.isPaused else { return }
                self.recordingDuration += 1
                self.checkAutoStop()
                if self.recordingDuration == 7200 {
                    await NotificationService.shared.scheduleRouteLongSession()
                }
            }
        }

        Task {
            await NotificationService.shared.scheduleRouteAutoStop()
        }
    }

    func pauseRecording() {
        isPaused = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func resumeRecording() {
        isPaused = false
        lastMovementTime = Date()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func stopRecording() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        isRecording = false
        isPaused = false
        autoStopWarning = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        autoStopTimer?.invalidate()
        autoStopTimer = nil

        NotificationService.shared.cancelRouteAutoStop()
        NotificationService.shared.cancelRouteLongSession()

        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 20

        guard currentRouteCoordinates.count > 1 else { return }

        let distanceKm = recordingDistance / 1000
        guard distanceKm > 0.05 else { return }

        let intensity: String
        let pace = distanceKm > 0 ? Double(recordingDuration) / 60.0 / distanceKm : 0
        if pace < 6 { intensity = "high" }
        else if pace < 10 { intensity = "medium" }
        else { intensity = "low" }

        do {
            let routeTitle = generateRouteTitle()
            let durationMinutes = recordingDuration / 60

            let route = try await RouteService.shared.saveRoute(
                userId: userId,
                title: routeTitle,
                distanceKm: distanceKm,
                durationMinutes: durationMinutes,
                intensity: intensity,
                coordinates: currentRouteCoordinates
            )
            withAnimation { routes.append(route) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                activeLayer = .routes
            }

            await NotificationService.shared.scheduleRouteSaved(
                title: routeTitle,
                distanceKm: distanceKm,
                durationMinutes: durationMinutes
            )

            await checkAchievements(distanceKm: distanceKm)

        } catch {
            print("Save route error: \(error)")
        }
    }

    private func checkAchievements(distanceKm: Double) async {
        let totalRoutes = routes.count
        let streakDays = UserManager.shared.profile?.streakDays ?? 0

        if totalRoutes == 1 {
            await NotificationService.shared.scheduleAchievement(
                title: "First route! 🎉",
                body: String(format: "You've walked %.1fkm on your first recorded route!", distanceKm)
            )
        } else if totalRoutes == 10 {
            await NotificationService.shared.scheduleAchievement(
                title: "10 routes recorded! 🗺️",
                body: "You're becoming a real explorer. Keep going!"
            )
        }

        if streakDays == 7 {
            await NotificationService.shared.scheduleAchievement(
                title: "7-day streak! 🔥",
                body: "You're building a real habit. You're in the top 20% of PaceLife users!"
            )
        } else if streakDays == 30 {
            await NotificationService.shared.scheduleAchievement(
                title: "30-day streak! 🏆",
                body: "Incredible consistency. You're in the top 5% of PaceLife users!"
            )
        }
    }

    func discardRecording() {
        isRecording = false
        isPaused = false
        autoStopWarning = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        currentRouteCoordinates = []
        recordingDistance = 0
        recordingDuration = 0
        lastRecordedLocation = nil
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func checkAutoStop() {
        guard let lastMove = lastMovementTime else { return }
        let timeSinceMove = Date().timeIntervalSince(lastMove)
        if timeSinceMove > autoStopInterval - 60 && !autoStopWarning {
            autoStopWarning = true
        }
        if timeSinceMove > autoStopInterval {
            Task { await stopRecording() }
        }
    }

    private func generateRouteTitle() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let dateStr = Date().formatted(.dateTime.day().month(.abbreviated))
        switch hour {
        case 5..<10: return "Morning run · \(dateStr)"
        case 10..<14: return "Midday walk · \(dateStr)"
        case 14..<18: return "Afternoon route · \(dateStr)"
        case 18..<22: return "Evening walk · \(dateStr)"
        default: return "Night route · \(dateStr)"
        }
    }

    var formattedDistance: String {
        if recordingDistance < 1000 {
            return "\(Int(recordingDistance))m"
        }
        return String(format: "%.2fkm", recordingDistance / 1000)
    }

    var formattedDuration: String {
        let h = recordingDuration / 3600
        let m = (recordingDuration % 3600) / 60
        let s = recordingDuration % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var estimatedCalories: Int {
        let weightKg = UserManager.shared.profile?.weightKg ?? 70
        let distanceKm = recordingDistance / 1000
        return Int(distanceKm * weightKg * 1.036)
    }
}

extension MapViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        guard location.horizontalAccuracy < 20 else { return }

        if isRecording && !isPaused {
            if let last = lastRecordedLocation {
                let distance = location.distance(from: last)
                if distance > 3 {
                    currentRouteCoordinates.append([
                        location.coordinate.latitude,
                        location.coordinate.longitude
                    ])
                    recordingDistance += distance
                    lastRecordedLocation = location
                    lastMovementTime = Date()
                    autoStopWarning = false
                }
            } else {
                currentRouteCoordinates.append([
                    location.coordinate.latitude,
                    location.coordinate.longitude
                ])
                lastRecordedLocation = location
                lastMovementTime = Date()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}
