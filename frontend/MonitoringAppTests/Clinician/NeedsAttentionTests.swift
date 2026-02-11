//
//  NeedsAttentionTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 3: Needs-attention classification
//  Validates: Requirements 4.1, 4.2, 4.3
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Test Helpers

private func makeProfile(
    userId: UUID,
    restingHeartRate: Double? = 70.0
) -> UserProfile {
    UserProfile(
        id: UUID(),
        userId: userId,
        role: .patient,
        name: "Patient",
        age: 30,
        sex: nil,
        heightCm: nil,
        weightKg: nil,
        exerciseFrequency: nil,
        activityLevel: nil,
        restingHeartRate: restingHeartRate,
        createdAt: Date(),
        updatedAt: Date()
    )
}

private func makeSample(
    userId: UUID,
    windowStart: Date,
    avgHeartRate: Double = 72.0,
    rmssd: Double? = 40.0
) -> PhysiologicalSample {
    PhysiologicalSample(
        userId: userId,
        windowStart: windowStart,
        avgHeartRate: avgHeartRate,
        rmssd: rmssd,
        sdnn: 50.0,
        sampleCount: 60
    )
}

// MARK: - Property Tests

struct NeedsAttentionTests {

    // Feature: cardiologist-views, Property 3: Needs-attention classification

    @Test func inactivePatient_flaggedForInactivity() {
        // Patient with no samples in last 7 days should be flagged
        property("patients with no recent samples are flagged for inactivity") <- forAll(
            Gen<UInt>.fromElements(in: 8...30)
        ) { daysSinceLastSample in
            let now = Date()
            let patientId = UUID()
            let profile = makeProfile(userId: patientId)
            let oldSampleDate = Calendar.current.date(byAdding: .day, value: -Int(daysSinceLastSample), to: now)!

            let items = ClinicianService.classifyNeedsAttention(
                patientIds: [patientId],
                profiles: [patientId: profile],
                samplesByPatient: [patientId: [makeSample(userId: patientId, windowStart: oldSampleDate)]],
                now: now
            )

            let inactivityItems = items.filter { $0.reason == .inactivity && $0.id == patientId }
            return inactivityItems.count == 1
        }
    }

    @Test func activePatient_notFlaggedForInactivity() {
        // Patient with samples in last 7 days should NOT be flagged for inactivity
        property("patients with recent samples are not flagged for inactivity") <- forAll(
            Gen<UInt>.fromElements(in: 0...6)
        ) { daysAgo in
            let now = Date()
            let patientId = UUID()
            let profile = makeProfile(userId: patientId)
            let recentDate = Calendar.current.date(byAdding: .day, value: -Int(daysAgo), to: now)!

            let items = ClinicianService.classifyNeedsAttention(
                patientIds: [patientId],
                profiles: [patientId: profile],
                samplesByPatient: [patientId: [makeSample(userId: patientId, windowStart: recentDate)]],
                now: now
            )

            let inactivityItems = items.filter { $0.reason == .inactivity && $0.id == patientId }
            return inactivityItems.count == 0
        }
    }

    @Test func elevatedHR_flaggedWhenAboveBaseline15Percent() {
        // Patient whose 7d avg HR exceeds baseline by ≥15% should be flagged
        property("patients with HR ≥15% above baseline are flagged for elevated HR") <- forAll(
            Gen<Double>.fromElements(in: 50...90),
            Gen<Double>.fromElements(in: 15...50)
        ) { baseline, percentAbove in
            let now = Date()
            let patientId = UUID()
            let profile = makeProfile(userId: patientId, restingHeartRate: baseline)
            let elevatedHR = baseline * (1.0 + percentAbove / 100.0)
            let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!

            let items = ClinicianService.classifyNeedsAttention(
                patientIds: [patientId],
                profiles: [patientId: profile],
                samplesByPatient: [patientId: [makeSample(userId: patientId, windowStart: recentDate, avgHeartRate: elevatedHR)]],
                now: now
            )

            let hrItems = items.filter { $0.reason == .elevatedHeartRate && $0.id == patientId }
            return hrItems.count == 1
        }
    }

    @Test func normalHR_notFlaggedForElevation() {
        // Patient whose 7d avg HR is below 15% above baseline should NOT be flagged
        property("patients with HR <15% above baseline are not flagged") <- forAll(
            Gen<Double>.fromElements(in: 50...90),
            Gen<Double>.fromElements(in: 0...14)
        ) { baseline, percentAbove in
            let now = Date()
            let patientId = UUID()
            let profile = makeProfile(userId: patientId, restingHeartRate: baseline)
            let normalHR = baseline * (1.0 + percentAbove / 100.0)
            let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!

            let items = ClinicianService.classifyNeedsAttention(
                patientIds: [patientId],
                profiles: [patientId: profile],
                samplesByPatient: [patientId: [makeSample(userId: patientId, windowStart: recentDate, avgHeartRate: normalHR)]],
                now: now
            )

            let hrItems = items.filter { $0.reason == .elevatedHeartRate && $0.id == patientId }
            return hrItems.count == 0
        }
    }

    @Test func decliningHRV_flaggedWhenRMSSDDrops25Percent() {
        // Patient whose 7d avg RMSSD declined ≥25% vs prior 7d should be flagged
        property("patients with RMSSD decline ≥25% are flagged for declining HRV") <- forAll(
            Gen<Double>.fromElements(in: 30...80),
            Gen<Double>.fromElements(in: 25...70)
        ) { priorRMSSD, percentDecline in
            let now = Date()
            let patientId = UUID()
            let profile = makeProfile(userId: patientId)
            let recentRMSSD = priorRMSSD * (1.0 - percentDecline / 100.0)

            let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!
            let priorDate = Calendar.current.date(byAdding: .day, value: -10, to: now)!

            let samples = [
                makeSample(userId: patientId, windowStart: recentDate, rmssd: recentRMSSD),
                makeSample(userId: patientId, windowStart: priorDate, rmssd: priorRMSSD),
            ]

            let items = ClinicianService.classifyNeedsAttention(
                patientIds: [patientId],
                profiles: [patientId: profile],
                samplesByPatient: [patientId: samples],
                now: now
            )

            let hrvItems = items.filter { $0.reason == .decliningHRV && $0.id == patientId }
            return hrvItems.count == 1
        }
    }

    @Test func stableHRV_notFlaggedForDecline() {
        // Patient whose RMSSD decline is <25% should NOT be flagged
        property("patients with RMSSD decline <25% are not flagged") <- forAll(
            Gen<Double>.fromElements(in: 30...80),
            Gen<Double>.fromElements(in: 0...24)
        ) { priorRMSSD, percentDecline in
            let now = Date()
            let patientId = UUID()
            let profile = makeProfile(userId: patientId)
            let recentRMSSD = priorRMSSD * (1.0 - percentDecline / 100.0)

            let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!
            let priorDate = Calendar.current.date(byAdding: .day, value: -10, to: now)!

            let samples = [
                makeSample(userId: patientId, windowStart: recentDate, rmssd: recentRMSSD),
                makeSample(userId: patientId, windowStart: priorDate, rmssd: priorRMSSD),
            ]

            let items = ClinicianService.classifyNeedsAttention(
                patientIds: [patientId],
                profiles: [patientId: profile],
                samplesByPatient: [patientId: samples],
                now: now
            )

            let hrvItems = items.filter { $0.reason == .decliningHRV && $0.id == patientId }
            return hrvItems.count == 0
        }
    }

    @Test func healthyPatient_noFlags() {
        // Patient meeting no criteria should not appear
        let now = Date()
        let patientId = UUID()
        let profile = makeProfile(userId: patientId, restingHeartRate: 70.0)
        let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let priorDate = Calendar.current.date(byAdding: .day, value: -10, to: now)!

        let samples = [
            makeSample(userId: patientId, windowStart: recentDate, avgHeartRate: 72.0, rmssd: 40.0),
            makeSample(userId: patientId, windowStart: priorDate, avgHeartRate: 72.0, rmssd: 42.0),
        ]

        let items = ClinicianService.classifyNeedsAttention(
            patientIds: [patientId],
            profiles: [patientId: profile],
            samplesByPatient: [patientId: samples],
            now: now
        )

        #expect(items.isEmpty)
    }

    @Test func noSamplesAtAll_flaggedForInactivity() {
        let now = Date()
        let patientId = UUID()
        let profile = makeProfile(userId: patientId)

        let items = ClinicianService.classifyNeedsAttention(
            patientIds: [patientId],
            profiles: [patientId: profile],
            samplesByPatient: [:],
            now: now
        )

        #expect(items.count == 1)
        #expect(items.first?.reason == .inactivity)
    }
}
