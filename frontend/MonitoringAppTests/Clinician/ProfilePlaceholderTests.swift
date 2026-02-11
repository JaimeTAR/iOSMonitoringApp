//
//  ProfilePlaceholderTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 9: Profile card placeholder for missing fields
//  Validates: Requirements 7.5
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Test Helpers

private func makeProfile(
    name: String? = "Test",
    age: Int? = 30,
    sex: Sex? = .male,
    activityLevel: ActivityLevel? = .moderado,
    restingHeartRate: Double? = 70.0
) -> UserProfile {
    UserProfile(
        id: UUID(),
        userId: UUID(),
        role: .patient,
        name: name,
        age: age,
        sex: sex,
        heightCm: nil,
        weightKg: nil,
        exerciseFrequency: nil,
        activityLevel: activityLevel,
        restingHeartRate: restingHeartRate,
        createdAt: Date(),
        updatedAt: Date()
    )
}

// MARK: - Property Tests

struct ProfilePlaceholderTests {

    // Feature: cardiologist-views, Property 9: Profile card placeholder for missing fields

    @Test func nilAgeShowsPlaceholder() {
        let result = PatientDetailViewModel.displayValue(nil as Int?)
        #expect(!result.isEmpty)
        #expect(result == "N/A")
    }

    @Test func nilDoubleShowsPlaceholder() {
        let result = PatientDetailViewModel.displayValue(nil as Double?)
        #expect(!result.isEmpty)
        #expect(result == "N/A")
    }

    @Test func nilStringShowsPlaceholder() {
        let result = PatientDetailViewModel.displayValue(nil as String?)
        #expect(!result.isEmpty)
        #expect(result == "N/A")
    }

    @Test func emptyStringShowsPlaceholder() {
        let result = PatientDetailViewModel.displayValue("")
        #expect(!result.isEmpty)
        #expect(result == "N/A")
    }

    @Test func presentValuesShowActualValue() {
        property("non-nil Int values display as their string representation") <- forAll(
            Gen<UInt>.fromElements(in: 1...149)
        ) { age in
            let result = PatientDetailViewModel.displayValue(Int(age))
            return result == "\(age)" && !result.isEmpty
        }
    }

    @Test func presentDoubleValuesShowActualValue() {
        property("non-nil Double values display as formatted string") <- forAll(
            Gen<Double>.fromElements(in: 40...120)
        ) { hr in
            let result = PatientDetailViewModel.displayValue(hr)
            return !result.isEmpty && result != "N/A"
        }
    }

    @Test func randomNilCombinationsAlwaysProduceNonEmptyStrings() {
        property("any combination of nil fields produces non-empty placeholder strings") <- forAll(
            Bool.arbitrary,
            Bool.arbitrary,
            Bool.arbitrary,
            Bool.arbitrary
        ) { hasAge, hasSex, hasActivity, hasHR in
            let profile = makeProfile(
                age: hasAge ? 30 : nil,
                sex: hasSex ? .male : nil,
                activityLevel: hasActivity ? .moderado : nil,
                restingHeartRate: hasHR ? 70.0 : nil
            )

            let ageStr = PatientDetailViewModel.displayValue(profile.age)
            let sexStr = PatientDetailViewModel.displayValue(profile.sex?.rawValue)
            let activityStr = PatientDetailViewModel.displayValue(profile.activityLevel?.rawValue)
            let hrStr = PatientDetailViewModel.displayValue(profile.restingHeartRate)

            return !ageStr.isEmpty && !sexStr.isEmpty && !activityStr.isEmpty && !hrStr.isEmpty
        }
    }
}
