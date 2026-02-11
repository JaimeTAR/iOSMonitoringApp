//
//  ActiveRelationshipsTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 5: Patient list includes only active relationships
//  Validates: Requirements 6.1
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Generators

private func makeRelationship(
    patientId: UUID,
    status: RelationshipStatus,
    endDate: Date? = nil
) -> ClinicianPatient {
    ClinicianPatient(
        id: UUID(),
        clinicianId: UUID(),
        patientId: patientId,
        invitationCodeId: nil,
        startDate: Date(),
        endDate: endDate,
        status: status,
        createdAt: Date()
    )
}

private func genRelationships(count: UInt) -> Gen<[ClinicianPatient]> {
    Gen<[ClinicianPatient]>.compose { composer in
        (0..<count).map { _ in
            let status: RelationshipStatus = composer.generate()
            let hasEndDate: Bool = composer.generate()
            return makeRelationship(
                patientId: UUID(),
                status: status,
                endDate: hasEndDate ? Date() : nil
            )
        }
    }
}

// MARK: - Property Tests

struct ActiveRelationshipsTests {

    // Feature: cardiologist-views, Property 5: Patient list includes only active relationships

    @Test func onlyActiveRelationships_included() {
        property("only relationships with activo status and nil endDate produce patient IDs") <- forAll(
            Gen<UInt>.fromElements(in: 0...15)
        ) { count in
            return forAll(genRelationships(count: count)) { relationships in
                let result = ClinicianService.activePatientIds(from: relationships)
                let expected = relationships
                    .filter { $0.status == .activo && $0.endDate == nil }
                    .map { $0.patientId }
                return Set(result) == Set(expected)
            }
        }
    }

    @Test func inactiveRelationships_excluded() {
        property("inactive relationships never appear in result") <- forAll(
            Gen<UInt>.fromElements(in: 1...15)
        ) { count in
            return forAll(genRelationships(count: count)) { relationships in
                let result = Set(ClinicianService.activePatientIds(from: relationships))
                let inactiveIds = Set(
                    relationships
                        .filter { $0.status == .inactivo || $0.endDate != nil }
                        .map { $0.patientId }
                )
                // No inactive patient should appear unless they also have an active relationship
                let activeIds = Set(
                    relationships
                        .filter { $0.status == .activo && $0.endDate == nil }
                        .map { $0.patientId }
                )
                let purelyInactive = inactiveIds.subtracting(activeIds)
                return result.intersection(purelyInactive).isEmpty
            }
        }
    }

    @Test func resultCount_matchesActiveCount() {
        property("result count matches number of active relationships") <- forAll(
            Gen<UInt>.fromElements(in: 0...15)
        ) { count in
            return forAll(genRelationships(count: count)) { relationships in
                let result = ClinicianService.activePatientIds(from: relationships)
                let expectedCount = relationships
                    .filter { $0.status == .activo && $0.endDate == nil }
                    .count
                return result.count == expectedCount
            }
        }
    }

    // MARK: - Edge Cases

    @Test func emptyRelationships_returnsEmpty() {
        let result = ClinicianService.activePatientIds(from: [])
        #expect(result.isEmpty)
    }

    @Test func allInactive_returnsEmpty() {
        let relationships = [
            makeRelationship(patientId: UUID(), status: .inactivo),
            makeRelationship(patientId: UUID(), status: .activo, endDate: Date()),
        ]
        let result = ClinicianService.activePatientIds(from: relationships)
        #expect(result.isEmpty)
    }
}
