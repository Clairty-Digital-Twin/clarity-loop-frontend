import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
final class EmailVerificationViewModel {
    // MARK: - Properties

    let email: String
    private let password: String // Store password for auto-login after verification
    var otpDigits: [String] = Array(repeating: "", count: 6)

    var isLoading = false
    var errorMessage: String?
    var hasError = false
    var isVerified = false
    var resendCooldown = 0

    private let authService: AuthServiceProtocol
    private var resendTimer: Timer?

    // MARK: - Computed Properties

    var otpCode: String {
        otpDigits.joined()
    }

    var isVerifyButtonEnabled: Bool {
        otpDigits.allSatisfy { !$0.isEmpty }
    }

    // MARK: - Initialization

    init(email: String, password: String, authService: AuthServiceProtocol) {
        self.email = email
        self.password = password
        self.authService = authService
    }

    deinit {
        resendTimer?.invalidate()
    }

    // MARK: - Public Methods

    func verifyCode() async {
        guard isVerifyButtonEnabled else { return }

        isLoading = true
        errorMessage = nil
        hasError = false

        do {
            // Call verify email endpoint
            _ = try await authService.verifyEmail(code: otpCode)

            // If verification successful, try to login
            _ = try await authService.signIn(withEmail: email, password: password)

            // Success!
            isVerified = true

        } catch {
            hasError = true
            handleVerificationError(error)

            // Shake animation
            withAnimation(.default) {
                hasError = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.hasError = false
            }
        }

        isLoading = false
    }

    func resendCode() async {
        guard resendCooldown == 0 else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Call resend email endpoint (assuming it exists)
            try await authService.resendVerificationEmail(to: email)

            // Start cooldown
            startResendTimer()

            // Show success message
            errorMessage = "Verification code sent!"

            // Clear message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.errorMessage = nil
            }

        } catch {
            errorMessage = "Failed to resend code. Please try again."
        }

        isLoading = false
    }

    func startResendTimer() {
        resendCooldown = 60 // 60 seconds cooldown

        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if self.resendCooldown > 0 {
                    self.resendCooldown -= 1
                } else {
                    self.resendTimer?.invalidate()
                    self.resendTimer = nil
                }
            }
        }
    }

    // MARK: - Private Methods

    private func handleVerificationError(_ error: Error) {
        if let urlError = error as? URLError {
            if urlError.code == .notConnectedToInternet {
                errorMessage = "No internet connection"
            } else {
                errorMessage = "Network error. Please try again."
            }
        } else if (error as NSError).code == 400 {
            errorMessage = "Invalid or expired code"
            // Clear the OTP fields
            otpDigits = Array(repeating: "", count: 6)
        } else {
            errorMessage = "Verification failed. Please try again."
        }
    }
}
