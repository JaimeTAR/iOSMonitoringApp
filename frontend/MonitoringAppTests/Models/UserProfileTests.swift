//
//  UserProfileTests.swift
//  MonitoringAppTests
//
//  Unit tests for UserProfile model validation
//

import Testing
import Foundation
@testable import MonitoringApp

struct UserProfileTests {
    
    // MARK: - Test Fixtures
    
    private func createProfile(
        age: Int? = 35,
        sex: Sex? = .male,
        heightCm: Double? = 175,
        weightKg: Double? = 70,
        exerciseFrequency: Int? = 3,
        activityLevel: ActivityLevel? = .moderado,
        restingHeartRate: Double? = 62
    ) -> UserProfile {
        UserProfile(
            id: UUID(),
            userId: UUID(),
            role: .patient,
            age: age,
            sex: sex,
            heightCm: heightCm,
            weightKg: weightKg,
            exerciseFrequency: exerciseFrequency,
            activityLevel: activityLevel,
            restingHeartRate: restingHeartRate,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    // MARK: - Age Validation Tests
    
    @Test func validAge_withinRange_returnsTrue() {
        #expect(UserProfile.isValidAge(1) == true)
        #expect(UserProfile.isValidAge(35) == true)
        #expect(UserProfile.isValidAge(149) == true)
    }
    
    @Test func validAge_atBoundaries_returnsCorrectly() {
        #expect(UserProfile.isValidAge(1) == true)   // Lower boundary
        #expect(UserProfile.isValidAge(149) == true) // Upper boundary
        #expect(UserProfile.isValidAge(0) == false)  // Below lower boundary
        #expect(UserProfile.isValidAge(150) == false) // Above upper boundary
    }
    
    @Test func validAge_negativeValue_returnsFalse() {
        #expect(UserProfile.isValidAge(-1) == false)
        #expect(UserProfile.isValidAge(-100) == false)
    }
    
    // MARK: - Height Validation Tests
    
    @Test func validHeight_withinRange_returnsTrue() {
        #expect(UserProfile.isValidHeight(0) == true)
        #expect(UserProfile.isValidHeight(175) == true)
        #expect(UserProfile.isValidHeight(300) == true)
    }
    
    @Test func validHeight_atBoundaries_returnsCorrectly() {
        #expect(UserProfile.isValidHeight(0) == true)    // Lower boundary
        #expect(UserProfile.isValidHeight(300) == true)  // Upper boundary
        #expect(UserProfile.isValidHeight(-0.1) == false) // Below lower boundary
        #expect(UserProfile.isValidHeight(300.1) == false) // Above upper boundary
    }
    
    @Test func validHeight_negativeValue_returnsFalse() {
        #expect(UserProfile.isValidHeight(-1) == false)
        #expect(UserProfile.isValidHeight(-50) == false)
    }
    
    // MARK: - Weight Validation Tests
    
    @Test func validWeight_withinRange_returnsTrue() {
        #expect(UserProfile.isValidWeight(0) == true)
        #expect(UserProfile.isValidWeight(70) == true)
        #expect(UserProfile.isValidWeight(500) == true)
    }
    
    @Test func validWeight_atBoundaries_returnsCorrectly() {
        #expect(UserProfile.isValidWeight(0) == true)    // Lower boundary
        #expect(UserProfile.isValidWeight(500) == true)  // Upper boundary
        #expect(UserProfile.isValidWeight(-0.1) == false) // Below lower boundary
        #expect(UserProfile.isValidWeight(500.1) == false) // Above upper boundary
    }
    
    @Test func validWeight_negativeValue_returnsFalse() {
        #expect(UserProfile.isValidWeight(-1) == false)
        #expect(UserProfile.isValidWeight(-100) == false)
    }

    
    // MARK: - Exercise Frequency Validation Tests
    
    @Test func validExerciseFrequency_withinRange_returnsTrue() {
        #expect(UserProfile.isValidExerciseFrequency(0) == true)
        #expect(UserProfile.isValidExerciseFrequency(3) == true)
        #expect(UserProfile.isValidExerciseFrequency(21) == true)
    }
    
    @Test func validExerciseFrequency_atBoundaries_returnsCorrectly() {
        #expect(UserProfile.isValidExerciseFrequency(0) == true)   // Lower boundary
        #expect(UserProfile.isValidExerciseFrequency(21) == true)  // Upper boundary
        #expect(UserProfile.isValidExerciseFrequency(-1) == false) // Below lower boundary
        #expect(UserProfile.isValidExerciseFrequency(22) == false) // Above upper boundary
    }
    
    @Test func validExerciseFrequency_negativeValue_returnsFalse() {
        #expect(UserProfile.isValidExerciseFrequency(-1) == false)
        #expect(UserProfile.isValidExerciseFrequency(-10) == false)
    }
    
    // MARK: - Profile isValid Tests
    
    @Test func isValid_withAllValidFields_returnsTrue() {
        let profile = createProfile()
        #expect(profile.isValid == true)
    }
    
    @Test func isValid_withNilOptionalFields_returnsTrue() {
        let profile = createProfile(
            age: nil,
            heightCm: nil,
            weightKg: nil,
            exerciseFrequency: nil
        )
        #expect(profile.isValid == true)
    }
    
    @Test func isValid_withInvalidAge_returnsFalse() {
        let profile = createProfile(age: 0)
        #expect(profile.isValid == false)
        
        let profile2 = createProfile(age: 150)
        #expect(profile2.isValid == false)
    }
    
    @Test func isValid_withInvalidHeight_returnsFalse() {
        let profile = createProfile(heightCm: -1)
        #expect(profile.isValid == false)
        
        let profile2 = createProfile(heightCm: 301)
        #expect(profile2.isValid == false)
    }
    
    @Test func isValid_withInvalidWeight_returnsFalse() {
        let profile = createProfile(weightKg: -1)
        #expect(profile.isValid == false)
        
        let profile2 = createProfile(weightKg: 501)
        #expect(profile2.isValid == false)
    }
    
    @Test func isValid_withInvalidExerciseFrequency_returnsFalse() {
        let profile = createProfile(exerciseFrequency: -1)
        #expect(profile.isValid == false)
        
        let profile2 = createProfile(exerciseFrequency: 22)
        #expect(profile2.isValid == false)
    }
    
    @Test func isValid_withMultipleInvalidFields_returnsFalse() {
        let profile = createProfile(age: 0, heightCm: -1, weightKg: 600)
        #expect(profile.isValid == false)
    }
}
