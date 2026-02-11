//
//  PatientListFilterSortTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 7: Patient search filtering
//  Feature: cardiologist-views, Property 8: Patient list sorting
//  Validates: Requirements 6.4, 6.6
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Arbitrary Conformances

extension PatientSummary: @retroactive Arbitrary {
    public static var arbitrary: Gen<PatientSummary> {
        Gen.compose { c in
            let hasDate = c.generate(using: Gen<Bool>.pure(true))
            let hasHR = c.generate(using: Gen<Bool>.pure(true))
            let hasRMSSD = c.generate(using: Gen<Bool>.pure(true))
            let offset = c.generate(using: Gen<Double>.fromElements(in: 0...604800))
            let hr = c.generate(using: Gen<Double>.fromElements(in: 50...120))
            let rmssd = c.generate(using: Gen<Double>.fromElements(in: 10...80))
            return PatientSummary(
                id: UUID(),
                name: c.generate(using: Gen<String>.fromElements(of: [
                    "Alice", "Bob", "Charlie", "Diana", "Eve", "Frank",
                    "Grace", "Hank", "Iris", "Jack", "Karen", "Leo"
                ])),
                lastActiveDate: hasDate ? Date().addingTimeInterval(-offset) : nil,
                avgHeartRate7d: hasHR ? hr : nil,
                avgRMSSD7d: hasRMSSD ? rmssd : nil,
                trend: [HealthTrend.improving, .stable, .declining].randomElement()!
            )
        }
    }
}

// MARK: - Generators

private let nameGen = Gen<String>.fromElements(of: [
    "Alice", "Bob", "Charlie", "Diana", "Eve", "Frank",
    "Grace", "Hank", "Iris", "Jack", "Karen", "Leo",
    "Maria", "Nick", "Olivia", "Paul"
])

private let searchGen = Gen<String>.fromElements(of: [
    "", "a", "al", "Ali", "bob", "CH", "eve", "Z", "an", "ar", "ack", "ia"
])

private func makePatient(name: String) -> PatientSummary {
    PatientSummary(
        id: UUID(),
        name: name,
        lastActiveDate: Date(),
        avgHeartRate7d: 72.0,
        avgRMSSD7d: 40.0,
        trend: .stable
    )
}

// MARK: - Property 7: Patient search filtering

struct PatientSearchFilteringTests {

    // Feature: cardiologist-views, Property 7: Patient search filtering

    @Test func filteredListIsSubsetOfOriginal() {
        property("filtered list is always a subset of the original") <- forAll(searchGen) { query in
            let patients = (0..<5).map { _ in makePatient(name: nameGen.generate) }
            let filtered = PatientListViewModel.filterPatients(patients, searchText: query)
            return filtered.allSatisfy { item in patients.contains(where: { $0.id == item.id }) }
        }
    }

    @Test func filteredListMatchesCaseInsensitive() {
        property("every filtered patient name contains the query (case-insensitive)") <- forAll(searchGen) { query in
            let patients = (0..<8).map { _ in makePatient(name: nameGen.generate) }
            let filtered = PatientListViewModel.filterPatients(patients, searchText: query)
            if query.isEmpty {
                return filtered.count == patients.count
            }
            let lowerQuery = query.lowercased()
            return filtered.allSatisfy { $0.name.lowercased().contains(lowerQuery) }
        }
    }

    @Test func emptySearchReturnsAll() {
        property("empty search returns all patients") <- forAll(Gen<UInt>.fromElements(in: 0...10)) { count in
            let patients = (0..<Int(count)).map { _ in makePatient(name: nameGen.generate) }
            let filtered = PatientListViewModel.filterPatients(patients, searchText: "")
            return filtered.count == patients.count
        }
    }

    @Test func noMatchReturnsEmpty() {
        let patients = [makePatient(name: "Alice"), makePatient(name: "Bob")]
        let filtered = PatientListViewModel.filterPatients(patients, searchText: "ZZZZZ")
        #expect(filtered.isEmpty)
    }
}


// MARK: - Property 8: Patient list sorting

struct PatientListSortingTests {

    // Feature: cardiologist-views, Property 8: Patient list sorting

    @Test func sortByNameIsAlphabetical() {
        property("sort by name produces alphabetical order") <- forAll(Gen<UInt>.fromElements(in: 0...10)) { count in
            let patients = (0..<Int(count)).map { _ in makePatient(name: nameGen.generate) }
            let sorted = PatientListViewModel.sortPatients(patients, by: .name)
            guard sorted.count > 1 else { return true }
            return zip(sorted, sorted.dropFirst()).allSatisfy {
                $0.0.name.localizedCaseInsensitiveCompare($0.1.name) != .orderedDescending
            }
        }
    }

    @Test func sortByLastActiveIsDescending() {
        property("sort by last active produces most-recent-first order") <- forAll(Gen<UInt>.fromElements(in: 0...10)) { count in
            let patients: [PatientSummary] = (0..<Int(count)).map { i in
                PatientSummary(
                    id: UUID(),
                    name: "P\(i)",
                    lastActiveDate: Bool.random() ? Date().addingTimeInterval(-Double.random(in: 0...604800)) : nil,
                    avgHeartRate7d: 72.0,
                    avgRMSSD7d: 40.0,
                    trend: .stable
                )
            }
            let sorted = PatientListViewModel.sortPatients(patients, by: .lastActive)
            guard sorted.count > 1 else { return true }
            return zip(sorted, sorted.dropFirst()).allSatisfy {
                ($0.0.lastActiveDate ?? .distantPast) >= ($0.1.lastActiveDate ?? .distantPast)
            }
        }
    }

    @Test func sortByAvgHeartRateIsAscending() {
        property("sort by avg HR produces ascending order") <- forAll(Gen<UInt>.fromElements(in: 0...10)) { count in
            let patients: [PatientSummary] = (0..<Int(count)).map { i in
                PatientSummary(
                    id: UUID(),
                    name: "P\(i)",
                    lastActiveDate: Date(),
                    avgHeartRate7d: Bool.random() ? Double.random(in: 50...120) : nil,
                    avgRMSSD7d: 40.0,
                    trend: .stable
                )
            }
            let sorted = PatientListViewModel.sortPatients(patients, by: .avgHeartRate)
            guard sorted.count > 1 else { return true }
            return zip(sorted, sorted.dropFirst()).allSatisfy {
                ($0.0.avgHeartRate7d ?? Double.greatestFiniteMagnitude) <= ($0.1.avgHeartRate7d ?? Double.greatestFiniteMagnitude)
            }
        }
    }

    @Test func sortPreservesAllElements() {
        property("sorting preserves all elements") <- forAll(Gen<UInt>.fromElements(in: 0...10)) { count in
            let patients = (0..<Int(count)).map { _ in makePatient(name: nameGen.generate) }
            let options: [PatientSortOption] = [.name, .lastActive, .avgHeartRate]
            let option = options.randomElement()!
            let sorted = PatientListViewModel.sortPatients(patients, by: option)
            let originalIds = Set(patients.map(\.id))
            let sortedIds = Set(sorted.map(\.id))
            return originalIds == sortedIds
        }
    }
}
