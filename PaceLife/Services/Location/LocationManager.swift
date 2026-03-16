import Foundation
import CoreLocation
import Combine
import Supabase

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

class LocationManager: NSObject, ObservableObject {
    static weak var shared: LocationManager?

    private let manager = CLLocationManager()

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?

    private var lastNearbyCheck: Date?

    override init() {
        super.init()
        LocationManager.shared = self
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
    }

    @MainActor
    private func checkNearbySpots(location: CLLocation) async {
        if let lastCheck = lastNearbyCheck,
           Date().timeIntervalSince(lastCheck) < 300 { return }
        lastNearbyCheck = Date()
        guard let userId = AuthService.shared.currentUser?.id else { return }
        guard let session = try? await SupabaseManager.shared.client.auth.session else { return }
        let supabaseURL = "https://vhgnnujzcjjugbneuwhn.supabase.co"
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoZ25udWp6Y2pqdWdibmV1d2huIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1ODg5MDgsImV4cCI6MjA4OTE2NDkwOH0.JjtPfC3P1V-pAZ4UrHDSbTNvxIlNHlrL3TCKqfWo4EA"
        guard let url = URL(string: "\(supabaseURL)/functions/v1/nearby-spots") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 10
        let body: [String: Any] = [
            "user_id": userId.supabaseString,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("Nearby spots: \(http.statusCode)")
            }
        } catch {
            print("Nearby spots check error: \(error)")
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
        }
        Task {
            await checkNearbySpots(location: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }
}
