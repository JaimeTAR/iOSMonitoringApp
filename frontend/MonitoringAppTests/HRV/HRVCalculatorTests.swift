//
//  HRVCalculatorTests.swift
//  MonitoringAppTests
//
//  Unit tests for HRVCalculator - RMSSD and SDNN calculations
//  Requirements: 20.2
//

import Testing
import Foundation
@testable import MonitoringApp

struct HRVCalculatorTests {
    
    let calculator = HRVCalculator()
    
    // MARK: - RMSSD Tests
    
    @Test func calculateRMSSD_withKnownSequence_returnsCorrectValue() {
        // Known RR intervals in seconds: 0.8, 0.85, 0.82, 0.88
        // Successive differences: 0.05, -0.03, 0.06
        // Squared differences: 0.0025, 0.0009, 0.0036
        // Sum: 0.007, Mean: 0.007/3 = 0.002333
        // RMSSD in seconds: sqrt(0.002333) ≈ 0.0483
        // RMSSD in ms: 48.3
        let rrIntervals = [0.8, 0.85, 0.82, 0.88]
        
        let result = calculator.calculateRMSSD(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        #expect(abs((result ?? 0) - 48.3) < 1.0) // Within 1ms tolerance
    }
    
    @Test func calculateRMSSD_withConstantIntervals_returnsZero() {
        // All intervals are the same, so successive differences are 0
        let rrIntervals = [0.8, 0.8, 0.8, 0.8]
        
        let result = calculator.calculateRMSSD(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        #expect(result == 0.0)
    }
    
    @Test func calculateRMSSD_withTwoIntervals_returnsValue() {
        // Minimum valid case: 2 intervals
        // Difference: 0.05, Squared: 0.0025, RMSSD: sqrt(0.0025) = 0.05 sec = 50ms
        let rrIntervals = [0.8, 0.85]
        
        let result = calculator.calculateRMSSD(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        #expect(abs((result ?? 0) - 50.0) < 0.1)
    }
    
    @Test func calculateRMSSD_withSingleInterval_returnsNil() {
        let rrIntervals = [0.8]
        
        let result = calculator.calculateRMSSD(rrIntervals: rrIntervals)
        
        #expect(result == nil)
    }
    
    @Test func calculateRMSSD_withEmptyArray_returnsNil() {
        let rrIntervals: [Double] = []
        
        let result = calculator.calculateRMSSD(rrIntervals: rrIntervals)
        
        #expect(result == nil)
    }
    
    @Test func calculateRMSSD_filtersOutliers_belowMinimum() {
        // 0.2 is below minimum (0.3), should be filtered out
        // Only [0.8, 0.85] remain
        let rrIntervals = [0.2, 0.8, 0.85]
        
        let result = calculator.calculateRMSSD(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        #expect(abs((result ?? 0) - 50.0) < 0.1)
    }
    
    @Test func calculateRMSSD_filtersOutliers_aboveMaximum() {
        // 2.5 is above maximum (2.0), should be filtered out
        // Only [0.8, 0.85] remain
        let rrIntervals = [0.8, 2.5, 0.85]
        
        let result = calculator.calculateRMSSD(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        #expect(abs((result ?? 0) - 50.0) < 0.1)
    }
    
    @Test func calculateRMSSD_allOutliers_returnsNil() {
        // All values outside valid range
        let rrIntervals = [0.1, 0.2, 3.0, 4.0]
        
        let result = calculator.calculateRMSSD(rrIntervals: rrIntervals)
        
        #expect(result == nil)
    }
    
    // MARK: - SDNN Tests
    
    @Test func calculateSDNN_withKnownSequence_returnsCorrectValue() {
        // RR intervals: 0.8, 0.85, 0.82, 0.88
        // Mean: 0.8375
        // Deviations: -0.0375, 0.0125, -0.0175, 0.0425
        // Squared: 0.00140625, 0.00015625, 0.00030625, 0.00180625
        // Variance: 0.003675/4 = 0.00091875
        // SDNN in seconds: sqrt(0.00091875) ≈ 0.0303
        // SDNN in ms: 30.3
        let rrIntervals = [0.8, 0.85, 0.82, 0.88]
        
        let result = calculator.calculateSDNN(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        #expect(abs((result ?? 0) - 30.3) < 1.0) // Within 1ms tolerance
    }
    
    @Test func calculateSDNN_withConstantIntervals_returnsZero() {
        // All intervals are the same, so standard deviation is 0
        let rrIntervals = [0.8, 0.8, 0.8, 0.8]
        
        let result = calculator.calculateSDNN(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        #expect(result == 0.0)
    }
    
    @Test func calculateSDNN_withTwoIntervals_returnsValue() {
        // Minimum valid case: 2 intervals
        // Mean: 0.825, Deviations: -0.025, 0.025
        // Variance: 0.00125/2 = 0.000625
        // SDNN: sqrt(0.000625) = 0.025 sec = 25ms
        let rrIntervals = [0.8, 0.85]
        
        let result = calculator.calculateSDNN(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        #expect(abs((result ?? 0) - 25.0) < 0.1)
    }
    
    @Test func calculateSDNN_withSingleInterval_returnsNil() {
        let rrIntervals = [0.8]
        
        let result = calculator.calculateSDNN(rrIntervals: rrIntervals)
        
        #expect(result == nil)
    }
    
    @Test func calculateSDNN_withEmptyArray_returnsNil() {
        let rrIntervals: [Double] = []
        
        let result = calculator.calculateSDNN(rrIntervals: rrIntervals)
        
        #expect(result == nil)
    }
    
    @Test func calculateSDNN_filtersOutliers() {
        // 0.1 and 3.0 are outside valid range, should be filtered
        // Only [0.8, 0.85] remain
        let rrIntervals = [0.1, 0.8, 3.0, 0.85]
        
        let result = calculator.calculateSDNN(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        #expect(abs((result ?? 0) - 25.0) < 0.1)
    }
    
    // MARK: - Boundary Tests
    
    @Test func calculateRMSSD_atMinimumBoundary_includesValue() {
        // 0.3 is exactly at minimum boundary, should be included
        let rrIntervals = [0.3, 0.35]
        
        let result = calculator.calculateRMSSD(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        #expect(abs((result ?? 0) - 50.0) < 0.1)
    }
    
    @Test func calculateRMSSD_atMaximumBoundary_includesValue() {
        // 2.0 is exactly at maximum boundary, should be included
        let rrIntervals = [1.95, 2.0]
        
        let result = calculator.calculateRMSSD(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        #expect(abs((result ?? 0) - 50.0) < 0.1)
    }
    
    // MARK: - Real-World Scenario Tests
    
    @Test func calculateRMSSD_typicalRestingHRV_returnsReasonableValue() {
        // Typical resting RR intervals (~60 BPM with normal variability)
        let rrIntervals = [1.0, 0.98, 1.02, 0.99, 1.01, 0.97, 1.03]
        
        let result = calculator.calculateRMSSD(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        // Typical resting RMSSD is 20-100ms
        #expect((result ?? 0) > 10 && (result ?? 0) < 100)
    }
    
    @Test func calculateSDNN_typicalRestingHRV_returnsReasonableValue() {
        // Typical resting RR intervals
        let rrIntervals = [1.0, 0.98, 1.02, 0.99, 1.01, 0.97, 1.03]
        
        let result = calculator.calculateSDNN(rrIntervals: rrIntervals)
        
        #expect(result != nil)
        // Typical resting SDNN is 30-100ms
        #expect((result ?? 0) > 10 && (result ?? 0) < 100)
    }
}
