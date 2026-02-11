//
//  InvitationCodeTests.swift
//  MonitoringAppTests
//
//  Unit tests for InvitationCode model validation and expiration logic
//

import Testing
import Foundation
@testable import MonitoringApp

struct InvitationCodeTests {
    
    // MARK: - Test Fixtures
    
    private func createInvitationCode(
        status: InvitationStatus = .pending,
        expiresAt: Date = Date().addingTimeInterval(3600) // 1 hour from now
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
    
    // MARK: - isValid Tests with Status
    
    @Test func isValid_withPendingStatusAndFutureExpiration_returnsTrue() {
        let code = createInvitationCode(status: .pending, expiresAt: Date().addingTimeInterval(3600))
        #expect(code.isValid == true)
    }
    
    @Test func isValid_withUsedStatus_returnsFalse() {
        let code = createInvitationCode(status: .used, expiresAt: Date().addingTimeInterval(3600))
        #expect(code.isValid == false)
    }
    
    @Test func isValid_withExpiredStatus_returnsFalse() {
        let code = createInvitationCode(status: .expired, expiresAt: Date().addingTimeInterval(3600))
        #expect(code.isValid == false)
    }
    
    @Test func isValid_withRevokedStatus_returnsFalse() {
        let code = createInvitationCode(status: .revoked, expiresAt: Date().addingTimeInterval(3600))
        #expect(code.isValid == false)
    }
    
    // MARK: - isValid Tests with Expiration
    
    @Test func isValid_withPastExpiration_returnsFalse() {
        let code = createInvitationCode(status: .pending, expiresAt: Date().addingTimeInterval(-1))
        #expect(code.isValid == false)
    }
    
    @Test func isValid_withExpirationInDistantFuture_returnsTrue() {
        let code = createInvitationCode(status: .pending, expiresAt: Date().addingTimeInterval(86400 * 365)) // 1 year
        #expect(code.isValid == true)
    }
    
    @Test func isValid_withExpirationInDistantPast_returnsFalse() {
        let code = createInvitationCode(status: .pending, expiresAt: Date().addingTimeInterval(-86400)) // 1 day ago
        #expect(code.isValid == false)
    }
    
    // MARK: - Combined Status and Expiration Tests
    
    @Test func isValid_withUsedStatusAndPastExpiration_returnsFalse() {
        let code = createInvitationCode(status: .used, expiresAt: Date().addingTimeInterval(-3600))
        #expect(code.isValid == false)
    }
    
    @Test func isValid_withExpiredStatusAndFutureExpiration_returnsFalse() {
        // Status takes precedence - even if expiration is in future, expired status means invalid
        let code = createInvitationCode(status: .expired, expiresAt: Date().addingTimeInterval(3600))
        #expect(code.isValid == false)
    }
    
    @Test func isValid_withRevokedStatusAndFutureExpiration_returnsFalse() {
        let code = createInvitationCode(status: .revoked, expiresAt: Date().addingTimeInterval(3600))
        #expect(code.isValid == false)
    }
    
    // MARK: - Edge Cases
    
    @Test func isValid_withExpirationExactlyNow_returnsFalse() {
        // expiresAt > Date() means expiration at exactly now should be invalid
        let code = createInvitationCode(status: .pending, expiresAt: Date())
        #expect(code.isValid == false)
    }
    
    @Test func isValid_withExpirationOneSecondFromNow_returnsTrue() {
        let code = createInvitationCode(status: .pending, expiresAt: Date().addingTimeInterval(1))
        #expect(code.isValid == true)
    }
    
    @Test func isValid_withExpirationOneSecondAgo_returnsFalse() {
        let code = createInvitationCode(status: .pending, expiresAt: Date().addingTimeInterval(-1))
        #expect(code.isValid == false)
    }
}
