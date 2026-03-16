import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var appeared = false
    @State private var showForgotPassword = false

    var emailError: String? {
        guard !email.isEmpty else { return nil }
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let valid = NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
        return valid ? nil : "Please enter a valid email address"
    }

    var passwordError: String? {
        guard !password.isEmpty else { return nil }
        if password.count < 6 { return "Password must be at least 6 characters" }
        return nil
    }

    var nameError: String? {
        guard isSignUp && !name.isEmpty else { return nil }
        if name.count < 2 { return "Name must be at least 2 characters" }
        return nil
    }

    var canSubmit: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        emailError == nil &&
        passwordError == nil &&
        (!isSignUp || !name.isEmpty)
    }

    var body: some View {
        ZStack {
            Color.plBg.ignoresSafeArea()
            AnimatedBackgroundView()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    VStack(spacing: 12) {
                        Image(systemName: "figure.walk.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.plGreen, Color(hex: "6B8FFF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)

                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.plTextPrimary)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)

                        Text(isSignUp ? "Start your PaceLife journey" : "Good to see you again")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: appeared)
                    }

                    VStack(spacing: 14) {
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 6) {
                                PLTextField(
                                    placeholder: "Your name",
                                    text: $name,
                                    icon: "person"
                                )
                                if let error = nameError {
                                    ValidationMessage(text: error, isError: true)
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            PLTextField(
                                placeholder: "Email address",
                                text: $email,
                                icon: "envelope",
                                keyboardType: .emailAddress
                            )
                            if let error = emailError {
                                ValidationMessage(text: error, isError: true)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            PLTextField(
                                placeholder: "Password",
                                text: $password,
                                icon: "lock",
                                isSecure: true
                            )
                            if let error = passwordError {
                                ValidationMessage(text: error, isError: true)
                            } else if isSignUp && !password.isEmpty {
                                PasswordStrengthBar(password: password)
                            }
                        }

                        if !isSignUp {
                            HStack {
                                Spacer()
                                Button(action: { showForgotPassword = true }) {
                                    Text("Forgot password?")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(Color.plGreen)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: appeared)

                    if let error = authService.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.plRed)
                            Text(error)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Color.plRed)
                        }
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                    }

                    VStack(spacing: 14) {
                        PLPrimaryButton(
                            title: authService.isLoading ? "Please wait..." : (isSignUp ? "Create Account" : "Sign In"),
                            icon: authService.isLoading ? "hourglass" : "arrow.right"
                        ) {
                            Task {
                                if isSignUp {
                                    await authService.signUp(email: email, password: password, name: name)
                                } else {
                                    await authService.signIn(email: email, password: password)
                                }
                            }
                        }
                        .disabled(authService.isLoading || !canSubmit)
                        .opacity(canSubmit ? 1 : 0.6)

                        HStack(spacing: 16) {
                            Rectangle().fill(Color.plBorder).frame(height: 0.5)
                            Text("or")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Color.plTextTertiary)
                            Rectangle().fill(Color.plBorder).frame(height: 0.5)
                        }

                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                Task { await authService.signInWithApple(result: result) }
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: PLRadius.lg))

                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isSignUp.toggle()
                                authService.errorMessage = nil
                                password = ""
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .foregroundStyle(Color.plTextTertiary)
                                Text(isSignUp ? "Sign In" : "Sign Up")
                                    .foregroundStyle(Color.plGreen)
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 14, design: .rounded))
                        }
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.45), value: appeared)

                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear { appeared = true }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(isPresented: $showForgotPassword)
        }
    }
}

struct ValidationMessage: View {
    let text: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(isError ? Color.plRed : Color.plGreen)
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(isError ? Color.plRed : Color.plGreen)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct PasswordStrengthBar: View {
    let password: String

    var strength: Int {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: .punctuationCharacters) != nil { score += 1 }
        return min(score, 4)
    }

    var strengthLabel: String {
        switch strength {
        case 0, 1: return "Weak"
        case 2: return "Fair"
        case 3: return "Good"
        default: return "Strong"
        }
    }

    var strengthColor: Color {
        switch strength {
        case 0, 1: return .plRed
        case 2: return .plAmber
        case 3: return Color(hex: "6B8FFF")
        default: return .plGreen
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < strength ? strengthColor : Color.plBgTertiary)
                        .frame(height: 3)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: strength)
                }
            }
            Text(strengthLabel)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(strengthColor)
        }
    }
}
