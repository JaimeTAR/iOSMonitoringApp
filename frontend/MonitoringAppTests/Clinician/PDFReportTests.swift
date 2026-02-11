//
//  PDFReportTests.swift
//  MonitoringAppTests
//
//  Feature: cardiologist-views, Property 17: PDF report data completeness
//  Validates: Requirements 10.3
//

import Testing
import Foundation
import CoreGraphics
import SwiftCheck
@testable import MonitoringApp

// MARK: - Generators

private let reportDataGen: Gen<PatientReportData> = Gen.compose { c in
    let nameLength = c.generate(using: Gen<Int>.fromElements(in: 1...20))
    let letters = "abcdefghijklmnopqrstuvwxyz "
    let name = String((0..<nameLength).map { _ in letters.randomElement()! })
    let period = c.generate(using: Gen.fromElements(of: ReportPeriod.allCases))
    let avgHR = c.generate(using: Gen<Double>.fromElements(in: 50...180))
    let avgRMSSD = c.generate(using: Gen<Double>.fromElements(in: 10...120))
    let avgSDNN = c.generate(using: Gen<Double>.fromElements(in: 10...120))
    let sessionCount = c.generate(using: Gen<Int>.fromElements(in: 1...100))
    let totalMinutes = c.generate(using: Gen<Int>.fromElements(in: 1...6000))

    return PatientReportData(
        patientName: name,
        reportPeriod: period.rawValue,
        generatedDate: Date(),
        avgHeartRate: avgHR,
        avgRMSSD: avgRMSSD,
        avgSDNN: avgSDNN,
        sessionCount: sessionCount,
        totalMonitoringMinutes: totalMinutes
    )
}

// MARK: - Arbitrary Conformance

extension ReportPeriod: @retroactive Arbitrary {
    public static var arbitrary: Gen<ReportPeriod> {
        Gen.fromElements(of: ReportPeriod.allCases)
    }
}

extension PatientReportData: @retroactive Arbitrary {
    public static var arbitrary: Gen<PatientReportData> {
        reportDataGen
    }
}

// MARK: - Property Tests

struct PDFReportTests {

    // Feature: cardiologist-views, Property 17: PDF report data completeness

    @Test func pdfContainsAllRequiredFields() {
        property("PDF output contains all required text fields") <- forAll(reportDataGen) { report in
            guard let pdfData = PDFReportGenerator.generatePDF(from: report) else {
                return false
            }

            // Extract text content from PDF data
            guard let pdfString = extractTextFromPDF(data: pdfData) else {
                return false
            }

            // Verify all required fields are present
            let containsName = pdfString.contains(report.patientName)
            let containsPeriod = pdfString.contains(report.reportPeriod)
            let containsHR = pdfString.contains(String(format: "%.0f", report.avgHeartRate!))
            let containsRMSSD = pdfString.contains(String(format: "%.0f", report.avgRMSSD!))
            let containsSDNN = pdfString.contains(String(format: "%.0f", report.avgSDNN!))
            let containsSessions = pdfString.contains("\(report.sessionCount)")

            return containsName
                && containsPeriod
                && containsHR
                && containsRMSSD
                && containsSDNN
                && containsSessions
        }
    }

    @Test func pdfGenerationReturnsData() {
        let report = PatientReportData(
            patientName: "Test Patient",
            reportPeriod: "Last 7 Days",
            generatedDate: Date(),
            avgHeartRate: 72.0,
            avgRMSSD: 45.0,
            avgSDNN: 55.0,
            sessionCount: 5,
            totalMonitoringMinutes: 120
        )

        let data = PDFReportGenerator.generatePDF(from: report)
        #expect(data != nil)
        #expect(data!.count > 0)
    }
}

// MARK: - PDF Text Extraction Helper

private func extractTextFromPDF(data: Data) -> String? {
    guard let provider = CGDataProvider(data: data as CFData),
          let document = CGPDFDocument(provider) else {
        return nil
    }

    var fullText = ""
    for pageIndex in 1...document.numberOfPages {
        guard let page = document.page(at: pageIndex) else { continue }
        guard let contentStream = page.dictionary else { continue }

        // Use a simple approach: convert PDF data to string representation
        // For property testing, we check the raw PDF data contains the text strings
        let _ = contentStream
    }

    // Fallback: search the raw PDF data for text strings
    if let rawString = String(data: data, encoding: .ascii) {
        fullText = rawString
    } else if let rawString = String(data: data, encoding: .utf8) {
        fullText = rawString
    }

    return fullText.isEmpty ? nil : fullText
}
