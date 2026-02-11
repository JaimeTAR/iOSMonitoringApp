//
//  TrendDisplayTests.swift
//  MonitoringAppTests
//
//  Property tests (P12–P13) and unit tests for prediction and slope display formatting.
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

struct TrendDisplayPropertyTests {

    // Feature: hr-trend-regression, Property 12: Función de predicción correcta
    /// **Validates: Requirements 3.2, 11.3**
    @Test func property12_predictValueIsCorrect() {
        let regGen = Gen<(Double, Double, Double, Double, Double)>.zip(
            Gen<Double>.fromElements(in: -0.01...0.01),
            Gen<Double>.fromElements(in: 40...120),
            Gen<Double>.fromElements(in: 1_000_000...1_500_000),
            Gen<Double>.fromElements(in: 86400...604800),
            Gen<Double>.fromElements(in: 1_000_000...2_000_000)
        )
        property("predictValue equals slope * t + intercept") <- forAll(regGen) { tuple in
            let (slope, intercept, startEpoch, duration, queryEpoch) = tuple
            let regression = RegressionResult(
                slope: slope,
                intercept: intercept,
                startDate: Date(timeIntervalSince1970: startEpoch),
                endDate: Date(timeIntervalSince1970: startEpoch + duration)
            )
            let queryDate = Date(timeIntervalSince1970: queryEpoch)
            let predicted = PatientDetailViewModel.predictValue(at: queryDate, using: regression)
            let expected = slope * queryDate.timeIntervalSince1970 + intercept
            return abs(predicted - expected) < 1e-6
        }
    }

    // Feature: hr-trend-regression, Property 13: Texto de indicador de pendiente
    /// **Validates: Requirements 2.3, 7.2, 7.3, 7.4**
    @Test func property13_slopeDisplayText() {
        // Generate slopePerWeek and derive slope = slopePerWeek / 604800
        let spwGen = Gen<Double>.fromElements(in: -10...10)
        property("slopeDisplayText returns correct text based on slopePerWeek") <- forAll(spwGen) { slopePerWeek in
            let slope = slopePerWeek / 604_800.0
            let regression = RegressionResult(
                slope: slope,
                intercept: 70.0,
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400)
            )
            let text = PatientDetailViewModel.slopeDisplayText(regression)
            if abs(slopePerWeek) < 0.5 {
                return text == "Anomalías estables"
            } else if slopePerWeek >= 0.5 {
                let expected = String(format: "Anomalías \u{2191}%.1f BPM/sem", slopePerWeek)
                return text == expected
            } else {
                let expected = String(format: "Anomalías \u{2193}%.1f BPM/sem", abs(slopePerWeek))
                return text == expected
            }
        }
    }

    @Test func property13_nilReturns_sinAnomalias() {
        let text = PatientDetailViewModel.slopeDisplayText(nil)
        #expect(text == "Sin anomalías")
    }

    // Feature: hr-trend-regression, Property 14: Ordenamiento descendente de outliers
    /// **Validates: Requirements 6.4**
    @Test func property14_outlierDescendingSort() {
        property("outliers sorted by windowStart descending have monotonically decreasing dates") <- forAll(
            PhysiologicalSample.arbitrary.proliferate
        ) { samples in
            let result = PatientDetailViewModel.detectOutliers(from: samples)
            let sortedOutliers = result.outliers.sorted { $0.windowStart > $1.windowStart }
            return zip(sortedOutliers, sortedOutliers.dropFirst()).allSatisfy {
                $0.windowStart >= $1.windowStart
            }
        }
    }
}

// MARK: - Unit Tests

struct TrendDisplayUnitTests {

    @Test func formatPositiveSlope() {
        let slope = 2.3 / 604_800.0
        let reg = RegressionResult(slope: slope, intercept: 70, startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let text = PatientDetailViewModel.slopeDisplayText(reg)
        #expect(text == "Anomalías \u{2191}2.3 BPM/sem")
    }

    @Test func formatNegativeSlope() {
        let slope = -1.1 / 604_800.0
        let reg = RegressionResult(slope: slope, intercept: 70, startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let text = PatientDetailViewModel.slopeDisplayText(reg)
        #expect(text == "Anomalías \u{2193}1.1 BPM/sem")
    }

    @Test func formatStableSlope() {
        let slope = 0.3 / 604_800.0
        let reg = RegressionResult(slope: slope, intercept: 70, startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let text = PatientDetailViewModel.slopeDisplayText(reg)
        #expect(text == "Anomalías estables")
    }

    @Test func formatNilRegression() {
        let text = PatientDetailViewModel.slopeDisplayText(nil)
        #expect(text == "Sin anomalías")
    }

    @Test func predictValue_matchesFormula() {
        let reg = RegressionResult(slope: 0.001, intercept: 60.0, startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let queryDate = Date(timeIntervalSince1970: 1_500_000)
        let predicted = PatientDetailViewModel.predictValue(at: queryDate, using: reg)
        let expected = 0.001 * 1_500_000 + 60.0
        #expect(abs(predicted - expected) < 1e-6)
    }
}
