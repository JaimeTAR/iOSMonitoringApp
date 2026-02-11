import SwiftUI
import Combine
import Charts

/// Full session history with date range filters, summary card, and expandable session list
struct PatientHistorySection: View {
    @ObservedObject var viewModel: PatientDetailViewModel

    var body: some View {
        VStack(spacing: 16) {
            dateRangeFilter
            summarCard
            heartRateChart
            outlierListSection
            sessionList
        }
        .padding(.horizontal)
        .task { await viewModel.loadHistory() }
    }

    // MARK: - Date Range Filter

    private var dateRangeFilter: some View {
        Picker("Date Range", selection: $viewModel.historyDateRange) {
            ForEach(DateRangeFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Card

    private var summarCard: some View {
        let sessions = viewModel.historySessions
        let samples = viewModel.historySamples
        let aggregates = ClinicianService.computeAggregates(from: samples)

        return VStack(spacing: 12) {
            HStack {
                Text("Summary")
                    .font(.appHeadline)
                    .foregroundColor(.appTextPrimary)
                Spacer()
                Text(viewModel.historyDateRange.rawValue)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }

            HStack(spacing: 16) {
                summaryItem(title: "Total Time", value: formatMinutes(aggregates.totalMinutes))
                summaryItem(title: "Avg HR", value: samples.isEmpty ? "--" : String(format: "%.0f", aggregates.avgHR))
                summaryItem(title: "Sessions", value: "\(sessions.count)")
            }

            HStack(spacing: 16) {
                summaryItem(title: "Anomalías", value: "\(viewModel.outlierResult.outliers.count)")
                summaryItem(title: "Tendencia", value: PatientDetailViewModel.slopeDisplayText(viewModel.regressionResult))
                summaryItem(title: "Frec/sem", value: String(format: "%.1f", viewModel.anomalyFrequencyPerWeek))
            }

            if let rmssd = aggregates.avgRMSSD {
                HStack(spacing: 16) {
                    summaryItem(title: "Avg RMSSD", value: String(format: "%.0f ms", rmssd))
                    Spacer()
                }
            }

            if !viewModel.outlierResult.outliers.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(viewModel.outlierResult.outliers.count) lecturas atípicas detectadas")
                        .font(.appCaption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Heart Rate Chart

    private var heartRateChart: some View {
        Group {
            if !viewModel.historySamples.isEmpty {
                let outlierResult = viewModel.outlierResult
                let dataPoints: [ChartDataPoint] =
                    outlierResult.inliers.map { ChartDataPoint(date: $0.windowStart, value: $0.avgHeartRate, isOutlier: false) } +
                    outlierResult.outliers.map { ChartDataPoint(date: $0.windowStart, value: $0.avgHeartRate, isOutlier: true) }

                VStack(spacing: 8) {
                    Chart {
                        ForEach(dataPoints) { point in
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("BPM", point.value)
                            )
                            .symbol(point.isOutlier ? .triangle : .circle)
                            .foregroundStyle(point.isOutlier ? Color.orange : Color.blue)
                        }

                        if let regression = viewModel.regressionResult {
                            let startBPM = PatientDetailViewModel.predictValue(at: regression.startDate, using: regression)
                            let endBPM = PatientDetailViewModel.predictValue(at: regression.endDate, using: regression)

                            LineMark(
                                x: .value("Date", regression.startDate),
                                y: .value("BPM", startBPM)
                            )
                            .foregroundStyle(Color.red.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))

                            LineMark(
                                x: .value("Date", regression.endDate),
                                y: .value("BPM", endBPM)
                            )
                            .foregroundStyle(Color.red.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))

                            // Projection line
                            let targetDate = viewModel.projectionHorizon.targetDate(from: regression.endDate)
                            let rawProjectedBPM = PatientDetailViewModel.predictValue(at: targetDate, using: regression)
                            let projectedBPM = min(max(rawProjectedBPM, 30), 220)

                            LineMark(
                                x: .value("Date", regression.endDate),
                                y: .value("BPM", endBPM)
                            )
                            .foregroundStyle(Color.red.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

                            LineMark(
                                x: .value("Date", targetDate),
                                y: .value("BPM", projectedBPM)
                            )
                            .foregroundStyle(Color.red.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        }
                    }
                    .chartYScale(domain: 30...220)
                    .frame(height: 200)
                    .padding()
                    .background(Color.appSurface)
                    .cornerRadius(12)

                    // Projection horizon picker
                    if viewModel.regressionResult != nil {
                        Picker("Horizonte", selection: $viewModel.projectionHorizon) {
                            ForEach(ProjectionHorizon.allCases, id: \.self) { horizon in
                                Text(horizon.rawValue).tag(horizon)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Projection label
                    if let regression = viewModel.regressionResult {
                        let targetDate = viewModel.projectionHorizon.targetDate(from: regression.endDate)
                        let rawProjectedBPM = PatientDetailViewModel.predictValue(at: targetDate, using: regression)
                        let projectedBPM = min(max(rawProjectedBPM, 30), 220)
                        let isStable = abs(regression.slopePerWeek) < 0.5
                        let dateStr = targetDate.formatted(.dateTime.day().month(.abbreviated))

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle")
                                .font(.caption)
                                .foregroundColor(.appTextSecondary)
                            Text("Anomalías ~\(String(format: "%.1f", projectedBPM)) BPM el \(dateStr)\(isStable ? " (estable)" : "")")
                                .font(.appCaption)
                                .foregroundColor(.appTextSecondary)
                        }
                    }

                    // Projection disclaimer
                    if viewModel.regressionResult != nil {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("Tendencia basada en regresión lineal de anomalías. No constituye un pronóstico clínico.")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
    }

    // MARK: - Outlier List

    private var outlierListSection: some View {
        Group {
            if !viewModel.outlierResult.outliers.isEmpty {
                DisclosureGroup("Lecturas atípicas (\(viewModel.outlierResult.outliers.count))") {
                    let sortedOutliers = viewModel.outlierResult.outliers.sorted { $0.windowStart > $1.windowStart }
                    ForEach(sortedOutliers, id: \.id) { outlier in
                        HStack {
                            Text(outlier.windowStart.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                .font(.appCaption)
                                .foregroundColor(.appTextSecondary)
                            Spacer()
                            Text(String(format: "%.0f BPM", outlier.avgHeartRate))
                                .font(.appCallout)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .font(.appCallout)
                .foregroundColor(.appTextPrimary)
                .padding()
                .background(Color.appSurface)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        let grouped = groupedByDay(viewModel.historySessions)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Sessions")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)

            if grouped.isEmpty {
                Text("No sessions for this period.")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(grouped, id: \.date) { group in
                    HistoryDayCard(dayGroup: group)
                }
            }
        }
    }

    // MARK: - Helpers

    private func groupedByDay(_ sessions: [MonitoringSession]) -> [HistoryDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.date)
        }
        return grouped.map { date, daySessions in
            HistoryDayGroup(date: date, sessions: daySessions.sorted { $0.date > $1.date })
        }.sorted { $0.date > $1.date }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

// MARK: - Chart Data Point

private struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isOutlier: Bool
}

// MARK: - Day Group Model

private struct HistoryDayGroup {
    let date: Date
    let sessions: [MonitoringSession]

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return Self.dayFormatter.string(from: date)
    }
}

// MARK: - Day Card

private struct HistoryDayCard: View {
    let dayGroup: HistoryDayGroup
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(dayGroup.formattedDate)
                        .font(.appHeadline)
                        .foregroundColor(.appTextPrimary)
                    Spacer()
                    Text("\(dayGroup.sessions.count) session\(dayGroup.sessions.count == 1 ? "" : "s")")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                }
                .padding()
                .background(Color.appSurface)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(dayGroup.sessions) { session in
                        HistorySessionRow(session: session)
                    }
                }
            }
        }
        .cornerRadius(12)
        .clipped()
    }
}

// MARK: - Session Row

private struct HistorySessionRow: View {
    let session: MonitoringSession
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Text(timeString(session.date))
                        .font(.appCallout)
                        .foregroundColor(.appTextSecondary)
                        .frame(width: 60, alignment: .leading)

                    Circle()
                        .fill(Color.heartRateColor(for: Int(session.avgHeartRate)).opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.heartRateColor(for: Int(session.avgHeartRate)))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.formattedDuration)
                            .font(.appCallout)
                            .foregroundColor(.appTextPrimary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("\(Int(session.avgHeartRate))")
                            .font(.appHeadline)
                            .foregroundColor(.appTextPrimary)
                        Text("BPM")
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.appSurfaceElevated)
            }
            .buttonStyle(.plain)

            if isExpanded {
                sessionDetail
            }
        }
    }

    private var sessionDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                detailItem("Duration", value: session.formattedDuration)
                detailItem("Avg HR", value: "\(Int(session.avgHeartRate)) BPM")
            }
            HStack(spacing: 16) {
                detailItem("RMSSD", value: session.avgRMSSD.map { String(format: "%.0f ms", $0) } ?? "N/A")
                detailItem("SDNN", value: session.avgSDNN.map { String(format: "%.0f ms", $0) } ?? "N/A")
            }
            Text("Started: \(formattedDateTime(session.date))")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .padding()
        .background(Color.appSurfaceElevated.opacity(0.7))
    }

    private func detailItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            Text(value)
                .font(.appCallout)
                .foregroundColor(.appTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func timeString(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func formattedDateTime(_ date: Date) -> String {
        Self.dateTimeFormatter.string(from: date)
    }
}
