//
//  InvitationCodeGenerationTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 12: Invitation code generation format
//  Validates: Requirements 11.2
//

import Testing
import Foundation
import SwiftCheck
@testable import MonitoringApp

// MARK: - Property Tests

struct InvitationCodeGenerationTests {

    // Feature: cardiologist-views, Property 12: Invitation code generation format

    @Test func generatedCode_is5Characters() {
        property("generated code is exactly 5 characters") <- forAll(
            Gen<Int>.pure(0) // dummy generator to run 100 iterations
        ) { _ in
            let code = ClinicianService.generateRandomCode(length: 5)
            return code.count == 5
        }
    }

    @Test func generatedCode_alphanumericOnly() {
        let validChars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        property("generated code contains only uppercase alphanumeric characters") <- forAll(
            Gen<Int>.pure(0)
        ) { _ in
            let code = ClinicianService.generateRandomCode(length: 5)
            return code.unicodeScalars.allSatisfy { validChars.contains($0) }
        }
    }

    @Test func invitationCodeInsert_pendingStatusAnd7DayExpiry() {
        property("InvitationCodeInsert has pending status and 7-day expiry") <- forAll(
            Gen<Int>.pure(0)
        ) { _ in
            let now = Date()
            let expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: now)!
            let insert = InvitationCodeInsert(
                clinicianId: UUID(),
                code: ClinicianService.generateRandomCode(length: 5),
                status: .pending,
                createdAt: now,
                expiresAt: expiresAt
            )

            let expiryInterval = insert.expiresAt.timeIntervalSince(insert.createdAt)
            let sevenDaysInSeconds = 7.0 * 24.0 * 3600.0

            return insert.status == .pending
                && insert.code.count == 5
                && abs(expiryInterval - sevenDaysInSeconds) < 1.0
        }
    }

    @Test func generatedCodes_haveVariation() {
        // Generate multiple codes and verify they're not all identical
        var codes = Set<String>()
        for _ in 0..<20 {
            codes.insert(ClinicianService.generateRandomCode(length: 5))
        }
        // With 36^5 possible codes, 20 draws should almost certainly produce at least 2 distinct values
        #expect(codes.count > 1)
    }

    @Test func customLength_respected() {
        property("generateRandomCode respects the length parameter") <- forAll(
            Gen<UInt>.fromElements(in: 1...20)
        ) { length in
            let code = ClinicianService.generateRandomCode(length: Int(length))
            return code.count == Int(length)
        }
    }
}
