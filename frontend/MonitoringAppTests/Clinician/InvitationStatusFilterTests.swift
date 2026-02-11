//
//  InvitationStatusFilterTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 13: Invitation status counter computation
//  Feature: cardiologist-views, Property 14: Invitation status filtering
//  Validates: Requirements 11.3, 11.5
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Arbitrary Conformances

extension InvitationStatus: @retroactive Arbitrary {
    public static var arbitrary: Gen<InvitationStatus> {
        Gen<InvitationStatus>.fromElements(of: InvitationStatus.allCases)
    }
}

// MARK: - Test Helpers

private func makeCode(status: InvitationStatus) -> InvitationCode {
    InvitationCode(
        id: UUID(),
        clinicianId: UUID(),
        code: "ABCDE",
        status: status,
        createdAt: Date(),
        expiresAt: Date().addingTimeInterval(604800)
    )
}

// MARK: - Property 13: Invitation status counter computation

struct InvitationStatusCounterTests {

    // Feature: cardiologist-views, Property 13: Invitation status counter computation

    @Test func countersSumToTotalMinusRevoked() {
        property("pending + used + expired + revoked equals total code count") <- forAll(
            Gen<UInt>.fromElements(in: 0...20)
        ) { count in
            let statuses: [InvitationStatus] = (0..<Int(count)).map { _ in
                InvitationStatus.allCases.randomElement()!
            }
            let codes = statuses.map { makeCode(status: $0) }
            let counts = InvitationManagerViewModel.computeStatusCounts(codes)
            let revokedCount = codes.filter { $0.status == .revoked }.count
            return counts.pending + counts.used + counts.expired + revokedCount == codes.count
        }
    }

    @Test func pendingCountMatchesManualCount() {
        property("pending count matches manual filter") <- forAll(
            Gen<UInt>.fromElements(in: 0...15)
        ) { count in
            let codes = (0..<Int(count)).map { _ in makeCode(status: InvitationStatus.allCases.randomElement()!) }
            let counts = InvitationManagerViewModel.computeStatusCounts(codes)
            let expected = codes.filter { $0.status == .pending }.count
            return counts.pending == expected
        }
    }

    @Test func usedCountMatchesManualCount() {
        property("used count matches manual filter") <- forAll(
            Gen<UInt>.fromElements(in: 0...15)
        ) { count in
            let codes = (0..<Int(count)).map { _ in makeCode(status: InvitationStatus.allCases.randomElement()!) }
            let counts = InvitationManagerViewModel.computeStatusCounts(codes)
            let expected = codes.filter { $0.status == .used }.count
            return counts.used == expected
        }
    }

    @Test func expiredCountMatchesManualCount() {
        property("expired count matches manual filter") <- forAll(
            Gen<UInt>.fromElements(in: 0...15)
        ) { count in
            let codes = (0..<Int(count)).map { _ in makeCode(status: InvitationStatus.allCases.randomElement()!) }
            let counts = InvitationManagerViewModel.computeStatusCounts(codes)
            let expected = codes.filter { $0.status == .expired }.count
            return counts.expired == expected
        }
    }
}

// MARK: - Property 14: Invitation status filtering

struct InvitationStatusFilteringTests {

    // Feature: cardiologist-views, Property 14: Invitation status filtering

    @Test func allFilterReturnsEverything() {
        property("'All' filter returns all codes") <- forAll(
            Gen<UInt>.fromElements(in: 0...15)
        ) { count in
            let codes = (0..<Int(count)).map { _ in makeCode(status: InvitationStatus.allCases.randomElement()!) }
            let filtered = InvitationManagerViewModel.filterCodes(codes, by: .all)
            return filtered.count == codes.count
        }
    }

    @Test func pendingFilterReturnsOnlyPending() {
        property("'Pending' filter returns only pending codes") <- forAll(
            Gen<UInt>.fromElements(in: 0...15)
        ) { count in
            let codes = (0..<Int(count)).map { _ in makeCode(status: InvitationStatus.allCases.randomElement()!) }
            let filtered = InvitationManagerViewModel.filterCodes(codes, by: .pending)
            return filtered.allSatisfy { $0.status == .pending }
        }
    }

    @Test func filteredIsSubsetOfOriginal() {
        property("filtered list is always a subset of the original") <- forAll(
            Gen<UInt>.fromElements(in: 0...15)
        ) { count in
            let codes = (0..<Int(count)).map { _ in makeCode(status: InvitationStatus.allCases.randomElement()!) }
            let filters: [InvitationStatusFilter] = [.all, .pending, .used, .expired]
            let filter = filters.randomElement()!
            let filtered = InvitationManagerViewModel.filterCodes(codes, by: filter)
            return filtered.allSatisfy { item in codes.contains(where: { $0.id == item.id }) }
        }
    }

    @Test func filterMatchesExpectedCount() {
        property("filter count matches manual count for each status") <- forAll(
            Gen<UInt>.fromElements(in: 0...15)
        ) { count in
            let codes = (0..<Int(count)).map { _ in makeCode(status: InvitationStatus.allCases.randomElement()!) }
            let pendingFiltered = InvitationManagerViewModel.filterCodes(codes, by: .pending)
            let usedFiltered = InvitationManagerViewModel.filterCodes(codes, by: .used)
            let expiredFiltered = InvitationManagerViewModel.filterCodes(codes, by: .expired)
            let expectedPending = codes.filter { $0.status == .pending }.count
            let expectedUsed = codes.filter { $0.status == .used }.count
            let expectedExpired = codes.filter { $0.status == .expired }.count
            return pendingFiltered.count == expectedPending
                && usedFiltered.count == expectedUsed
                && expiredFiltered.count == expectedExpired
        }
    }
}
