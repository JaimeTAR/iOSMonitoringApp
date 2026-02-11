//
//  WindowAggregatorTests.swift
//  MonitoringAppTests
//
//  Unit tests for WindowAggregator - 1-minute window aggregation logic
//  Requirements: 20.2
//

import Testing
import Foundation
@testable import MonitoringApp

struct WindowAggregatorTests {
    
    let aggregator = WindowAggregator()
    let testUserId = UUID()
    let testWindowStart = Date()
    
    // MARK: - Basic Aggregation Tests
    
    @Test func aggregate_withValidSamples_returnsPhysiologicalSample() {
        let samples = [
            HeartRateData(heartRate: 70, rrIntervals: [0.85, 0.87]),
            HeartRateData(heartRate: 72, rrIntervals: [0.83, 0.86]),
            HeartRateData(heartRate: 68, rrIntervals: [0.88, 0.84])
        ]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.userId == testUserId)
        #expect(result?.windowStart == testWindowStart)
        #expect(result?.sampleCount == 3)
    }
    
    @Test func aggregate_calculatesCorrectAverageHeartRate() {
        let samples = [
            HeartRateData(heartRate: 70),
            HeartRateData(heartRate: 80),
            HeartRateData(heartRate: 90)
        ]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.avgHeartRate == 80.0) // (70 + 80 + 90) / 3
    }
    
    @Test func aggregate_withSingleSample_returnsCorrectAverage() {
        let samples = [HeartRateData(heartRate: 75)]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.avgHeartRate == 75.0)
        #expect(result?.sampleCount == 1)
    }
    
    // MARK: - Empty/Invalid Input Tests
    
    @Test func aggregate_withEmptySamples_returnsNil() {
        let samples: [HeartRateData] = []
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result == nil)
    }
    
    @Test func aggregate_withAllInvalidSamples_returnsNil() {
        // Heart rates outside valid range (30-220)
        let samples = [
            HeartRateData(heartRate: 10),
            HeartRateData(heartRate: 250),
            HeartRateData(heartRate: 0)
        ]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result == nil)
    }
    
    @Test func aggregate_filtersInvalidSamples() {
        // Mix of valid and invalid samples
        let samples = [
            HeartRateData(heartRate: 70),  // valid
            HeartRateData(heartRate: 10),  // invalid - too low
            HeartRateData(heartRate: 80),  // valid
            HeartRateData(heartRate: 250)  // invalid - too high
        ]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.avgHeartRate == 75.0) // (70 + 80) / 2
        #expect(result?.sampleCount == 2)
    }
    
    // MARK: - HRV Calculation Tests
    
    @Test func aggregate_calculatesRMSSD_whenRRIntervalsPresent() {
        let samples = [
            HeartRateData(heartRate: 70, rrIntervals: [0.8, 0.85]),
            HeartRateData(heartRate: 72, rrIntervals: [0.82, 0.88])
        ]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.rmssd != nil)
        #expect((result?.rmssd ?? 0) > 0)
    }
    
    @Test func aggregate_calculatesSDNN_whenRRIntervalsPresent() {
        let samples = [
            HeartRateData(heartRate: 70, rrIntervals: [0.8, 0.85]),
            HeartRateData(heartRate: 72, rrIntervals: [0.82, 0.88])
        ]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.sdnn != nil)
        #expect((result?.sdnn ?? 0) > 0)
    }
    
    @Test func aggregate_returnsNilHRV_whenNoRRIntervals() {
        let samples = [
            HeartRateData(heartRate: 70, rrIntervals: []),
            HeartRateData(heartRate: 72, rrIntervals: [])
        ]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.rmssd == nil)
        #expect(result?.sdnn == nil)
    }
    
    @Test func aggregate_returnsNilHRV_whenInsufficientRRIntervals() {
        // Only 1 RR interval total - not enough for HRV calculation
        let samples = [
            HeartRateData(heartRate: 70, rrIntervals: [0.85])
        ]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.rmssd == nil)
        #expect(result?.sdnn == nil)
    }
    
    @Test func aggregate_combinesRRIntervalsFromAllSamples() {
        // Each sample has 1 RR interval, combined they have 3
        let samples = [
            HeartRateData(heartRate: 70, rrIntervals: [0.8]),
            HeartRateData(heartRate: 72, rrIntervals: [0.85]),
            HeartRateData(heartRate: 68, rrIntervals: [0.82])
        ]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.rmssd != nil)
        #expect(result?.sdnn != nil)
    }
    
    // MARK: - Sample Validation Tests
    
    @Test func aggregate_resultIsValid() {
        let samples = [
            HeartRateData(heartRate: 70, rrIntervals: [0.8, 0.85]),
            HeartRateData(heartRate: 72, rrIntervals: [0.82, 0.88])
        ]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.isValid == true)
    }
    
    @Test func aggregate_setsIsSyncedToFalse() {
        let samples = [HeartRateData(heartRate: 70)]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.isSynced == false)
    }
    
    // MARK: - Boundary Tests
    
    @Test func aggregate_atMinimumValidHeartRate_succeeds() {
        let samples = [HeartRateData(heartRate: 30)]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.avgHeartRate == 30.0)
    }
    
    @Test func aggregate_atMaximumValidHeartRate_succeeds() {
        let samples = [HeartRateData(heartRate: 220)]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result != nil)
        #expect(result?.avgHeartRate == 220.0)
    }
    
    @Test func aggregate_belowMinimumHeartRate_filtered() {
        let samples = [HeartRateData(heartRate: 29)]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result == nil)
    }
    
    @Test func aggregate_aboveMaximumHeartRate_filtered() {
        let samples = [HeartRateData(heartRate: 221)]
        
        let result = aggregator.aggregate(samples: samples, windowStart: testWindowStart, userId: testUserId)
        
        #expect(result == nil)
    }
}
