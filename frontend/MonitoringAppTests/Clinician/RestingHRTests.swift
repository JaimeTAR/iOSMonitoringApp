//
//  RestingHRTests.swift
//  MonitoringAppTests
//
//  Feature: clinician-set-resting-hr, Property 1: BPM validation correctness
//  Feature: clinician-set-resting-hr, Property 2: Save updates local profile state
//  Validates: Requirements 5.2, 5.3, 5.4, 3.1, 3.3, 3.4, 4.1, 4.2
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Test Helpers

private func makeProfile(
    restingHeartRate: Double? = nil
) -> UserProfile {
    UserProfile(
        id: UUID(),
        userId: UUID(),
        role: .patient,
        name: "Test",
        age: 30,
        sex: .male,
        heightCm: nil,
        weightKg: nil,
        exerciseFrequency: nil,
        activityLevel: nil,
        restingHeartRate: restingHeartRate,
        createdAt: Date(),
        updatedAt: Date()
    )
}

private func makePatientDetail(
    restingHeartRate: Double? = nil
) -> PatientDetail {
    PatientDetail(
        profile: makeProfile(restingHeartRate: restingHeartRate),
        overview: nil
    )
}

// MARK: - Mock Service

private final class MockClinicianService: ClinicianServiceProtocol {
    var shouldThrow = false

    func updatePatientRestingHeartRate(patientId: UUID, bpm: Double) async throws {
        if shouldThrow {
            throw ClinicianError.updateRestingHRFailed("mock error")
        }
    }

    func fetchPatients(for clinicianId: UUID) async throws -> [PatientSummary] { [] }
    func fetchPatientDetail(patientId: UUID) async throws -> PatientDetail {
        makePatientDetail()
    }
    func fetchPatientSamples(patientId: UUID, from: Date, to: Date) async throws -> [PhysiologicalSample] { [] }
    func fetchDashboardStats(for clinicianId: UUID) async throws -> DashboardStats {
        DashboardStats(totalActivePatients: 0, patientsActiveToday: 0, pendingInvitations: 0)
    }
    func fetchNeedsAttention(for clinicianId: UUID) async throws -> [NeedsAttentionItem] { [] }
    func fetchRecentActivity(for clinicianId: UUID, limit: Int) async throws -> [RecentActivityItem] { [] }
    func fetchInvitationCodes(for clinicianId: UUID) async throws -> [InvitationCode] { [] }
    func generateInvitationCode(for clinicianId: UUID) async throws -> InvitationCode {
        InvitationCode(id: UUID(), clinicianId: clinicianId, code: "AAAAA", status: .pending, createdAt: Date(), expiresAt: Date())
    }
    func revokeInvitationCode(id: UUID) async throws {}
    func fetchClinicianProfile(userId: UUID) async throws -> UserProfile {
        makeProfile()
    }
}

// MARK: - Generators

/// Generates a random Double in [30.0, 220.0]
private let genValidBPM = Gen<Double>.fromElements(in: 30.0...220.0)

/// Generates a random Double outside [30.0, 220.0]
private let genInvalidBPMLow = Gen<Double>.fromElements(in: -1000.0...29.9)
private let genInvalidBPMHigh = Gen<Double>.fromElements(in: 220.1...1000.0)

/// Generates a random non-numeric string
private let genNonNumericString = Gen<String>.compose { composer in
    let length: UInt = composer.generate(using: Gen<UInt>.fromElements(in: 1...20))
    let chars = (0..<length).map { _ -> Character in
        let c: UInt8 = composer.generate(using: Gen<UInt8>.fromElements(in: 65...122))
        return Character(UnicodeScalar(c))
    }
    return String(chars)
}

// MARK: - Property Tests

struct RestingHRTests {

    // Feature: clinician-set-resting-hr, Property 1: BPM validation correctness

    @Test func validBPMValues_returnTrue() {
        property("isValidBPM returns true for doubles in [30, 220]") <- forAll(genValidBPM) { d in
            return PatientDetailViewModel.isValidBPM(String(d))
        }
    }

    @Test func invalidBPMLow_returnFalse() {
        property("isValidBPM returns false for doubles below 30") <- forAll(genInvalidBPMLow) { d in
            return !PatientDetailViewModel.isValidBPM(String(d))
        }
    }

    @Test func invalidBPMHigh_returnFalse() {
        property("isValidBPM returns false for doubles above 220") <- forAll(genInvalidBPMHigh) { d in
            return !PatientDetailViewModel.isValidBPM(String(d))
        }
    }

    @Test func nonNumericStrings_returnFalse() {
        property("isValidBPM returns false for non-numeric strings") <- forAll(genNonNumericString) { s in
            // Filter out strings that happen to parse as valid doubles in range
            if let val = Double(s), val >= 30.0, val <= 220.0 { return true }
            return !PatientDetailViewModel.isValidBPM(s)
        }
    }

    @Test func emptyString_returnsFalse() {
        #expect(!PatientDetailViewModel.isValidBPM(""))
    }

    // MARK: - Boundary Edge Cases

    @Test func boundaryValues() {
        #expect(PatientDetailViewModel.isValidBPM("30"))
        #expect(PatientDetailViewModel.isValidBPM("220"))
        #expect(!PatientDetailViewModel.isValidBPM("29.9"))
        #expect(!PatientDetailViewModel.isValidBPM("220.1"))
        #expect(!PatientDetailViewModel.isValidBPM("abc"))
        #expect(!PatientDetailViewModel.isValidBPM("  "))
    }

    // Feature: clinician-set-resting-hr, Property 2: Save updates local profile state

    @Test @MainActor func saveRestingHR_updatesLocalState() async {
        // Generate 100 random valid BPM values and verify each one
        let bpmValues = genValidBPM.proliferate(withSize: 100).generate
        for bpm in bpmValues {
            let mockService = MockClinicianService()
            let vm = PatientDetailViewModel(service: mockService, patientId: UUID())
            vm.patientDetail = makePatientDetail()

            await vm.saveRestingHeartRate(String(bpm))

            #expect(vm.patientDetail?.profile.restingHeartRate == bpm)
            #expect(vm.isSavingRestingHR == false)
            #expect(vm.error == nil)
        }
    }

    @Test @MainActor func saveRestingHR_errorSetsErrorState() async {
        let mockService = MockClinicianService()
        mockService.shouldThrow = true
        let vm = PatientDetailViewModel(service: mockService, patientId: UUID())
        vm.patientDetail = makePatientDetail()

        await vm.saveRestingHeartRate("72")

        #expect(vm.error != nil)
        #expect(vm.isSavingRestingHR == false)
    }
}
