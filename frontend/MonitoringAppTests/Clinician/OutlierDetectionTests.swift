//
//  OutlierDetectionTests.swift
//  MonitoringAppTests
//
//  Property tests (P1–P5) and unit tests for IQR-based outlier detection.
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Shared Test Helpers

extension PhysiologicalSample: @retroactive Arbitrary {
    public static var arbitrary: Gen<PhysiologicalSample> {
        Gen<Double>.fromElements(in: 30...220).map { hr in
            PhysiologicalSample(
                userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                windowStart: Date(timeIntervalSince1970: Double.random(in: 0...2_000_000_000)),
                avgHeartRate: hr,
                rmssd: 40.0,
                sdnn: 50.0,
                sampleCount: 60
            )
        }
    }
}

private func makeSample(avgHeartRate: Double, windowStart: Date = Date()) -> PhysiologicalSample {
    PhysiologicalSample(
        userId: UUID(),
        windowStart: windowStart,
        avgHeartRate: avgHeartRate,
        rmssd: 40.0,
        sdnn: 50.0,
        sampleCount: 60
    )
}

// MARK: - Property Tests

struct OutlierDetectionPropertyTests {

    // Feature: hr-trend-regression, Property 1: Clasificación IQR correcta
    /// **Validates: Requirements 1.2, 1.3, 9.1, 9.2**
    @Test func property1_iqrClassification() {
        property("every outlier is outside IQR bounds and every inlier is within") <- forAll(
            PhysiologicalSample.arbitrary.proliferate.suchThat { $0.count >= 4 }
        ) { samples in
            let result = PatientDetailViewModel.detectOutliers(from: samples)
            let hrValues = samples.map(\.avgHeartRate)
            let (q1, q3, iqr) = PatientDetailViewModel.computeIQR(hrValues)
            let lower = q1 - 1.5 * iqr
            let upper = q3 + 1.5 * iqr

            let outliersCorrect = result.outliers.allSatisfy {
                $0.avgHeartRate < lower || $0.avgHeartRate > upper
            }
            let inliersCorrect = result.inliers.allSatisfy {
                $0.avgHeartRate >= lower && $0.avgHeartRate <= upper
            }
            return outliersCorrect && inliersCorrect
        }
    }

    // Feature: hr-trend-regression, Property 2: Bypass para arreglos pequeños
    /// **Validates: Requirements 1.4, 9.5**
    @Test func property2_smallArrayBypass() {
        property("arrays with fewer than 4 elements return all as inliers") <- forAll(
            Gen<UInt>.fromElements(in: 0...3)
        ) { count in
            let samples = (0..<Int(count)).map { _ in PhysiologicalSample.arbitrary.generate }
            let result = PatientDetailViewModel.detectOutliers(from: samples)
            return result.inliers.count == samples.count && result.outliers.isEmpty
        }
    }

    // Feature: hr-trend-regression, Property 3: Preservación de orden
    /// **Validates: Requirements 1.6**
    @Test func property3_orderPreservation() {
        property("original indices in inliers and outliers are monotonically increasing") <- forAll(
            PhysiologicalSample.arbitrary.proliferate
        ) { samples in
            let result = PatientDetailViewModel.detectOutliers(from: samples)

            // Map each result sample back to its original index by id
            let idToIndex = Dictionary(uniqueKeysWithValues: samples.enumerated().map { ($1.id, $0) })

            let inlierIndices = result.inliers.compactMap { idToIndex[$0.id] }
            let outlierIndices = result.outliers.compactMap { idToIndex[$0.id] }

            let inliersOrdered = zip(inlierIndices, inlierIndices.dropFirst()).allSatisfy { $0 < $1 }
            let outliersOrdered = zip(outlierIndices, outlierIndices.dropFirst()).allSatisfy { $0 < $1 }

            return inliersOrdered && outliersOrdered
        }
    }

    // Feature: hr-trend-regression, Property 4: Partición completa
    /// **Validates: Requirements 9.3**
    @Test func property4_completePartition() {
        property("inliers.count + outliers.count == input.count") <- forAll(
            PhysiologicalSample.arbitrary.proliferate
        ) { samples in
            let result = PatientDetailViewModel.detectOutliers(from: samples)
            return result.inliers.count + result.outliers.count == samples.count
        }
    }

    // Feature: hr-trend-regression, Property 5: Valores iguales son todos inliers
    /// **Validates: Requirements 9.4**
    @Test func property5_equalValuesAllInliers() {
        property("when all avgHeartRate values are equal, outliers is empty") <- forAll(
            Gen<Double>.fromElements(in: 30...220),
            Gen<UInt>.fromElements(in: 1...20)
        ) { hr, count in
            let samples = (0..<Int(count)).map { _ in
                makeSample(avgHeartRate: hr)
            }
            let result = PatientDetailViewModel.detectOutliers(from: samples)
            return result.outliers.isEmpty && result.inliers.count == samples.count
        }
    }
}

// MARK: - Unit Tests

struct OutlierDetectionUnitTests {

    @Test func knownIQRExample_100IsOutlier() {
        // Dataset: [1, 2, 3, 4, 5, 100]
        let samples = [1.0, 2.0, 3.0, 4.0, 5.0, 100.0].map { makeSample(avgHeartRate: $0) }
        let result = PatientDetailViewModel.detectOutliers(from: samples)

        #expect(result.outliers.count == 1)
        #expect(result.outliers.first?.avgHeartRate == 100.0)
        #expect(result.inliers.count == 5)
    }

    @Test func emptyArray_bothEmpty() {
        let result = PatientDetailViewModel.detectOutliers(from: [])
        #expect(result.inliers.isEmpty)
        #expect(result.outliers.isEmpty)
    }

    @Test func singleSample_isInlier() {
        let sample = makeSample(avgHeartRate: 72.0)
        let result = PatientDetailViewModel.detectOutliers(from: [sample])

        #expect(result.inliers.count == 1)
        #expect(result.inliers.first?.id == sample.id)
        #expect(result.outliers.isEmpty)
    }
}
