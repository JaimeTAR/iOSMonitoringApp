//
//  SampleAggregationTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 10: Sample aggregate computation
//  Validates: Requirements 8.1, 8.2, 8.3, 8.4, 9.3, 10.2
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Generators

private func genSamples(count: UInt) -> Gen<[PhysiologicalSample]> {
    Gen<[PhysiologicalSample]>.compose { composer in
        (0..<count).map { i in
            let hr: Double = Double(composer.generate(using: Gen<UInt>.fromElements(in: 50...120)))
            let hasRMSSD: Bool = composer.generate()
            let hasSDNN: Bool = composer.generate()
            let rmssd: Double? = hasRMSSD ? Double(composer.generate(using: Gen<UInt>.fromElements(in: 10...100))) : nil
            let sdnn: Double? = hasSDNN ? Double(composer.generate(using: Gen<UInt>.fromElements(in: 10...100))) : nil
            let date = Calendar.current.date(byAdding: .minute, value: -Int(i), to: Date())!
            return PhysiologicalSample(
                userId: UUID(),
                windowStart: date,
                avgHeartRate: hr,
                rmssd: rmssd,
                sdnn: sdnn,
                sampleCount: 60
            )
        }
    }
}

// MARK: - Property Tests

struct SampleAggregationTests {

    // Feature: cardiologist-views, Property 10: Sample aggregate computation

    @Test func avgHeartRate_isArithmeticMean() {
        property("avgHR equals arithmetic mean of all avgHeartRate values") <- forAll(
            Gen<UInt>.fromElements(in: 1...20)
        ) { count in
            return forAll(genSamples(count: count)) { samples in
                let result = ClinicianService.computeAggregates(from: samples)
                let expected = samples.map(\.avgHeartRate).reduce(0, +) / Double(samples.count)
                return abs(result.avgHR - expected) < 0.001
            }
        }
    }

    @Test func avgRMSSD_isArithmeticMeanOfNonNil() {
        property("avgRMSSD equals arithmetic mean of non-nil rmssd values") <- forAll(
            Gen<UInt>.fromElements(in: 1...20)
        ) { count in
            return forAll(genSamples(count: count)) { samples in
                let result = ClinicianService.computeAggregates(from: samples)
                let rmssdValues = samples.compactMap(\.rmssd)
                if rmssdValues.isEmpty {
                    return result.avgRMSSD == nil
                } else {
                    let expected = rmssdValues.reduce(0, +) / Double(rmssdValues.count)
                    return result.avgRMSSD != nil && abs(result.avgRMSSD! - expected) < 0.001
                }
            }
        }
    }

    @Test func avgSDNN_isArithmeticMeanOfNonNil() {
        property("avgSDNN equals arithmetic mean of non-nil sdnn values") <- forAll(
            Gen<UInt>.fromElements(in: 1...20)
        ) { count in
            return forAll(genSamples(count: count)) { samples in
                let result = ClinicianService.computeAggregates(from: samples)
                let sdnnValues = samples.compactMap(\.sdnn)
                if sdnnValues.isEmpty {
                    return result.avgSDNN == nil
                } else {
                    let expected = sdnnValues.reduce(0, +) / Double(sdnnValues.count)
                    return result.avgSDNN != nil && abs(result.avgSDNN! - expected) < 0.001
                }
            }
        }
    }

    @Test func totalMinutes_equalsSampleCount() {
        property("totalMinutes equals the number of samples") <- forAll(
            Gen<UInt>.fromElements(in: 1...20)
        ) { count in
            return forAll(genSamples(count: count)) { samples in
                let result = ClinicianService.computeAggregates(from: samples)
                return result.totalMinutes == samples.count
            }
        }
    }

    // MARK: - Edge Cases

    @Test func emptySamples_returnsZeroAndNil() {
        let result = ClinicianService.computeAggregates(from: [])
        #expect(result.avgHR == 0)
        #expect(result.avgRMSSD == nil)
        #expect(result.avgSDNN == nil)
        #expect(result.totalMinutes == 0)
    }

    @Test func allNilRMSSD_returnsNil() {
        let samples = (0..<5).map { i in
            PhysiologicalSample(
                userId: UUID(),
                windowStart: Calendar.current.date(byAdding: .minute, value: -i, to: Date())!,
                avgHeartRate: 72.0,
                rmssd: nil,
                sdnn: nil,
                sampleCount: 60
            )
        }
        let result = ClinicianService.computeAggregates(from: samples)
        #expect(result.avgRMSSD == nil)
        #expect(result.avgSDNN == nil)
        #expect(result.totalMinutes == 5)
    }
}
