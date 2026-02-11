//
//  ClinicianProfileStatsTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 18: Clinician profile stats
//  Validates: Requirements 12.2
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Test Helpers

private func makeRelationship(
    clinicianId: UUID,
    status: RelationshipStatus,
    endDate: Date? = nil
) -> ClinicianPatient {
    ClinicianPatient(
        id: UUID(),
        clinicianId: clinicianId,
        patientId: UUID(),
        invitationCodeId: nil,
        startDate: Date(),
        endDate: endDate,
        status: status,
        createdAt: Date()
    )
}

private func makeProfile(createdAt: Date = Date()) -> UserProfile {
    UserProfile(
        id: UUID(),
        userId: UUID(),
        role: .clinician,
        name: "Dr. Test",
        age: 45,
        sex: nil,
        heightCm: nil,
        weightKg: nil,
        exerciseFrequency: nil,
        activityLevel: nil,
        restingHeartRate: nil,
        createdAt: createdAt,
        updatedAt: Date()
    )
}

// MARK: - Property Tests

struct ClinicianProfileStatsTests {

    // Feature: cardiologist-views, Property 18: Clinician profile stats

    @Test func activePatientCountMatchesActiveRelationships() {
        property("active patient count equals relationships with activo status and nil endDate") <- forAll(
            Gen<UInt>.fromElements(in: 0...20)
        ) { count in
            let clinicianId = UUID()
            let relationships: [ClinicianPatient] = (0..<Int(count)).map { _ in
                let status: RelationshipStatus = Bool.random() ? .activo : .inactivo
                let endDate: Date? = Bool.random() ? Date() : nil
                return makeRelationship(clinicianId: clinicianId, status: status, endDate: endDate)
            }

            let activeIds = ClinicianService.activePatientIds(from: relationships)
            let expectedCount = relationships.filter { $0.status == .activo && $0.endDate == nil }.count

            return activeIds.count == expectedCount
        }
    }

    @Test func accountCreatedDateMatchesProfile() {
        let createdAt = Date().addingTimeInterval(-86400 * 30)
        let profile = makeProfile(createdAt: createdAt)
        #expect(profile.createdAt == createdAt)
    }

    @Test func noRelationshipsYieldsZeroActive() {
        let activeIds = ClinicianService.activePatientIds(from: [])
        #expect(activeIds.isEmpty)
    }

    @Test func allInactiveYieldsZeroActive() {
        let clinicianId = UUID()
        let relationships = (0..<5).map { _ in
            makeRelationship(clinicianId: clinicianId, status: .inactivo)
        }
        let activeIds = ClinicianService.activePatientIds(from: relationships)
        #expect(activeIds.isEmpty)
    }

    @Test func activoWithEndDateNotCounted() {
        let clinicianId = UUID()
        let relationships = (0..<5).map { _ in
            makeRelationship(clinicianId: clinicianId, status: .activo, endDate: Date())
        }
        let activeIds = ClinicianService.activePatientIds(from: relationships)
        #expect(activeIds.isEmpty)
    }
}
