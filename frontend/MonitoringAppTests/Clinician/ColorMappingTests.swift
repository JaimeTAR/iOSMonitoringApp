//
//  ColorMappingTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 16: Color mapping correctness
//  Validates: Requirements 13.1, 13.3
//

import Testing
import SwiftUI
import SwiftCheck
@testable import MonitoringApp

// MARK: - Arbitrary Conformances

extension HealthTrend: @retroactive Arbitrary {
    public static var arbitrary: Gen<HealthTrend> {
        Gen<HealthTrend>.fromElements(of: HealthTrend.allCases)
    }
}

// MARK: - Property Tests

struct ColorMappingTests {

    // Feature: cardiologist-views, Property 16: Color mapping correctness

    @Test func healthTrend_colorMapping_isCorrectForAllCases() {
        property("HealthTrend color maps green/yellow/red correctly") <- forAll { (trend: HealthTrend) in
            switch trend {
            case .improving:
                return trend.color == Color.statusGreen
            case .stable:
                return trend.color == Color.statusYellow
            case .declining:
                return trend.color == Color.statusRed
            }
        }
    }

    @Test func invitationStatus_badgeColor_isCorrectForAllCases() {
        property("InvitationStatus badge color maps correctly") <- forAll { (status: InvitationStatus) in
            switch status {
            case .pending:
                return status.badgeColor == Color.statusYellow
            case .used:
                return status.badgeColor == Color.statusGreen
            case .expired:
                return status.badgeColor == Color.statusRed
            case .revoked:
                return status.badgeColor == Color.gray
            }
        }
    }

    @Test func healthTrend_allCases_haveDistinctColors() {
        let colors = HealthTrend.allCases.map { $0.color }
        let uniqueColors = Set(colors.map { "\($0)" })
        #expect(uniqueColors.count == HealthTrend.allCases.count)
    }

    @Test func invitationStatus_allCases_haveDistinctColors() {
        let colors = InvitationStatus.allCases.map { $0.badgeColor }
        let uniqueColors = Set(colors.map { "\($0)" })
        #expect(uniqueColors.count == InvitationStatus.allCases.count)
    }
}
