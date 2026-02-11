//
//  HeartRateParserTests.swift
//  MonitoringAppTests
//
//  Unit tests for HeartRateParser - BLE heart rate data parsing
//

import Testing
import Foundation
@testable import MonitoringApp

struct HeartRateParserTests {
    
    // MARK: - Basic Heart Rate Parsing Tests
    
    @Test func parse_8bitHeartRate_returnsCorrectValue() {
        // Flags: 0x00 = 8-bit HR, no sensor contact, no energy, no RR
        // HR: 72 BPM
        let data = Data([0x00, 72])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 72)
        #expect(result?.sensorContact == nil)
        #expect(result?.energyExpended == nil)
        #expect(result?.rrIntervals.isEmpty == true)
    }
    
    @Test func parse_16bitHeartRate_returnsCorrectValue() {
        // Flags: 0x01 = 16-bit HR
        // HR: 150 BPM (little endian: 0x96, 0x00)
        let data = Data([0x01, 0x96, 0x00])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 150)
    }
    
    @Test func parse_16bitHeartRateHighValue_returnsCorrectValue() {
        // Flags: 0x01 = 16-bit HR
        // HR: 300 BPM (little endian: 0x2C, 0x01) - outside normal range but parseable
        let data = Data([0x01, 0x2C, 0x01])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 300)
    }
    
    // MARK: - Sensor Contact Tests
    
    @Test func parse_sensorContactSupported_contactDetected_returnsTrue() {
        // Flags: 0x06 = 8-bit HR, sensor contact supported (bit 2), contact detected (bit 1)
        // HR: 75 BPM
        let data = Data([0x06, 75])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 75)
        #expect(result?.sensorContact == true)
    }
    
    @Test func parse_sensorContactSupported_contactNotDetected_returnsFalse() {
        // Flags: 0x04 = 8-bit HR, sensor contact supported (bit 2), contact NOT detected (bit 1 = 0)
        // HR: 75 BPM
        let data = Data([0x04, 75])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 75)
        #expect(result?.sensorContact == false)
    }
    
    @Test func parse_sensorContactNotSupported_returnsNil() {
        // Flags: 0x00 = 8-bit HR, sensor contact NOT supported
        // HR: 75 BPM
        let data = Data([0x00, 75])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.sensorContact == nil)
    }
    
    // MARK: - Energy Expended Tests
    
    @Test func parse_energyExpendedPresent_returnsCorrectValue() {
        // Flags: 0x08 = 8-bit HR, energy expended present
        // HR: 80 BPM
        // Energy: 500 kJ (little endian: 0xF4, 0x01)
        let data = Data([0x08, 80, 0xF4, 0x01])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 80)
        #expect(result?.energyExpended == 500)
    }
    
    @Test func parse_energyExpendedNotPresent_returnsNil() {
        // Flags: 0x00 = 8-bit HR, no energy expended
        let data = Data([0x00, 80])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.energyExpended == nil)
    }

    
    // MARK: - RR Interval Tests
    
    @Test func parse_singleRRInterval_returnsCorrectValue() {
        // Flags: 0x10 = 8-bit HR, RR intervals present
        // HR: 70 BPM
        // RR: 857ms = 877 in 1/1024 sec (little endian: 0x6D, 0x03)
        let data = Data([0x10, 70, 0x6D, 0x03])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 70)
        #expect(result?.rrIntervals.count == 1)
        
        // 877 / 1024 ≈ 0.8564 seconds
        let expectedRR = 877.0 / 1024.0
        #expect(abs((result?.rrIntervals.first ?? 0) - expectedRR) < 0.001)
    }
    
    @Test func parse_multipleRRIntervals_returnsAllValues() {
        // Flags: 0x10 = 8-bit HR, RR intervals present
        // HR: 70 BPM
        // RR1: 896ms (0x0380 = 896 in 1/1024 sec)
        // RR2: 892ms (0x037C = 892 in 1/1024 sec)
        let data = Data([0x10, 70, 0x80, 0x03, 0x7C, 0x03])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.rrIntervals.count == 2)
        
        let expectedRR1 = 896.0 / 1024.0
        let expectedRR2 = 892.0 / 1024.0
        #expect(abs((result?.rrIntervals[0] ?? 0) - expectedRR1) < 0.001)
        #expect(abs((result?.rrIntervals[1] ?? 0) - expectedRR2) < 0.001)
    }
    
    @Test func parse_noRRIntervals_returnsEmptyArray() {
        // Flags: 0x00 = 8-bit HR, no RR intervals
        let data = Data([0x00, 70])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.rrIntervals.isEmpty == true)
    }
    
    // MARK: - Combined Flags Tests
    
    @Test func parse_allFlagsSet_parsesCorrectly() {
        // Flags: 0x1F = 16-bit HR, sensor contact supported & detected, energy present, RR present
        // HR: 85 BPM (little endian: 0x55, 0x00)
        // Energy: 100 kJ (little endian: 0x64, 0x00)
        // RR: 850ms (0x0352 = 850 in 1/1024 sec)
        let data = Data([0x1F, 0x55, 0x00, 0x64, 0x00, 0x52, 0x03])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 85)
        #expect(result?.sensorContact == true)
        #expect(result?.energyExpended == 100)
        #expect(result?.rrIntervals.count == 1)
    }
    
    @Test func parse_16bitHRWithRRIntervals_parsesCorrectly() {
        // Flags: 0x11 = 16-bit HR, RR intervals present
        // HR: 120 BPM (little endian: 0x78, 0x00)
        // RR: 500ms (0x01F4 = 500 in 1/1024 sec)
        let data = Data([0x11, 0x78, 0x00, 0xF4, 0x01])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 120)
        #expect(result?.rrIntervals.count == 1)
        
        let expectedRR = 500.0 / 1024.0
        #expect(abs((result?.rrIntervals.first ?? 0) - expectedRR) < 0.001)
    }
    
    // MARK: - Invalid Data Tests
    
    @Test func parse_emptyData_returnsNil() {
        let data = Data()
        
        let result = HeartRateParser.parse(data)
        
        #expect(result == nil)
    }
    
    @Test func parse_singleByte_returnsNil() {
        let data = Data([0x00])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result == nil)
    }
    
    @Test func parse_16bitHRInsufficientBytes_returnsNil() {
        // Flags: 0x01 = 16-bit HR, but only 1 byte of HR data
        let data = Data([0x01, 0x50])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result == nil)
    }
    
    @Test func parse_energyExpendedInsufficientBytes_returnsNil() {
        // Flags: 0x08 = energy expended present, but insufficient bytes
        let data = Data([0x08, 70, 0x64])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result == nil)
    }
    
    // MARK: - Heart Rate Validation Tests
    
    @Test func isValidHeartRate_withinRange_returnsTrue() {
        #expect(HeartRateParser.isValidHeartRate(30) == true)
        #expect(HeartRateParser.isValidHeartRate(72) == true)
        #expect(HeartRateParser.isValidHeartRate(150) == true)
        #expect(HeartRateParser.isValidHeartRate(220) == true)
    }
    
    @Test func isValidHeartRate_atBoundaries_returnsCorrectly() {
        #expect(HeartRateParser.isValidHeartRate(30) == true)   // Lower boundary
        #expect(HeartRateParser.isValidHeartRate(220) == true)  // Upper boundary
        #expect(HeartRateParser.isValidHeartRate(29) == false)  // Below lower boundary
        #expect(HeartRateParser.isValidHeartRate(221) == false) // Above upper boundary
    }
    
    @Test func isValidHeartRate_extremeValues_returnsFalse() {
        #expect(HeartRateParser.isValidHeartRate(0) == false)
        #expect(HeartRateParser.isValidHeartRate(-1) == false)
        #expect(HeartRateParser.isValidHeartRate(300) == false)
        #expect(HeartRateParser.isValidHeartRate(1000) == false)
    }
    
    // MARK: - Edge Cases
    
    @Test func parse_minimumValidHeartRate_parsesCorrectly() {
        let data = Data([0x00, 30])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 30)
        #expect(HeartRateParser.isValidHeartRate(result?.heartRate ?? 0) == true)
    }
    
    @Test func parse_maximumValidHeartRate_parsesCorrectly() {
        let data = Data([0x00, 220])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 220)
        #expect(HeartRateParser.isValidHeartRate(result?.heartRate ?? 0) == true)
    }
    
    @Test func parse_zeroHeartRate_parsesButInvalid() {
        let data = Data([0x00, 0])
        
        let result = HeartRateParser.parse(data)
        
        #expect(result != nil)
        #expect(result?.heartRate == 0)
        #expect(HeartRateParser.isValidHeartRate(result?.heartRate ?? 0) == false)
    }
}
