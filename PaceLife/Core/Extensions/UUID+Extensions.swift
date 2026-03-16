import Foundation

extension UUID {
    var supabaseString: String {
        self.uuidString.lowercased()
    }
}
