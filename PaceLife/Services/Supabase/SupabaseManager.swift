import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://vhgnnujzcjjugbneuwhn.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoZ25udWp6Y2pqdWdibmV1d2huIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1ODg5MDgsImV4cCI6MjA4OTE2NDkwOH0.JjtPfC3P1V-pAZ4UrHDSbTNvxIlNHlrL3TCKqfWo4EA",
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    storage: KeychainLocalStorage(service: "supabase", accessGroup: nil),
                    autoRefreshToken: true,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
