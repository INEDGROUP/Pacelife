import SwiftUI

struct ForgotPasswordView: View {
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var isSending = false
    @State private var emailSent = false
    @State private var errorMessage: String?
    @FocusState private var emailFocused: Bool

    var emailError: String? {
        guard !email.isEmpty else { return nil }
        let regex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email) ? nil : "Invalid email address"
    }

    var body: some View {
        ZStack {
            Color.plBg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(emailSent ? "Check your email" : "Reset Password")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.plTextPrimary)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.plTextTertiary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)

                if emailSent {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(Color.plGreen.opacity(0.12))
                                .frame(width: 80, height: 80)
                            Image(systemName: "envelope.badge.checkmark.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.plGreen)
                        }

                        VStack(spacing: 8) {
                            Text("Email sent!")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.plTextPrimary)
                            Text("We've sent a password reset link to\n\(email)")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(Color.plTextTertiary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }

                        Text("Check your spam folder if you don't see it within a few minutes.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        PLPrimaryButton(title: "Back to Sign In", icon: "arrow.left") {
                            isPresented = false
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    VStack(spacing: 20) {
                        Text("Enter the email address associated with your account and we'll send you a link to reset your password.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.plTextTertiary)
                            .lineSpacing(3)

                        VStack(alignment: .leading, spacing: 6) {
                            PLTextField(
                                placeholder: "Email address",
                                text: $email,
                                icon: "envelope",
                                keyboardType: .emailAddress
                            )
                            .focused($emailFocused)

                            if let error = emailError {
                                ValidationMessage(text: error, isError: true)
                            }
                        }

                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.plRed)
                                Text(error)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Color.plRed)
                            }
                        }

                        PLPrimaryButton(
                            title: isSending ? "Sending..." : "Send Reset Link",
                            icon: isSending ? "hourglass" : "paperplane.fill"
                        ) {
                            Task { await sendReset() }
                        }
                        .disabled(isSending || email.isEmpty || emailError != nil)
                        .opacity(email.isEmpty || emailError != nil ? 0.6 : 1)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                emailFocused = true
            }
        }
    }

    private func sendReset() async {
        isSending = true
        errorMessage = nil
        do {
            try await SupabaseManager.shared.client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "com.inedgroup.pacelife://reset-password")
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                emailSent = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Could not send reset email. Please check the address and try again."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        isSending = false
    }
}
