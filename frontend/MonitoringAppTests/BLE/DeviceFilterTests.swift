//
//  DeviceFilterTests.swift
//  MonitoringAppTests
//
//  Unit tests for device filtering by signal strength (RSSI)
//

import Testing
import Foundation
@testable import MonitoringApp

struct DeviceFilterTests {
    
    // MARK: - Device Filtering Helper
    
    /// Simulates the device filtering logic used in BLEService
    /// Filters and sorts devices by RSSI, keeping only top 5
    private func filterDevices(_ devices: [MockDevice], maxCount: Int = 5) -> [MockDevice] {
        devices
            .sorted { $0.rssi > $1.rssi }
            .prefix(maxCount)
            .map { $0 }
    }
    
    /// Mock device for testing filtering logic without CoreBluetooth dependency
    struct MockDevice: Identifiable {
        let id: UUID
        let name: String
        let rssi: Int
        
        init(name: String = "Device", rssi: Int) {
            self.id = UUID()
            self.name = name
            self.rssi = rssi
        }
    }
    
    // MARK: - Sorting Tests
    
    @Test func filterDevices_sortsbyRSSIDescending() {
        let devices = [
            MockDevice(name: "Weak", rssi: -90),
            MockDevice(name: "Strong", rssi: -50),
            MockDevice(name: "Medium", rssi: -70)
        ]
        
        let filtered = filterDevices(devices)
        
        #expect(filtered.count == 3)
        #expect(filtered[0].name == "Strong")
        #expect(filtered[1].name == "Medium")
        #expect(filtered[2].name == "Weak")
    }
    
    @Test func filterDevices_handlesEqualRSSI() {
        let devices = [
            MockDevice(name: "Device1", rssi: -60),
            MockDevice(name: "Device2", rssi: -60),
            MockDevice(name: "Device3", rssi: -60)
        ]
        
        let filtered = filterDevices(devices)
        
        #expect(filtered.count == 3)
        // All have same RSSI, order may vary but all should be present
        let names = filtered.map { $0.name }
        #expect(names.contains("Device1"))
        #expect(names.contains("Device2"))
        #expect(names.contains("Device3"))
    }
    
    // MARK: - Limit Tests
    
    @Test func filterDevices_limitsToMaxCount() {
        let devices = [
            MockDevice(name: "Device1", rssi: -50),
            MockDevice(name: "Device2", rssi: -55),
            MockDevice(name: "Device3", rssi: -60),
            MockDevice(name: "Device4", rssi: -65),
            MockDevice(name: "Device5", rssi: -70),
            MockDevice(name: "Device6", rssi: -75),
            MockDevice(name: "Device7", rssi: -80)
        ]
        
        let filtered = filterDevices(devices, maxCount: 5)
        
        #expect(filtered.count == 5)
    }
    
    @Test func filterDevices_keepsStrongestSignals() {
        let devices = [
            MockDevice(name: "Strongest", rssi: -40),
            MockDevice(name: "Strong", rssi: -50),
            MockDevice(name: "Medium", rssi: -60),
            MockDevice(name: "Weak", rssi: -70),
            MockDevice(name: "Weaker", rssi: -80),
            MockDevice(name: "Weakest", rssi: -90),
            MockDevice(name: "VeryWeak", rssi: -100)
        ]
        
        let filtered = filterDevices(devices, maxCount: 5)
        
        #expect(filtered.count == 5)
        #expect(filtered[0].name == "Strongest")
        #expect(filtered[1].name == "Strong")
        #expect(filtered[2].name == "Medium")
        #expect(filtered[3].name == "Weak")
        #expect(filtered[4].name == "Weaker")
        
        // Weakest signals should be excluded
        let names = filtered.map { $0.name }
        #expect(!names.contains("Weakest"))
        #expect(!names.contains("VeryWeak"))
    }
    
    @Test func filterDevices_exactlyMaxCount_returnsAll() {
        let devices = [
            MockDevice(name: "Device1", rssi: -50),
            MockDevice(name: "Device2", rssi: -60),
            MockDevice(name: "Device3", rssi: -70),
            MockDevice(name: "Device4", rssi: -80),
            MockDevice(name: "Device5", rssi: -90)
        ]
        
        let filtered = filterDevices(devices, maxCount: 5)
        
        #expect(filtered.count == 5)
    }
    
    @Test func filterDevices_lessThanMaxCount_returnsAll() {
        let devices = [
            MockDevice(name: "Device1", rssi: -50),
            MockDevice(name: "Device2", rssi: -60),
            MockDevice(name: "Device3", rssi: -70)
        ]
        
        let filtered = filterDevices(devices, maxCount: 5)
        
        #expect(filtered.count == 3)
    }
    
    // MARK: - Edge Cases
    
    @Test func filterDevices_emptyArray_returnsEmpty() {
        let devices: [MockDevice] = []
        
        let filtered = filterDevices(devices)
        
        #expect(filtered.isEmpty)
    }
    
    @Test func filterDevices_singleDevice_returnsSingleDevice() {
        let devices = [MockDevice(name: "OnlyDevice", rssi: -60)]
        
        let filtered = filterDevices(devices)
        
        #expect(filtered.count == 1)
        #expect(filtered[0].name == "OnlyDevice")
    }
    
    @Test func filterDevices_negativeRSSIValues_sortsCorrectly() {
        // RSSI values are typically negative (closer to 0 = stronger)
        let devices = [
            MockDevice(name: "VeryStrong", rssi: -30),
            MockDevice(name: "Strong", rssi: -45),
            MockDevice(name: "Medium", rssi: -60),
            MockDevice(name: "Weak", rssi: -85),
            MockDevice(name: "VeryWeak", rssi: -100)
        ]
        
        let filtered = filterDevices(devices)
        
        #expect(filtered[0].rssi == -30)
        #expect(filtered[1].rssi == -45)
        #expect(filtered[2].rssi == -60)
        #expect(filtered[3].rssi == -85)
        #expect(filtered[4].rssi == -100)
    }
    
    @Test func filterDevices_mixedPositiveNegativeRSSI_sortsCorrectly() {
        // Edge case: some devices might report positive RSSI (unusual but possible)
        let devices = [
            MockDevice(name: "Positive", rssi: 10),
            MockDevice(name: "Zero", rssi: 0),
            MockDevice(name: "Negative", rssi: -50)
        ]
        
        let filtered = filterDevices(devices)
        
        #expect(filtered[0].name == "Positive")
        #expect(filtered[1].name == "Zero")
        #expect(filtered[2].name == "Negative")
    }
    
    // MARK: - RSSI Range Tests
    
    @Test func filterDevices_typicalRSSIRange_sortsCorrectly() {
        // Typical BLE RSSI range is -30 (very close) to -100 (far away)
        let devices = [
            MockDevice(name: "Excellent", rssi: -35),
            MockDevice(name: "Good", rssi: -55),
            MockDevice(name: "Fair", rssi: -75),
            MockDevice(name: "Poor", rssi: -95)
        ]
        
        let filtered = filterDevices(devices)
        
        #expect(filtered[0].name == "Excellent")
        #expect(filtered[1].name == "Good")
        #expect(filtered[2].name == "Fair")
        #expect(filtered[3].name == "Poor")
    }
    
    @Test func filterDevices_customMaxCount_respectsLimit() {
        let devices = [
            MockDevice(rssi: -40),
            MockDevice(rssi: -50),
            MockDevice(rssi: -60),
            MockDevice(rssi: -70),
            MockDevice(rssi: -80)
        ]
        
        let filtered3 = filterDevices(devices, maxCount: 3)
        #expect(filtered3.count == 3)
        
        let filtered1 = filterDevices(devices, maxCount: 1)
        #expect(filtered1.count == 1)
        #expect(filtered1[0].rssi == -40)
        
        let filtered10 = filterDevices(devices, maxCount: 10)
        #expect(filtered10.count == 5) // Only 5 devices available
    }
}
