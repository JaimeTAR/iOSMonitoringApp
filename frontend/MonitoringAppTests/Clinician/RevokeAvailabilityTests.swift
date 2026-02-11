//
//  RevokeAvailabilityTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 15: Revoke action availability and effect
//  Validates: Requirements 11.8, 11.9
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Test Helpers

private let invitationStatusGen = Gen<InvitationStatus>.fromElements(of: InvitationStatus.allCases)

private func makeCode(status: InvitationStatus) -> InvitationCode {
    InvitationCode(
        id: UUID(),
        clinicianId: UUID(),
        code: "ABCDE",
        status: status,
        createdAt: Date(),
        expiresAt: Date().addingTimeInterval(604800)
    )
}

// MARK: - Property Tests

struct RevokeAvailabilityTests {

    // Feature: cardiologist-views, Property 15: Revoke action availability and effect

    @Test func revokeAvailableOnlyForPending() {
        property("revoke is available if and only if status is pending") <- forAll(
            invitationStatusGen
        ) { status in
            let code = makeCode(status: status)
            let canRevoke = InvitationManagerViewModel.canRevoke(code)
            return canRevoke == (status == .pending)
        }
    }

    @Test func pendingCodesCanAlwaysBeRevoked() {
        let code = makeCode(status: .pending)
        #expect(InvitationManagerViewModel.canRevoke(code) == true)
    }

    @Test func usedCodesCannotBeRevoked() {
        let code = makeCode(status: .used)
        #expect(InvitationManagerViewModel.canRevoke(code) == false)
    }

    @Test func expiredCodesCannotBeRevoked() {
        let code = makeCode(status: .expired)
        #expect(InvitationManagerViewModel.canRevoke(code) == false)
    }

    @Test func revokedCodesCannotBeRevoked() {
        let code = makeCode(status: .revoked)
        #expect(InvitationManagerViewModel.canRevoke(code) == false)
    }
}
