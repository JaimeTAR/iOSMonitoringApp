//
//  RoleRoutingTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 1: Role-based routing correctness
//  Validates: Requirements 1.1, 1.2
//

import Testing
import SwiftCheck
@testable import MonitoringApp

// MARK: - Arbitrary Conformances

extension UserRole: @retroactive Arbitrary {
    public static var arbitrary: Gen<UserRole> {
        Gen<UserRole>.fromElements(of: UserRole.allCases)
    }
}

// MARK: - Property Tests

struct RoleRoutingTests {

    // Feature: cardiologist-views, Property 1: Role-based routing correctness

    @Test func resolveRoute_returnsCorrectRoleForEveryUserRole() {
        property("resolveRoute maps each UserRole to itself") <- forAll { (role: UserRole) in
            return RootView.resolveRoute(for: role) == role
        }
    }

    @Test func resolveRoute_clinicianRole_returnsClinician() {
        #expect(RootView.resolveRoute(for: .clinician) == .clinician)
    }

    @Test func resolveRoute_patientRole_returnsPatient() {
        #expect(RootView.resolveRoute(for: .patient) == .patient)
    }

    @Test func resolveRoute_nilRole_defaultsToPatient() {
        #expect(RootView.resolveRoute(for: nil) == .patient)
    }

    @Test func resolveRoute_isExhaustiveOverAllCases() {
        // Verify every UserRole case produces a defined route
        for role in UserRole.allCases {
            let result = RootView.resolveRoute(for: role)
            #expect(UserRole.allCases.contains(result))
        }
    }
}
