//
//  AuthServiceTests.swift
//  MonitoringAppTests
//
//  Unit tests for AuthService validation and error handling
//  Requirements: 20.4, 21.2
//

import Testing
import Foundation
@testable import MonitoringApp

struct AuthServiceTests {
    
    // MARK: - AuthError Tests
    
    @Test func authError_invalidInvitationCode_hasCorrectDescription() {
        let error = AuthError.invalidInvitationCode
        #expect(error.errorDescription == "Invalid invitation code. Please check and try again.")
    }
    
    @Test func authError_invitationCodeExpired_hasCorrectDescription() {
        let error = AuthError.invitationCodeExpired
        #expect(error.errorDescription == "This invitation code has expired. Please request a new one from your clinician.")
    }
    
    @Test func authError_invitationCodeUsed_hasCorrectDescription() {
        let error = AuthError.invitationCodeUsed
        #expect(error.errorDescription == "This invitation code has already been used.")
    }
    
    @Test func authError_invitationCodeRevoked_hasCorrectDescription() {
        let error = AuthError.invitationCodeRevoked
        #expect(error.errorDescription == "This invitation code has been revoked. Please request a new one.")
    }
    
    @Test func authError_registrationFailed_includesReason() {
        let reason = "Email already exists"
        let error = AuthError.registrationFailed(reason)
        #expect(error.errorDescription == "Registration failed: \(reason)")
    }
    
    @Test func authError_signInFailed_includesReason() {
        let reason = "Invalid credentials"
        let error = AuthError.signInFailed(reason)
        #expect(error.errorDescription == "Sign in failed: \(reason)")
    }
    
    @Test func authError_signOutFailed_includesReason() {
        let reason = "Network timeout"
        let error = AuthError.signOutFailed(reason)
        #expect(error.errorDescription == "Sign out failed: \(reason)")
    }
    
    @Test func authError_networkError_hasCorrectDescription() {
        let error = AuthError.networkError
        #expect(error.errorDescription == "Network error. Please check your connection and try again.")
    }
    
    @Test func authError_unauthorized_hasCorrectDescription() {
        let error = AuthError.unauthorized
        #expect(error.errorDescription == "Session expired. Please sign in again.")
    }
    
    @Test func authError_userNotFound_hasCorrectDescription() {
        let error = AuthError.userNotFound
        #expect(error.errorDescription == "User not found.")
    }
    
    @Test func authError_profileCreationFailed_includesReason() {
        let reason = "Database constraint violation"
        let error = AuthError.profileCreationFailed(reason)
        #expect(error.errorDescription == "Failed to create profile: \(reason)")
    }
    
    @Test func authError_unknown_includesMessage() {
        let message = "Something unexpected happened"
        let error = AuthError.unknown(message)
        #expect(error.errorDescription == message)
    }
    
    // MARK: - Invitation Code Format Validation Tests
    
    @Test func invitationCodeValidation_emptyCode_isInvalid() {
        let code = ""
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        #expect(trimmed.count != 5)
    }
    
    @Test func invitationCodeValidation_shortCode_isInvalid() {
        let code = "ABC1"
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        #expect(trimmed.count != 5)
    }
    
    @Test func invitationCodeValidation_longCode_isInvalid() {
        let code = "ABC123"
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        #expect(trimmed.count != 5)
    }
    
    @Test func invitationCodeValidation_exactlyFiveCharacters_isValid() {
        let code = "ABC12"
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        #expect(trimmed.count == 5)
    }
    
    @Test func invitationCodeValidation_lowercaseCode_isNormalized() {
        let code = "abc12"
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        #expect(trimmed == "ABC12")
    }
    
    @Test func invitationCodeValidation_codeWithWhitespace_isTrimmed() {
        let code = "  ABC12  "
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        #expect(trimmed == "ABC12")
        #expect(trimmed.count == 5)
    }
    
    @Test func invitationCodeValidation_codeWithNewlines_isTrimmed() {
        let code = "\nABC12\n"
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        #expect(trimmed == "ABC12")
    }
    
    @Test func invitationCodeValidation_mixedCaseCode_isNormalized() {
        let code = "AbC1d"
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        #expect(trimmed == "ABC1D")
    }
    
    // MARK: - Invitation Code Status Validation Tests
    
    @Test func invitationCodeStatus_pending_allowsValidation() {
        let code = createInvitationCode(status: .pending, expiresAt: Date().addingTimeInterval(3600))
        #expect(code.status == .pending)
        #expect(code.isValid == true)
    }
    
    @Test func invitationCodeStatus_used_blocksValidation() {
        let code = createInvitationCode(status: .used, expiresAt: Date().addingTimeInterval(3600))
        #expect(code.status == .used)
        #expect(code.isValid == false)
    }
    
    @Test func invitationCodeStatus_expired_blocksValidation() {
        let code = createInvitationCode(status: .expired, expiresAt: Date().addingTimeInterval(3600))
        #expect(code.status == .expired)
        #expect(code.isValid == false)
    }
    
    @Test func invitationCodeStatus_revoked_blocksValidation() {
        let code = createInvitationCode(status: .revoked, expiresAt: Date().addingTimeInterval(3600))
        #expect(code.status == .revoked)
        #expect(code.isValid == false)
    }
    
    @Test func invitationCodeStatus_pendingButExpiredByDate_blocksValidation() {
        let code = createInvitationCode(status: .pending, expiresAt: Date().addingTimeInterval(-1))
        #expect(code.status == .pending)
        #expect(code.isValid == false)
    }
    
    // MARK: - Error Handling Scenarios
    
    @Test func errorHandling_allAuthErrorCases_haveDescriptions() {
        let errors: [AuthError] = [
            .invalidInvitationCode,
            .invitationCodeExpired,
            .invitationCodeUsed,
            .invitationCodeRevoked,
            .registrationFailed("test"),
            .signInFailed("test"),
            .signOutFailed("test"),
            .networkError,
            .unauthorized,
            .userNotFound,
            .profileCreationFailed("test"),
            .unknown("test")
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
    
    @Test func errorHandling_registrationFailedWithEmptyReason_stillHasDescription() {
        let error = AuthError.registrationFailed("")
        #expect(error.errorDescription == "Registration failed: ")
    }
    
    @Test func errorHandling_signInFailedWithSpecialCharacters_preservesReason() {
        let reason = "Error: <invalid> & 'special' \"chars\""
        let error = AuthError.signInFailed(reason)
        #expect(error.errorDescription?.contains(reason) == true)
    }
    
    // MARK: - Helper Methods
    
    private func createInvitationCode(
        status: InvitationStatus = .pending,
        expiresAt: Date = Date().addingTimeInterval(3600)
    ) -> InvitationCode {
        InvitationCode(
            id: UUID(),
            clinicianId: UUID(),
            code: "ABC12",
            status: status,
            createdAt: Date(),
            expiresAt: expiresAt
        )
    }
}
