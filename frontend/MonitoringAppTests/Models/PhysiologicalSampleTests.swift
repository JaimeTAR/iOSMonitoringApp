//
//  PhysiologicalSampleTests.swift
//  MonitoringAppTests
//
//  Unit tests for PhysiologicalSample model validation
//

import Testing
import Foundation
@testable import MonitoringApp

struct PhysiologicalSampleTests {
    
    // MARK: - Test Fixtures
    
    private func createSample(
        avgHeartRate: Double = 72,
        rmssd: Double? = 45.5,
        sdnn: Double? = 52.3,
        sampleCount: Int = 60
    ) -> PhysiologicalSample {
        PhysiologicalSample(
            userId: UUID(),
            windowStart: Date(),
            avgHeartRate: avgHeartRate,
            rmssd: rmssd,
            sdnn: sdnn,
            sampleCount: sampleCount
        )
    }
    
    // MARK: - Heart Rate Validation Tests
    
    @Test func isValidHeartRate_withinRange_returnsTrue() {
        #expect(PhysiologicalSample.isValidHeartRate(0) == true)
        #expect(PhysiologicalSample.isValidHeartRate(72) == true)
        #expect(PhysiologicalSample.isValidHeartRate(150) == true)
        #expect(PhysiologicalSample.isValidHeartRate(300) == true)
    }
    
    @Test func isValidHeartRate_atBoundaries_returnsCorrectly() {
        #expect(PhysiologicalSample.isValidHeartRate(0) == true)     // Lower boundary
        #expect(PhysiologicalSample.isValidHeartRate(300) == true)   // Upper boundary
        #expect(PhysiologicalSample.isValidHeartRate(-0.1) == false) // Below lower boundary
        #expect(PhysiologicalSample.isValidHeartRate(300.1) == false) // Above upper boundary
    }
    
    @Test func isValidHeartRate_negativeValue_returnsFalse() {
        #expect(PhysiologicalSample.isValidHeartRate(-1) == false)
        #expect(PhysiologicalSample.isValidHeartRate(-100) == false)
    }
    
    @Test func isValidHeartRate_extremeHighValue_returnsFalse() {
        #expect(PhysiologicalSample.isValidHeartRate(301) == false)
        #expect(PhysiologicalSample.isValidHeartRate(1000) == false)
    }
    
    // MARK: - RMSSD Validation Tests
    
    @Test func isValidRMSSD_nonNegative_returnsTrue() {
        #expect(PhysiologicalSample.isValidRMSSD(0) == true)
        #expect(PhysiologicalSample.isValidRMSSD(45.5) == true)
        #expect(PhysiologicalSample.isValidRMSSD(100) == true)
        #expect(PhysiologicalSample.isValidRMSSD(1000) == true)
    }
    
    @Test func isValidRMSSD_negative_returnsFalse() {
        #expect(PhysiologicalSample.isValidRMSSD(-0.1) == false)
        #expect(PhysiologicalSample.isValidRMSSD(-1) == false)
        #expect(PhysiologicalSample.isValidRMSSD(-100) == false)
    }
    
    @Test func isValidRMSSD_atZeroBoundary_returnsTrue() {
        #expect(PhysiologicalSample.isValidRMSSD(0) == true)
        #expect(PhysiologicalSample.isValidRMSSD(0.0001) == true)
    }
    
    // MARK: - SDNN Validation Tests
    
    @Test func isValidSDNN_nonNegative_returnsTrue() {
        #expect(PhysiologicalSample.isValidSDNN(0) == true)
        #expect(PhysiologicalSample.isValidSDNN(52.3) == true)
        #expect(PhysiologicalSample.isValidSDNN(100) == true)
        #expect(PhysiologicalSample.isValidSDNN(1000) == true)
    }
    
    @Test func isValidSDNN_negative_returnsFalse() {
        #expect(PhysiologicalSample.isValidSDNN(-0.1) == false)
        #expect(PhysiologicalSample.isValidSDNN(-1) == false)
        #expect(PhysiologicalSample.isValidSDNN(-100) == false)
    }
    
    @Test func isValidSDNN_atZeroBoundary_returnsTrue() {
        #expect(PhysiologicalSample.isValidSDNN(0) == true)
        #expect(PhysiologicalSample.isValidSDNN(0.0001) == true)
    }

    
    // MARK: - Sample isValid Tests
    
    @Test func isValid_withAllValidFields_returnsTrue() {
        let sample = createSample()
        #expect(sample.isValid == true)
    }
    
    @Test func isValid_withNilOptionalFields_returnsTrue() {
        let sample = createSample(rmssd: nil, sdnn: nil)
        #expect(sample.isValid == true)
    }
    
    @Test func isValid_withInvalidHeartRate_returnsFalse() {
        let sample = createSample(avgHeartRate: -1)
        #expect(sample.isValid == false)
        
        let sample2 = createSample(avgHeartRate: 301)
        #expect(sample2.isValid == false)
    }
    
    @Test func isValid_withInvalidRMSSD_returnsFalse() {
        let sample = createSample(rmssd: -1)
        #expect(sample.isValid == false)
        
        let sample2 = createSample(rmssd: -0.1)
        #expect(sample2.isValid == false)
    }
    
    @Test func isValid_withInvalidSDNN_returnsFalse() {
        let sample = createSample(sdnn: -1)
        #expect(sample.isValid == false)
        
        let sample2 = createSample(sdnn: -0.1)
        #expect(sample2.isValid == false)
    }
    
    @Test func isValid_withMultipleInvalidFields_returnsFalse() {
        let sample = createSample(avgHeartRate: -1, rmssd: -1, sdnn: -1)
        #expect(sample.isValid == false)
    }
    
    @Test func isValid_withValidHeartRateAndNilHRVMetrics_returnsTrue() {
        let sample = createSample(avgHeartRate: 72, rmssd: nil, sdnn: nil)
        #expect(sample.isValid == true)
    }
    
    @Test func isValid_withZeroHeartRate_returnsTrue() {
        // 0 BPM is technically valid per the validation range (0-300)
        let sample = createSample(avgHeartRate: 0)
        #expect(sample.isValid == true)
    }
    
    @Test func isValid_withMaxHeartRate_returnsTrue() {
        let sample = createSample(avgHeartRate: 300)
        #expect(sample.isValid == true)
    }
    
    @Test func isValid_withZeroHRVMetrics_returnsTrue() {
        let sample = createSample(rmssd: 0, sdnn: 0)
        #expect(sample.isValid == true)
    }
    
    // MARK: - Initialization Tests
    
    @Test func init_setsIsSyncedToFalse() {
        let sample = createSample()
        #expect(sample.isSynced == false)
    }
    
    @Test func init_generatesUniqueId() {
        let sample1 = createSample()
        let sample2 = createSample()
        #expect(sample1.id != sample2.id)
    }
    
    @Test func init_setsCreatedAtToCurrentTime() {
        let beforeCreation = Date()
        let sample = createSample()
        let afterCreation = Date()
        
        #expect(sample.createdAt >= beforeCreation)
        #expect(sample.createdAt <= afterCreation)
    }
}
