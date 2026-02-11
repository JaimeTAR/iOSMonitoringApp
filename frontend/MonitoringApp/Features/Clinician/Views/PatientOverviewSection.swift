import SwiftUI
import Charts

/// 7-day summary with stat cards and HR / RMSSD trend charts
struct PatientOverviewSection: View {
    let overview: PatientOverview?

    var body: some View {
        if let overview {
            VStack(spacing: 16) {
                summaryStats(overview)
                heartRateChart(overview)
                rmssdChart(overview)
            }
            .padding(.horizontal)
        } else {
            emptyState
        }
    }

    // MARK: - Summary Stats

    private func summaryStats(_ overview: PatientOverview) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                miniStat("Avg HR", value: String(format: "%.0f", overview.avgHeartRate7d), unit: "BPM")
                miniStat("Avg RMSSD", value: overview.avgRMSSD7d.map { String(format: "%.0f", $0) } ?? "N/A", unit: "ms")
                miniStat("Avg SDNN", value: overview.avgSDNN7d.map { String(format: "%.0f", $0) } ?? "N/A", unit: "ms")
            }
            HStack(spacing: 12) {
                miniStat("Sessions", value: "\(overview.sessionCount7d)", unit: nil)
                miniStat("Total Time", value: formatMinutes(overview.totalMinutes7d), unit: nil)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    private func miniStat(_ title: String, value: String, unit: String?) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            if let unit {
                Text("\(title) (\(unit))")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            } else {
                Text(title)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Heart Rate Chart

    private func heartRateChart(_ overview: PatientOverview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate Trend")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)

            if overview.dailyHeartRates.isEmpty {
                Text("No heart rate data")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            } else {
                Chart {
                    ForEach(overview.dailyHeartRates, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("BPM", point.value)
                        )
                        .foregroundStyle(Color.appPrimary)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("BPM", point.value)
                        )
                        .foregroundStyle(Color.appPrimary)
                    }
                }
                .chartYAxisLabel("BPM")
                .frame(height: 180)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    // MARK: - RMSSD Chart

    private func rmssdChart(_ overview: PatientOverview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RMSSD Trend")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)

            if overview.dailyRMSSD.isEmpty {
                Text("No RMSSD data")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            } else {
                Chart {
                    ForEach(overview.dailyRMSSD, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("RMSSD", point.value)
                        )
                        .foregroundStyle(Color.statusGreen)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("RMSSD", point.value)
                        )
                        .foregroundStyle(Color.statusGreen)
                    }
                }
                .chartYAxisLabel("ms")
                .frame(height: 180)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.appTextSecondary)
            Text("No recent data available")
                .font(.appBody)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
