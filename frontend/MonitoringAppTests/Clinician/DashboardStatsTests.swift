//
//  DashboardStatsTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 2: Dashboard stats computation
//  Validates: Requirements 3.1
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Test Helpers

/// Creates a ClinicianPatient with the given parameters
private func makeRelationship(
    clinicianId: UUID = UUID(),
    patientId: UUID,
    status: RelationshipStatus,
    endDate: Date? = nil
) -> ClinicianPatient {
    ClinicianPatient(
        id: UUID(),
        clinicianId: clinicianId,
        patientId: patientId,
        invitationCodeId: nil,
        startDate: Date(),
        endDate: endDate,
        status: status,
        createdAt: Date()
    )
}

/// Creates a PhysiologicalSample for a given patient at a given time
private func makeSample(userId: UUID, windowStart: Date) -> PhysiologicalSample {
    PhysiologicalSample(
        userId: userId,
        windowStart: windowStart,
        avgHeartRate: 72.0,
        rmssd: 40.0,
        sdnn: 50.0,
        sampleCount: 60
    )
}

/// Creates an InvitationCode with the given status
private func makeInvitation(status: InvitationStatus) -> InvitationCode {
    InvitationCode(
        id: UUID(),
        clinicianId: UUID(),
        code: "ABCDE",
        status: status,
        createdAt: Date(),
        expiresAt: Date().addingTimeInterval(7 * 24 * 3600)
    )
}

// MARK: - Arbitrary Conformances

extension RelationshipStatus: @retroactive Arbitrary {
    public static var arbitrary: Gen<RelationshipStatus> {
        Gen<RelationshipStatus>.fromElements(of: [.activo, .inactivo])
    }
}

extension ClinicianPatient: @retroactive Arbitrary {
    public static var arbitrary: Gen<ClinicianPatient> {
        Gen<ClinicianPatient>.compose { composer in
            let status: RelationshipStatus = composer.generate()
            let hasEndDate: Bool = composer.generate()
            return ClinicianPatient(
                id: UUID(),
                clinicianId: UUID(),
                patientId: UUID(),
                invitationCodeId: nil,
                startDate: Date(),
                endDate: hasEndDate ? Date() : nil,
                status: status,
                createdAt: Date()
            )
        }
    }
}

extension PhysiologicalSample: @retroactive Arbitrary {
    public static var arbitrary: Gen<PhysiologicalSample> {
        Gen<PhysiologicalSample>.compose { _ in
            PhysiologicalSample(
                userId: UUID(),
                windowStart: Date(),
                avgHeartRate: 72.0,
                rmssd: 40.0,
                sdnn: 50.0,
                sampleCount: 60
            )
        }
    }
}

extension InvitationCode: @retroactive Arbitrary {
    public static var arbitrary: Gen<InvitationCode> {
        Gen<InvitationCode>.compose { composer in
            let status: InvitationStatus = composer.generate()
            return InvitationCode(
                id: UUID(),
                clinicianId: UUID(),
                code: "ABCDE",
                status: status,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(7 * 24 * 3600)
            )
        }
    }
}

// MARK: - Generators

/// Generates a random list of ClinicianPatient relationships with mixed statuses and endDates
private func genRelationships(patientIds: [UUID]) -> Gen<[ClinicianPatient]> {
    let clinicianId = UUID()
    return Gen<[ClinicianPatient]>.compose { composer in
        patientIds.map { patientId in
            let status: RelationshipStatus = composer.generate()
            let hasEndDate: Bool = composer.generate()
            let endDate: Date? = hasEndDate ? Date() : nil
            return makeRelationship(
                clinicianId: clinicianId,
                patientId: patientId,
                status: status,
                endDate: endDate
            )
        }
    }
}

/// Generates random samples for a subset of patient IDs, some within 24h and some older
private func genSamples(patientIds: [UUID], now: Date) -> Gen<[PhysiologicalSample]> {
    Gen<[PhysiologicalSample]>.compose { composer in
        patientIds.flatMap { patientId -> [PhysiologicalSample] in
            let count: UInt = composer.generate(using: Gen<UInt>.fromElements(in: 0...3))
            return (0..<count).map { _ in
                let hoursAgo: UInt = composer.generate(using: Gen<UInt>.fromElements(in: 0...47))
                let sampleDate = Calendar.current.date(byAdding: .hour, value: -Int(hoursAgo), to: now)!
                return makeSample(userId: patientId, windowStart: sampleDate)
            }
        }
    }
}

/// Generates random invitation codes with mixed statuses
private func genInvitations(count: UInt) -> Gen<[InvitationCode]> {
    Gen<[InvitationCode]>.compose { composer in
        (0..<count).map { _ in
            let status: InvitationStatus = composer.generate()
            return makeInvitation(status: status)
        }
    }
}

// MARK: - Property Tests

struct DashboardStatsTests {

    // Feature: cardiologist-views, Property 2: Dashboard stats computation

    @Test func totalActivePatients_matchesActiveRelationshipCount() {
        property("totalActivePatients equals count of activo relationships with nil endDate") <- forAll(
            Gen<UInt>.fromElements(in: 0...10)
        ) { patientCount in
            let patientIds = (0..<patientCount).map { _ in UUID() }
            let now = Date()

            return forAll(genRelationships(patientIds: patientIds)) { relationships in
                let stats = ClinicianService.computeDashboardStats(
                    relationships: relationships,
                    samples: [],
                    invitationCodes: [],
                    now: now
                )

                let expectedActive = Set(
                    relationships
                        .filter { $0.status == .activo && $0.endDate == nil }
                        .map { $0.patientId }
                ).count

                return stats.totalActivePatients == expectedActive
            }
        }
    }

    @Test func patientsActiveToday_matchesDistinctPatientsWithRecentSamples() {
        property("patientsActiveToday equals distinct active patients with samples in last 24h") <- forAll(
            Gen<UInt>.fromElements(in: 1...8)
        ) { patientCount in
            let patientIds = (0..<patientCount).map { _ in UUID() }
            let now = Date()

            return forAll(
                genRelationships(patientIds: patientIds),
                genSamples(patientIds: patientIds, now: now)
            ) { relationships, samples in
                let stats = ClinicianService.computeDashboardStats(
                    relationships: relationships,
                    samples: samples,
                    invitationCodes: [],
                    now: now
                )

                let activePatientIds = Set(
                    relationships
                        .filter { $0.status == .activo && $0.endDate == nil }
                        .map { $0.patientId }
                )
                let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
                let expectedActiveToday = Set(
                    samples
                        .filter { activePatientIds.contains($0.userId) && $0.windowStart >= twentyFourHoursAgo }
                        .map { $0.userId }
                ).count

                return stats.patientsActiveToday == expectedActiveToday
            }
        }
    }

    @Test func pendingInvitations_matchesPendingCodeCount() {
        property("pendingInvitations equals count of codes with pending status") <- forAll(
            Gen<UInt>.fromElements(in: 0...15)
        ) { invCount in
            return forAll(genInvitations(count: invCount)) { codes in
                let stats = ClinicianService.computeDashboardStats(
                    relationships: [],
                    samples: [],
                    invitationCodes: codes
                )

                let expectedPending = codes.filter { $0.status == .pending }.count
                return stats.pendingInvitations == expectedPending
            }
        }
    }

    @Test func allStatsCorrect_withMixedData() {
        property("all three stats are correct simultaneously for random data") <- forAll(
            Gen<UInt>.fromElements(in: 0...8),
            Gen<UInt>.fromElements(in: 0...10)
        ) { patientCount, invCount in
            let patientIds = (0..<patientCount).map { _ in UUID() }
            let now = Date()

            return forAll(
                genRelationships(patientIds: patientIds),
                genSamples(patientIds: patientIds, now: now),
                genInvitations(count: invCount)
            ) { relationships, samples, codes in
                let stats = ClinicianService.computeDashboardStats(
                    relationships: relationships,
                    samples: samples,
                    invitationCodes: codes,
                    now: now
                )

                let activePatientIds = Set(
                    relationships
                        .filter { $0.status == .activo && $0.endDate == nil }
                        .map { $0.patientId }
                )
                let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: now)!

                let expectedTotal = activePatientIds.count
                let expectedActiveToday = Set(
                    samples
                        .filter { activePatientIds.contains($0.userId) && $0.windowStart >= twentyFourHoursAgo }
                        .map { $0.userId }
                ).count
                let expectedPending = codes.filter { $0.status == .pending }.count

                return stats.totalActivePatients == expectedTotal
                    && stats.patientsActiveToday == expectedActiveToday
                    && stats.pendingInvitations == expectedPending
            }
        }
    }

    // MARK: - Edge Cases

    @Test func emptyInputs_producesZeroStats() {
        let stats = ClinicianService.computeDashboardStats(
            relationships: [],
            samples: [],
            invitationCodes: []
        )
        #expect(stats.totalActivePatients == 0)
        #expect(stats.patientsActiveToday == 0)
        #expect(stats.pendingInvitations == 0)
    }

    @Test func inactiveRelationships_notCounted() {
        let patientId = UUID()
        let relationships = [
            makeRelationship(patientId: patientId, status: .inactivo),
            makeRelationship(patientId: UUID(), status: .activo, endDate: Date()),
        ]
        let stats = ClinicianService.computeDashboardStats(
            relationships: relationships,
            samples: [makeSample(userId: patientId, windowStart: Date())],
            invitationCodes: []
        )
        #expect(stats.totalActivePatients == 0)
        #expect(stats.patientsActiveToday == 0)
    }

    @Test func samplesFromNonActivePatients_notCountedAsActiveToday() {
        let activePatientId = UUID()
        let inactivePatientId = UUID()
        let now = Date()

        let relationships = [
            makeRelationship(patientId: activePatientId, status: .activo),
            makeRelationship(patientId: inactivePatientId, status: .inactivo),
        ]
        let samples = [
            makeSample(userId: inactivePatientId, windowStart: now),
        ]

        let stats = ClinicianService.computeDashboardStats(
            relationships: relationships,
            samples: samples,
            invitationCodes: [],
            now: now
        )
        #expect(stats.totalActivePatients == 1)
        #expect(stats.patientsActiveToday == 0)
    }

    @Test func nonPendingInvitations_notCounted() {
        let codes = [
            makeInvitation(status: .used),
            makeInvitation(status: .expired),
            makeInvitation(status: .revoked),
        ]
        let stats = ClinicianService.computeDashboardStats(
            relationships: [],
            samples: [],
            invitationCodes: codes
        )
        #expect(stats.pendingInvitations == 0)
    }
}
