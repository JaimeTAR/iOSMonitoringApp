import SwiftUI
import Combine

/// Report generation section with period picker, summary display, and PDF export
struct PatientReportsSection: View {
    @ObservedObject var viewModel: PatientDetailViewModel
    @State private var selectedPeriod: ReportPeriod = .last7Days
    @State private var showShareSheet = false
    @State private var pdfData: Data?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 16) {
            periodPicker

            if let report = viewModel.reportData {
                reportSummary(report)
                exportButton
            } else if viewModel.isLoading {
                ProgressView()
                    .padding(.vertical, 24)
            } else {
                emptyState
            }
        }
        .padding(.horizontal)
        .onChange(of: selectedPeriod) { _, newPeriod in
            Task { await viewModel.generateReport(period: newPeriod) }
        }
        .task { await viewModel.generateReport(period: selectedPeriod) }
        .sheet(isPresented: $showShareSheet) {
            if let pdfData {
                ShareSheet(activityItems: [pdfData])
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Failed to generate PDF. Please try again.")
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Report Period", selection: $selectedPeriod) {
            ForEach(ReportPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Report Summary

    private func reportSummary(_ report: PatientReportData) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Report Summary")
                    .font(.appHeadline)
                    .foregroundColor(.appTextPrimary)
                Spacer()
                Text(report.reportPeriod)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }

            VStack(spacing: 8) {
                reportRow("Patient", value: report.patientName)
                reportRow("Avg Heart Rate", value: report.avgHeartRate.map { String(format: "%.0f BPM", $0) } ?? "N/A")
                reportRow("Avg RMSSD", value: report.avgRMSSD.map { String(format: "%.0f ms", $0) } ?? "N/A")
                reportRow("Avg SDNN", value: report.avgSDNN.map { String(format: "%.0f ms", $0) } ?? "N/A")
                reportRow("Sessions", value: "\(report.sessionCount)")
                reportRow("Total Time", value: formatMinutes(report.totalMonitoringMinutes))
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    private func reportRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.appCallout)
                .foregroundColor(.appTextSecondary)
            Spacer()
            Text(value)
                .font(.appCallout)
                .foregroundColor(.appTextPrimary)
        }
    }

    // MARK: - Export

    private var exportButton: some View {
        Button {
            guard let report = viewModel.reportData else { return }
            if let data = PDFReportGenerator.generatePDF(from: report) {
                pdfData = data
                showShareSheet = true
            } else {
                showError = true
            }
        } label: {
            Label("Export PDF", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.appPrimary)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.appTextSecondary)
            Text("Insufficient data to generate a report for this period.")
                .font(.appBody)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
