//
//  RecentActivityTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 4: Recent activity feed selection
//  Validates: Requirements 5.1
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Arbitrary Conformance

extension RecentActivityItem: @retroactive Arbitrary {
    public static var arbitrary: Gen<RecentActivityItem> {
        Gen<RecentActivityItem>.compose { composer in
            let hoursAgo: UInt = composer.generate(using: Gen<UInt>.fromElements(in: 0...720))
            let date = Calendar.current.date(byAdding: .hour, value: -Int(hoursAgo), to: Date())!
            return RecentActivityItem(
                id: UUID(),
                patientId: UUID(),
                patientName: "Patient",
                sessionDate: date,
                durationMinutes: Int(composer.generate(using: Gen<UInt>.fromElements(in: 1...60))),
                avgHeartRate: 72.0
            )
        }
    }
}

// MARK: - Generators

private func genActivityItems(count: UInt) -> Gen<[RecentActivityItem]> {
    Gen<[RecentActivityItem]>.compose { composer in
        (0..<count).map { _ in
            let hoursAgo: UInt = composer.generate(using: Gen<UInt>.fromElements(in: 0...720))
            let date = Calendar.current.date(byAdding: .hour, value: -Int(hoursAgo), to: Date())!
            return RecentActivityItem(
                id: UUID(),
                patientId: UUID(),
                patientName: "Patient",
                sessionDate: date,
                durationMinutes: Int(composer.generate(using: Gen<UInt>.fromElements(in: 1...60))),
                avgHeartRate: 72.0
            )
        }
    }
}

// MARK: - Property Tests

struct RecentActivityTests {

    // Feature: cardiologist-views, Property 4: Recent activity feed selection

    @Test func recentActivity_atMost10Items() {
        property("recent activity feed contains at most 10 items") <- forAll(
            Gen<UInt>.fromElements(in: 0...25)
        ) { count in
            return forAll(genActivityItems(count: count)) { items in
                let result = ClinicianService.selectRecentActivity(items, limit: 10)
                return result.count <= 10
            }
        }
    }

    @Test func recentActivity_descendingDateOrder() {
        property("recent activity feed is in descending date order") <- forAll(
            Gen<UInt>.fromElements(in: 0...25)
        ) { count in
            return forAll(genActivityItems(count: count)) { items in
                let result = ClinicianService.selectRecentActivity(items, limit: 10)
                guard result.count >= 2 else { return true }
                for i in 0..<(result.count - 1) {
                    if result[i].sessionDate < result[i + 1].sessionDate {
                        return false
                    }
                }
                return true
            }
        }
    }

    @Test func recentActivity_containsMostRecentSessions() {
        property("recent activity feed contains the most recent sessions") <- forAll(
            Gen<UInt>.fromElements(in: 11...25)
        ) { count in
            return forAll(genActivityItems(count: count)) { items in
                let result = ClinicianService.selectRecentActivity(items, limit: 10)
                let sortedAll = items.sorted { $0.sessionDate > $1.sessionDate }
                let top10Dates = sortedAll.prefix(10).map { $0.sessionDate }
                let resultDates = result.map { $0.sessionDate }
                return Set(resultDates) == Set(top10Dates)
            }
        }
    }

    @Test func recentActivity_fewerThan10_returnsAll() {
        property("when fewer than 10 items, all are returned") <- forAll(
            Gen<UInt>.fromElements(in: 0...9)
        ) { count in
            return forAll(genActivityItems(count: count)) { items in
                let result = ClinicianService.selectRecentActivity(items, limit: 10)
                return result.count == items.count
            }
        }
    }

    // MARK: - Edge Cases

    @Test func emptyInput_returnsEmpty() {
        let result = ClinicianService.selectRecentActivity([], limit: 10)
        #expect(result.isEmpty)
    }
}
