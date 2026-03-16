import Foundation
import Supabase
import SwiftUI
import AuthenticationServices
import CryptoKit

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    private let client = SupabaseManager.shared.client

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var isInitialized = false
    @Published var errorMessage: String?

    private init() {
        Task {
            await initialize()
        }
    }

    func initialize() async {
        do {
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = true
            await UserManager.shared.loadUserData(userId: session.user.id)
        } catch {
            isAuthenticated = false
            currentUser = nil
        }
        isInitialized = true
        Task { await listenToAuthChanges() }
    }

    func listenToAuthChanges() async {
        for await (event, session) in await client.auth.authStateChanges {
            switch event {
            case .signedIn:
                if let user = session?.user {
                    currentUser = user
                    isAuthenticated = true
                    await UserManager.shared.loadUserData(userId: user.id)
                }
            case .signedOut:
                currentUser = nil
                isAuthenticated = false
                UserManager.shared.clearData()
            case .tokenRefreshed:
                currentUser = session?.user
            default:
                break
            }
        }
    }

    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["name": AnyJSON.string(name)]
            )
            currentUser = response.user
            isAuthenticated = true
            await UserManager.shared.loadUserData(userId: response.user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            currentUser = session.user
            isAuthenticated = true
            await UserManager.shared.loadUserData(userId: session.user.id)
        } catch {
            errorMessage = "Invalid email or password"
        }
        isLoading = false
    }

    func signInWithApple(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        do {
            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                errorMessage = "Apple Sign In failed"
                isLoading = false
                return
            }

            let firstName = credential.fullName?.givenName ?? ""
            let lastName = credential.fullName?.familyName ?? ""
            let fullName = [firstName, lastName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: tokenString)
            )

            currentUser = session.user
            isAuthenticated = true

            if !fullName.isEmpty {
                try await client
                    .from("profiles")
                    .update(["name": AnyJSON.string(fullName)])
                    .eq("id", value: session.user.id.supabaseString)
                    .execute()
            }

            await UserManager.shared.loadUserData(userId: session.user.id)

        } catch {
            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            currentUser = nil
            isAuthenticated = false
            UserManager.shared.clearData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
