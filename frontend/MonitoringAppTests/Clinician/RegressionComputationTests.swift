//
//  RegressionComputationTests.swift
//  MonitoringAppTests
//
//  Property tests (P6–P11) and unit tests for OLS linear regression.
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Test Helpers

private func makeSample(avgHeartRate: Double, windowStart: Date = Date()) -> PhysiologicalSample {
    PhysiologicalSample(userId: UUID(), windowStart: windowStart, avgHeartRate: avgHeartRate, rmssd: 40.0, sdnn: 50.0, sampleCount: 60)
}

// MARK: - Property Tests

struct RegressionComputationPropertyTests {

    // Feature: hr-trend-regression, Property 6: Regresión nil para menos de 2 muestras
    /// **Validates: Requirements 2.4**
    @Test func property6_regressionNilForFewerThan2Samples() {
        property("computeRegression returns nil for 0 or 1 samples") <- forAll(
            Gen<UInt>.fromElements(in: 0...1)
        ) { count in
            let samples = (0..<Int(count)).map { _ in PhysiologicalSample.arbitrary.generate }
            let result = PatientDetailViewModel.computeRegression(from: samples)
            return result == nil
        }
    }

    // Feature: hr-trend-regression, Property 7: Regresión nil para timestamps idénticos
    /// **Validates: Requirements 2.5**
    @Test func property7_regressionNilForIdenticalTimestamps() {
        property("computeRegression returns nil when all timestamps are equal") <- forAll(
            Gen<UInt>.fromElements(in: 2...20),
            Gen<Double>.fromElements(in: 40...120)
        ) { count, hr in
            let sharedDate = Date(timeIntervalSince1970: 1_000_000)
            let samples = (0..<Int(count)).map { _ in
                makeSample(avgHeartRate: hr, windowStart: sharedDate)
            }
            let result = PatientDetailViewModel.computeRegression(from: samples)
            return result == nil
        }
    }

    // Feature: hr-trend-regression, Property 8: Valores constantes producen pendiente cero
    /// **Validates: Requirements 10.1**
    @Test func property8_constantValuesProduceZeroSlope() {
        property("constant avgHeartRate produces slope ≈ 0 and intercept ≈ C") <- forAll(
            Gen<UInt>.fromElements(in: 2...20),
            Gen<Double>.fromElements(in: 40...120)
        ) { count, constantHR in
            let baseDate = Date(timeIntervalSince1970: 1_000_000)
            let samples = (0..<Int(count)).map { i in
                makeSample(avgHeartRate: constantHR, windowStart: baseDate.addingTimeInterval(Double(i) * 3600))
            }
            guard let result = PatientDetailViewModel.computeRegression(from: samples) else {
                return false
            }
            return abs(result.slope) < 1e-6 && abs(result.intercept - constantHR) < 1e-6
        }
    }

    // Feature: hr-trend-regression, Property 9: Dos puntos producen ajuste exacto
    /// **Validates: Requirements 10.2**
    @Test func property9_twoPointsProduceExactFit() {
        property("regression through 2 points predicts each point exactly") <- forAll(
            Gen<Double>.fromElements(in: 40...120),
            Gen<Double>.fromElements(in: 40...120),
            Gen<Double>.fromElements(in: 1_000_000...1_500_000),
            Gen<Double>.fromElements(in: 3600...86400)
        ) { hr1, hr2, baseEpoch, gap in
            let t1 = Date(timeIntervalSince1970: baseEpoch)
            let t2 = Date(timeIntervalSince1970: baseEpoch + gap)
            let s1 = makeSample(avgHeartRate: hr1, windowStart: t1)
            let s2 = makeSample(avgHeartRate: hr2, windowStart: t2)
            guard let result = PatientDetailViewModel.computeRegression(from: [s1, s2]) else {
                return false
            }
            let pred1 = PatientDetailViewModel.predictValue(at: t1, using: result)
            let pred2 = PatientDetailViewModel.predictValue(at: t2, using: result)
            return abs(pred1 - hr1) < 1e-6 && abs(pred2 - hr2) < 1e-6
        }
    }

    // Feature: hr-trend-regression, Property 10: Suma de residuos igual a cero
    /// **Validates: Requirements 10.3**
    @Test func property10_sumOfResidualsIsZero() {
        property("sum of residuals ≈ 0 for valid regression") <- forAll(
            Gen<UInt>.fromElements(in: 2...20)
        ) { count in
            let baseDate = Date(timeIntervalSince1970: 1_000_000)
            let samples = (0..<Int(count)).map { i in
                let hr = PhysiologicalSample.arbitrary.generate.avgHeartRate
                return makeSample(avgHeartRate: hr, windowStart: baseDate.addingTimeInterval(Double(i) * 3600))
            }
            guard let result = PatientDetailViewModel.computeRegression(from: samples) else {
                // nil is acceptable if timestamps happen to collide (shouldn't with distinct offsets)
                return true
            }
            let sumResiduals = samples.reduce(0.0) { acc, sample in
                let predicted = PatientDetailViewModel.predictValue(at: sample.windowStart, using: result)
                return acc + (sample.avgHeartRate - predicted)
            }
            return abs(sumResiduals) < 1e-6
        }
    }

    // Feature: hr-trend-regression, Property 11: Invariancia ante desplazamiento vertical
    /// **Validates: Requirements 10.4**
    @Test func property11_verticalShiftInvariance() {
        property("adding K to all avgHeartRate shifts intercept by K, slope unchanged") <- forAll(
            Gen<UInt>.fromElements(in: 2...20),
            Gen<Double>.fromElements(in: -50...50)
        ) { count, k in
            let baseDate = Date(timeIntervalSince1970: 1_000_000)
            let baseSamples = (0..<Int(count)).map { i in
                let hr = PhysiologicalSample.arbitrary.generate.avgHeartRate
                return makeSample(avgHeartRate: hr, windowStart: baseDate.addingTimeInterval(Double(i) * 3600))
            }
            let shiftedSamples = baseSamples.map { sample in
                makeSample(avgHeartRate: sample.avgHeartRate + k, windowStart: sample.windowStart)
            }
            guard let original = PatientDetailViewModel.computeRegression(from: baseSamples),
                  let shifted = PatientDetailViewModel.computeRegression(from: shiftedSamples) else {
                return true // nil results are acceptable edge cases
            }
            let slopeUnchanged = abs(shifted.slope - original.slope) < 1e-6
            let interceptShifted = abs(shifted.intercept - (original.intercept + k)) < 1e-6
            return slopeUnchanged && interceptShifted
        }
    }
}

// MARK: - Unit Tests

struct RegressionComputationUnitTests {

    @Test func knownRegression_perfectLine() {
        // y = 2x + 1 using timestamps 0, 1, 2 seconds since epoch
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 1)
        let t2 = Date(timeIntervalSince1970: 2)
        let samples = [
            makeSample(avgHeartRate: 1, windowStart: t0),
            makeSample(avgHeartRate: 3, windowStart: t1),
            makeSample(avgHeartRate: 5, windowStart: t2)
        ]
        let result = PatientDetailViewModel.computeRegression(from: samples)
        #expect(result != nil)
        #expect(abs(result!.slope - 2.0) < 1e-6)
        #expect(abs(result!.intercept - 1.0) < 1e-6)
    }

    @Test func slopePerWeek_equalsSlope_times_604800() {
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 1)
        let t2 = Date(timeIntervalSince1970: 2)
        let samples = [
            makeSample(avgHeartRate: 1, windowStart: t0),
            makeSample(avgHeartRate: 3, windowStart: t1),
            makeSample(avgHeartRate: 5, windowStart: t2)
        ]
        let result = PatientDetailViewModel.computeRegression(from: samples)!
        #expect(abs(result.slopePerWeek - result.slope * 604_800) < 1e-6)
    }

    @Test func regressionNil_emptyArray() {
        let result = PatientDetailViewModel.computeRegression(from: [])
        #expect(result == nil)
    }

    @Test func regressionNil_singleSample() {
        let sample = makeSample(avgHeartRate: 72.0)
        let result = PatientDetailViewModel.computeRegression(from: [sample])
        #expect(result == nil)
    }

    @Test func regressionNil_identicalTimestamps() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let samples = [
            makeSample(avgHeartRate: 60, windowStart: date),
            makeSample(avgHeartRate: 80, windowStart: date),
            makeSample(avgHeartRate: 70, windowStart: date)
        ]
        let result = PatientDetailViewModel.computeRegression(from: samples)
        #expect(result == nil)
    }
}
