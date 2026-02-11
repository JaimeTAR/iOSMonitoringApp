//
//  SessionGroupingTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 11: Session grouping from samples
//  Validates: Requirements 9.1
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Generators

/// Generates sorted samples with random gaps between them
private func genSortedSamples(count: UInt) -> Gen<[PhysiologicalSample]> {
    Gen<[PhysiologicalSample]>.compose { composer in
        let userId = UUID()
        var date = Date()
        return (0..<count).map { _ in
            let gapSeconds: UInt = composer.generate(using: Gen<UInt>.fromElements(in: 30...300))
            date = date.addingTimeInterval(Double(gapSeconds))
            return PhysiologicalSample(
                userId: userId,
                windowStart: date,
                avgHeartRate: 72.0,
                rmssd: 40.0,
                sdnn: 50.0,
                sampleCount: 60
            )
        }
    }
}

// MARK: - Property Tests

struct SessionGroupingTests {

    // Feature: cardiologist-views, Property 11: Session grouping from samples

    @Test func everySample_belongsToExactlyOneSession() {
        property("every sample belongs to exactly one session") <- forAll(
            Gen<UInt>.fromElements(in: 1...30)
        ) { count in
            return forAll(genSortedSamples(count: count)) { samples in
                let sessions = ClinicianService.groupIntoSessions(samples)
                let totalInSessions = sessions.reduce(0) { $0 + $1.count }
                return totalInSessions == samples.count
            }
        }
    }

    @Test func consecutiveSamplesWithin2Min_sameSession() {
        property("consecutive samples ≤2 min apart are in the same session") <- forAll(
            Gen<UInt>.fromElements(in: 2...20)
        ) { count in
            return forAll(genSortedSamples(count: count)) { samples in
                let sessions = ClinicianService.groupIntoSessions(samples)

                // Build a map from sample ID to session index
                var sampleToSession: [UUID: Int] = [:]
                for (sessionIdx, session) in sessions.enumerated() {
                    for sample in session {
                        sampleToSession[sample.id] = sessionIdx
                    }
                }

                // Check consecutive pairs
                for i in 0..<(samples.count - 1) {
                    let gap = samples[i + 1].windowStart.timeIntervalSince(samples[i].windowStart)
                    if gap <= 120 {
                        if sampleToSession[samples[i].id] != sampleToSession[samples[i + 1].id] {
                            return false
                        }
                    }
                }
                return true
            }
        }
    }

    @Test func samplesMoreThan2MinApart_differentSessions() {
        property("consecutive samples >2 min apart start new sessions") <- forAll(
            Gen<UInt>.fromElements(in: 2...20)
        ) { count in
            return forAll(genSortedSamples(count: count)) { samples in
                let sessions = ClinicianService.groupIntoSessions(samples)

                var sampleToSession: [UUID: Int] = [:]
                for (sessionIdx, session) in sessions.enumerated() {
                    for sample in session {
                        sampleToSession[sample.id] = sessionIdx
                    }
                }

                for i in 0..<(samples.count - 1) {
                    let gap = samples[i + 1].windowStart.timeIntervalSince(samples[i].windowStart)
                    if gap > 120 {
                        if sampleToSession[samples[i].id] == sampleToSession[samples[i + 1].id] {
                            return false
                        }
                    }
                }
                return true
            }
        }
    }

    @Test func sessionOrder_preservesSampleOrder() {
        property("sessions preserve the original sample ordering") <- forAll(
            Gen<UInt>.fromElements(in: 1...20)
        ) { count in
            return forAll(genSortedSamples(count: count)) { samples in
                let sessions = ClinicianService.groupIntoSessions(samples)
                let flattened = sessions.flatMap { $0 }
                // Flattened sessions should have the same order as input
                for (i, sample) in flattened.enumerated() {
                    if sample.id != samples[i].id {
                        return false
                    }
                }
                return true
            }
        }
    }

    // MARK: - Edge Cases

    @Test func emptySamples_returnsEmpty() {
        let sessions = ClinicianService.groupIntoSessions([])
        #expect(sessions.isEmpty)
    }

    @Test func singleSample_oneSession() {
        let sample = PhysiologicalSample(
            userId: UUID(),
            windowStart: Date(),
            avgHeartRate: 72.0,
            rmssd: 40.0,
            sdnn: 50.0,
            sampleCount: 60
        )
        let sessions = ClinicianService.groupIntoSessions([sample])
        #expect(sessions.count == 1)
        #expect(sessions.first?.count == 1)
    }

    @Test func allWithin2Min_oneSession() {
        let userId = UUID()
        let base = Date()
        let samples = (0..<5).map { i in
            PhysiologicalSample(
                userId: userId,
                windowStart: base.addingTimeInterval(Double(i) * 60),
                avgHeartRate: 72.0,
                rmssd: 40.0,
                sdnn: 50.0,
                sampleCount: 60
            )
        }
        let sessions = ClinicianService.groupIntoSessions(samples)
        #expect(sessions.count == 1)
        #expect(sessions.first?.count == 5)
    }

    @Test func allFarApart_eachOwnSession() {
        let userId = UUID()
        let base = Date()
        let samples = (0..<4).map { i in
            PhysiologicalSample(
                userId: userId,
                windowStart: base.addingTimeInterval(Double(i) * 300), // 5 min gaps
                avgHeartRate: 72.0,
                rmssd: 40.0,
                sdnn: 50.0,
                sampleCount: 60
            )
        }
        let sessions = ClinicianService.groupIntoSessions(samples)
        #expect(sessions.count == 4)
    }
}
