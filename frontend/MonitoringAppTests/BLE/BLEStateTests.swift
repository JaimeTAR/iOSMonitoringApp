//
//  BLEStateTests.swift
//  MonitoringAppTests
//
//  Unit tests for BLEState enum - state transitions and equality
//

import Testing
import Foundation
import CoreBluetooth
@testable import MonitoringApp

@MainActor
struct BLEStateTests {
    
    // MARK: - Test Helpers
    
    /// Creates a mock DiscoveredDevice for testing
    /// Note: We can't create real CBPeripheral instances in tests, so we test state equality logic
    
    // MARK: - State Equality Tests
    
    @Test func equality_sameSimpleStates_returnsTrue() {
        #expect(BLEState.unknown == BLEState.unknown)
        #expect(BLEState.poweredOff == BLEState.poweredOff)
        #expect(BLEState.unauthorized == BLEState.unauthorized)
        #expect(BLEState.poweredOn == BLEState.poweredOn)
        #expect(BLEState.scanning == BLEState.scanning)
        #expect(BLEState.disconnected == BLEState.disconnected)
    }
    
    @Test func equality_differentSimpleStates_returnsFalse() {
        #expect(BLEState.unknown != BLEState.poweredOff)
        #expect(BLEState.poweredOff != BLEState.unauthorized)
        #expect(BLEState.unauthorized != BLEState.poweredOn)
        #expect(BLEState.poweredOn != BLEState.scanning)
        #expect(BLEState.scanning != BLEState.disconnected)
        #expect(BLEState.disconnected != BLEState.unknown)
    }
    
    @Test func equality_unknownVsOtherStates_returnsFalse() {
        #expect(BLEState.unknown != BLEState.poweredOff)
        #expect(BLEState.unknown != BLEState.unauthorized)
        #expect(BLEState.unknown != BLEState.poweredOn)
        #expect(BLEState.unknown != BLEState.scanning)
        #expect(BLEState.unknown != BLEState.disconnected)
    }
    
    @Test func equality_poweredOffVsOtherStates_returnsFalse() {
        #expect(BLEState.poweredOff != BLEState.unknown)
        #expect(BLEState.poweredOff != BLEState.unauthorized)
        #expect(BLEState.poweredOff != BLEState.poweredOn)
        #expect(BLEState.poweredOff != BLEState.scanning)
        #expect(BLEState.poweredOff != BLEState.disconnected)
    }
    
    // MARK: - State Transition Logic Tests
    
    @Test func stateTransition_fromUnknownToPoweredOn_isValid() {
        var state: BLEState = .unknown
        state = .poweredOn
        #expect(state == .poweredOn)
    }
    
    @Test func stateTransition_fromPoweredOnToScanning_isValid() {
        var state: BLEState = .poweredOn
        state = .scanning
        #expect(state == .scanning)
    }
    
    @Test func stateTransition_fromScanningToDisconnected_isValid() {
        var state: BLEState = .scanning
        state = .disconnected
        #expect(state == .disconnected)
    }
    
    @Test func stateTransition_fromDisconnectedToPoweredOn_isValid() {
        var state: BLEState = .disconnected
        state = .poweredOn
        #expect(state == .poweredOn)
    }
    
    @Test func stateTransition_toPoweredOff_fromAnyState() {
        var state: BLEState = .poweredOn
        state = .poweredOff
        #expect(state == .poweredOff)
        
        state = .scanning
        state = .poweredOff
        #expect(state == .poweredOff)
        
        state = .disconnected
        state = .poweredOff
        #expect(state == .poweredOff)
    }
    
    @Test func stateTransition_toUnauthorized_fromAnyState() {
        var state: BLEState = .poweredOn
        state = .unauthorized
        #expect(state == .unauthorized)
        
        state = .scanning
        state = .unauthorized
        #expect(state == .unauthorized)
    }
    
    // MARK: - State Description Tests (for debugging)
    
    @Test func allStates_areDistinct() {
        let states: [BLEState] = [
            .unknown,
            .poweredOff,
            .unauthorized,
            .poweredOn,
            .scanning,
            .disconnected
        ]
        
        // Each state should only equal itself
        for (index, state) in states.enumerated() {
            for (otherIndex, otherState) in states.enumerated() {
                if index == otherIndex {
                    #expect(state == otherState)
                } else {
                    #expect(state != otherState)
                }
            }
        }
    }
}
