//
//  TrendComputationTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 6: Trend indicator computation
//  Validates: Requirements 6.3
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Test Helpers

private func makeSample(
    avgHeartRate: Double,
    rmssd: Double? = 40.0
) -> PhysiologicalSample {
    PhysiologicalSample(
        userId: UUID(),
        windowStart: Date(),
        avgHeartRate: avgHeartRate,
        rmssd: rmssd,
        sdnn: 50.0,
        sampleCount: 60
    )
}

private func makeSamples(count: Int, avgHR: Double, rmssd: Double?) -> [PhysiologicalSample] {
    (0..<count).map { _ in makeSample(avgHeartRate: avgHR, rmssd: rmssd) }
}

// MARK: - Property Tests

struct TrendComputationTests {

    // Feature: cardiologist-views, Property 6: Trend indicator computation

    @Test func emptyRecent_returnsStable() {
        property("empty recent window defaults to stable") <- forAll(
            Gen<UInt>.fromElements(in: 0...5)
        ) { priorCount in
            let prior = makeSamples(count: Int(priorCount), avgHR: 72.0, rmssd: 40.0)
            let trend = ClinicianService.computeTrend(recent: [], prior: prior)
            return trend == .stable
        }
    }

    @Test func emptyPrior_returnsStable() {
        property("empty prior window defaults to stable") <- forAll(
            Gen<UInt>.fromElements(in: 0...5)
        ) { recentCount in
            let recent = makeSamples(count: Int(recentCount), avgHR: 72.0, rmssd: 40.0)
            let trend = ClinicianService.computeTrend(recent: recent, prior: [])
            return trend == .stable
        }
    }

    @Test func hrDecrease5Percent_improving() {
        // HR decreased by ≥5% → improving
        property("HR decrease ≥5% classifies as improving") <- forAll(
            Gen<Double>.fromElements(in: 60...100),
            Gen<Double>.fromElements(in: 5...30)
        ) { priorHR, percentDecrease in
            let recentHR = priorHR * (1.0 - percentDecrease / 100.0)
            let recent = makeSamples(count: 3, avgHR: recentHR, rmssd: 40.0)
            let prior = makeSamples(count: 3, avgHR: priorHR, rmssd: 40.0)
            let trend = ClinicianService.computeTrend(recent: recent, prior: prior)
            return trend == .improving
        }
    }

    @Test func rmssdIncrease10Percent_improving() {
        // RMSSD increased by ≥10% → improving
        property("RMSSD increase ≥10% classifies as improving") <- forAll(
            Gen<Double>.fromElements(in: 20...60),
            Gen<Double>.fromElements(in: 10...50)
        ) { priorRMSSD, percentIncrease in
            let recentRMSSD = priorRMSSD * (1.0 + percentIncrease / 100.0)
            // Keep HR stable so only RMSSD drives the classification
            let recent = makeSamples(count: 3, avgHR: 72.0, rmssd: recentRMSSD)
            let prior = makeSamples(count: 3, avgHR: 72.0, rmssd: priorRMSSD)
            let trend = ClinicianService.computeTrend(recent: recent, prior: prior)
            return trend == .improving
        }
    }

    @Test func hrIncrease10Percent_declining() {
        // HR increased by ≥10% → declining
        property("HR increase ≥10% classifies as declining") <- forAll(
            Gen<Double>.fromElements(in: 60...100),
            Gen<Double>.fromElements(in: 10...40)
        ) { priorHR, percentIncrease in
            let recentHR = priorHR * (1.0 + percentIncrease / 100.0)
            let recent = makeSamples(count: 3, avgHR: recentHR, rmssd: 40.0)
            let prior = makeSamples(count: 3, avgHR: priorHR, rmssd: 40.0)
            let trend = ClinicianService.computeTrend(recent: recent, prior: prior)
            return trend == .declining
        }
    }

    @Test func rmssdDecrease15Percent_declining() {
        // RMSSD decreased by ≥15% → declining
        property("RMSSD decrease ≥15% classifies as declining") <- forAll(
            Gen<Double>.fromElements(in: 30...80),
            Gen<Double>.fromElements(in: 15...50)
        ) { priorRMSSD, percentDecrease in
            let recentRMSSD = priorRMSSD * (1.0 - percentDecrease / 100.0)
            // Keep HR stable so only RMSSD drives the classification
            let recent = makeSamples(count: 3, avgHR: 72.0, rmssd: recentRMSSD)
            let prior = makeSamples(count: 3, avgHR: 72.0, rmssd: priorRMSSD)
            let trend = ClinicianService.computeTrend(recent: recent, prior: prior)
            return trend == .declining
        }
    }

    @Test func stableValues_stable() {
        // Small changes in both HR and RMSSD → stable
        property("small changes classify as stable") <- forAll(
            Gen<Double>.fromElements(in: 60...100),
            Gen<Double>.fromElements(in: 30...60),
            Gen<Double>.fromElements(in: -4...4),
            Gen<Double>.fromElements(in: -9...9)
        ) { priorHR, priorRMSSD, hrChangePercent, rmssdChangePercent in
            let recentHR = priorHR * (1.0 + hrChangePercent / 100.0)
            let recentRMSSD = priorRMSSD * (1.0 + rmssdChangePercent / 100.0)
            let recent = makeSamples(count: 3, avgHR: recentHR, rmssd: recentRMSSD)
            let prior = makeSamples(count: 3, avgHR: priorHR, rmssd: priorRMSSD)
            let trend = ClinicianService.computeTrend(recent: recent, prior: prior)
            return trend == .stable
        }
    }

    @Test func nilRMSSD_onlyHRDrivesTrend() {
        // When RMSSD is nil, only HR determines trend
        let recent = makeSamples(count: 3, avgHR: 60.0, rmssd: nil)
        let prior = makeSamples(count: 3, avgHR: 72.0, rmssd: nil)
        let trend = ClinicianService.computeTrend(recent: recent, prior: prior)
        // HR decreased ~16.7% → improving
        #expect(trend == .improving)
    }
}
