import Foundation
import Combine
import Supabase

/// Segments available in the patient detail view
enum PatientDetailSegment: String, CaseIterable {
    case overview = "Overview"
    case history = "History"
    case reports = "Reports"
}

/// Report period options
enum ReportPeriod: String, CaseIterable {
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case last90Days = "Last 90 Days"

    var days: Int {
        switch self {
        case .last7Days: return 7
        case .last30Days: return 30
        case .last90Days: return 90
        }
    }
}

/// ViewModel for the patient detail screen
@MainActor
final class PatientDetailViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var patientDetail: PatientDetail?
    @Published var selectedSegment: PatientDetailSegment = .overview
    @Published private(set) var historySamples: [PhysiologicalSample] = []
    @Published var historyDateRange: DateRangeFilter = .week {
        didSet { Task { await loadHistory() } }
    }
    @Published private(set) var reportData: PatientReportData?
    @Published private(set) var isLoading = false
    @Published var isSavingRestingHR = false
    @Published var error: String?
    @Published var projectionHorizon: ProjectionHorizon = .twoWeeks

    // MARK: - Computed Properties

    var outlierResult: OutlierResult {
        Self.detectOutliers(from: historySamples)
    }

    /// Regression on outliers — tracks whether anomalous episodes are getting worse over time.
    /// Requires at least 3 outliers spanning at least 24 hours for a meaningful trend.
    var regressionResult: RegressionResult? {
        let outliers = outlierResult.outliers
        guard outliers.count >= 3 else { return nil }
        let dates = outliers.map(\.windowStart)
        let span = dates.max()!.timeIntervalSince(dates.min()!)
        guard span >= 86_400 else { return nil } // at least 24 hours apart
        return Self.computeRegression(from: outliers)
    }

    /// Anomaly frequency: count of outliers per week in the current date range
    var anomalyFrequencyPerWeek: Double {
        let outliers = outlierResult.outliers
        guard outliers.count >= 2 else { return Double(outliers.count) }
        let dates = outliers.map(\.windowStart)
        let earliest = dates.min()!
        let latest = dates.max()!
        let spanSeconds = latest.timeIntervalSince(earliest)
        let spanWeeks = max(spanSeconds / 604_800, 1.0 / 7.0) // at least 1 day to avoid division issues
        return Double(outliers.count) / spanWeeks
    }

    // MARK: - Dependencies

    private let service: ClinicianServiceProtocol
    let patientId: UUID

    // MARK: - Initialization

    init(service: ClinicianServiceProtocol, patientId: UUID) {
        self.service = service
        self.patientId = patientId
    }

    // MARK: - Public Methods

    /// Loads the patient profile and 7-day overview
    func loadPatientDetail() async {
        isLoading = true
        error = nil
        do {
            patientDetail = try await service.fetchPatientDetail(patientId: patientId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Loads history samples for the selected date range
    func loadHistory() async {
        isLoading = true
        error = nil
        let range = historyDateRange.dateRange
        do {
            historySamples = try await service.fetchPatientSamples(
                patientId: patientId, from: range.start, to: range.end
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Generates report data for the given period
    func generateReport(period: ReportPeriod) async {
        isLoading = true
        error = nil
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -period.days, to: now)!
        do {
            let samples = try await service.fetchPatientSamples(
                patientId: patientId, from: start, to: now
            )
            reportData = Self.buildReportData(
                patientName: patientDetail?.profile.name ?? "Unknown",
                period: period,
                samples: samples
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Pull-to-refresh support — reloads profile and history data independently
    func refresh() async {
        error = nil
        // Fetch profile
        do {
            let detail = try await service.fetchPatientDetail(patientId: patientId)
            patientDetail = nil  // force SwiftUI to detect the change
            patientDetail = detail
        } catch {
            self.error = error.localizedDescription
        }
        // Fetch history
        do {
            let range = historyDateRange.dateRange
            let samples = try await service.fetchPatientSamples(
                patientId: patientId, from: range.start, to: range.end
            )
            historySamples = []
            historySamples = samples
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Resting HR

    /// Validates that the input string represents a BPM value in [30.0, 220.0]
    nonisolated static func isValidBPM(_ input: String) -> Bool {
        guard let value = Double(input), value >= 30.0, value <= 220.0 else {
            return false
        }
        return true
    }

    /// Saves a new resting heart rate for the current patient
    func saveRestingHeartRate(_ bpmString: String) async {
        guard let bpm = Double(bpmString) else { return }
        isSavingRestingHR = true
        error = nil
        do {
            try await service.updatePatientRestingHeartRate(patientId: patientId, bpm: bpm)
            // Re-fetch full profile to ensure UI reflects the DB state
            patientDetail = try await service.fetchPatientDetail(patientId: patientId)
        } catch {
            self.error = error.localizedDescription
        }
        isSavingRestingHR = false
    }

    // MARK: - Static Helpers

    /// Returns a display string for a profile field, or a placeholder if nil
    nonisolated static func displayValue(_ value: String?, placeholder: String = "N/A") -> String {
        guard let value, !value.isEmpty else { return placeholder }
        return value
    }

    /// Returns a display string for an optional Int
    nonisolated static func displayValue(_ value: Int?, placeholder: String = "N/A") -> String {
        guard let value else { return placeholder }
        return "\(value)"
    }

    /// Returns a display string for an optional Double, formatted to 0 decimal places
    nonisolated static func displayValue(_ value: Double?, placeholder: String = "N/A") -> String {
        guard let value else { return placeholder }
        return String(format: "%.0f", value)
    }

    /// Computes Q1, Q3, and IQR from an array of values using linear interpolation.
    /// Precondition: values.count >= 4
    nonisolated static func computeIQR(_ values: [Double]) -> (q1: Double, q3: Double, iqr: Double) {
        let sorted = values.sorted()
        let n = Double(sorted.count)

        let q1Pos = (n - 1) * 0.25
        let q1Lower = Int(q1Pos)
        let q1Frac = q1Pos - Double(q1Lower)
        let q1 = sorted[q1Lower] + q1Frac * (sorted[q1Lower + 1] - sorted[q1Lower])

        let q3Pos = (n - 1) * 0.75
        let q3Lower = Int(q3Pos)
        let q3Frac = q3Pos - Double(q3Lower)
        let q3: Double
        if q3Lower + 1 < sorted.count {
            q3 = sorted[q3Lower] + q3Frac * (sorted[q3Lower + 1] - sorted[q3Lower])
        } else {
            q3 = sorted[q3Lower]
        }

        let iqr = q3 - q1
        return (q1: q1, q3: q3, iqr: iqr)
    }

    /// Separates samples into inliers and outliers using the IQR method.
    /// If samples.count < 4, returns all as inliers with empty outliers.
    nonisolated static func detectOutliers(from samples: [PhysiologicalSample]) -> OutlierResult {
        guard samples.count >= 4 else {
            return OutlierResult(inliers: samples, outliers: [])
        }

        let hrValues = samples.map(\.avgHeartRate)
        let (q1, q3, iqr) = computeIQR(hrValues)
        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr

        var inliers: [PhysiologicalSample] = []
        var outliers: [PhysiologicalSample] = []

        for sample in samples {
            if sample.avgHeartRate < lowerBound || sample.avgHeartRate > upperBound {
                outliers.append(sample)
            } else {
                inliers.append(sample)
            }
        }

        return OutlierResult(inliers: inliers, outliers: outliers)
    }

    /// Computes OLS linear regression from physiological samples.
    /// Returns nil if fewer than 2 samples or all timestamps are equal.
    nonisolated static func computeRegression(from samples: [PhysiologicalSample]) -> RegressionResult? {
        guard samples.count >= 2 else { return nil }

        let xs = samples.map { $0.windowStart.timeIntervalSince1970 }
        let ys = samples.map { $0.avgHeartRate }

        let n = Double(samples.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n

        var numerator = 0.0
        var denominator = 0.0
        for i in 0..<samples.count {
            let dx = xs[i] - meanX
            numerator += dx * (ys[i] - meanY)
            denominator += dx * dx
        }

        guard denominator != 0 else { return nil }

        let slope = numerator / denominator
        let intercept = meanY - slope * meanX

        let dates = samples.map(\.windowStart)
        let startDate = dates.min()!
        let endDate = dates.max()!

        return RegressionResult(slope: slope, intercept: intercept, startDate: startDate, endDate: endDate)
    }

    /// Predicts the BPM value at a given date using regression coefficients.
    nonisolated static func predictValue(at date: Date, using regression: RegressionResult) -> Double {
        regression.slope * date.timeIntervalSince1970 + regression.intercept
    }

    /// Returns a human-readable string for the anomaly regression slope.
    /// "Sin datos" if nil, "Estable" if |slopePerWeek| < 0.5,
    /// otherwise "+X.X BPM/sem" or "−X.X BPM/sem" describing anomaly severity trend.
    nonisolated static func slopeDisplayText(_ regressionResult: RegressionResult?) -> String {
        guard let result = regressionResult else { return "Sin anomalías" }
        let spw = result.slopePerWeek
        if abs(spw) < 0.5 { return "Anomalías estables" }
        if spw >= 0.5 {
            return String(format: "Anomalías \u{2191}%.1f BPM/sem", spw)
        }
        return String(format: "Anomalías \u{2193}%.1f BPM/sem", abs(spw))
    }

    /// Builds report data from samples (pure function, testable)
    static func buildReportData(
        patientName: String,
        period: ReportPeriod,
        samples: [PhysiologicalSample]
    ) -> PatientReportData {
        let aggregates = ClinicianService.computeAggregates(from: samples)
        let sessions = ClinicianService.groupIntoSessions(
            samples.sorted { $0.windowStart < $1.windowStart }
        )
        return PatientReportData(
            patientName: patientName,
            reportPeriod: period.rawValue,
            generatedDate: Date(),
            avgHeartRate: samples.isEmpty ? nil : aggregates.avgHR,
            avgRMSSD: aggregates.avgRMSSD,
            avgSDNN: aggregates.avgSDNN,
            sessionCount: sessions.count,
            totalMonitoringMinutes: aggregates.totalMinutes
        )
    }

    /// Groups history samples into sessions for display
    var historySessions: [MonitoringSession] {
        let sorted = historySamples.sorted { $0.windowStart < $1.windowStart }
        let groups = ClinicianService.groupIntoSessions(sorted)
        return groups.compactMap { session -> MonitoringSession? in
            guard let first = session.first, let last = session.last else { return nil }
            let avgHR = session.map(\.avgHeartRate).reduce(0, +) / Double(session.count)
            let rmssdVals = session.compactMap(\.rmssd)
            let sdnnVals = session.compactMap(\.sdnn)
            let duration = last.windowStart.timeIntervalSince(first.windowStart) + 60
            return MonitoringSession(
                date: first.windowStart,
                samples: session,
                duration: duration,
                avgHeartRate: avgHR,
                avgRMSSD: rmssdVals.isEmpty ? nil : rmssdVals.reduce(0, +) / Double(rmssdVals.count),
                avgSDNN: sdnnVals.isEmpty ? nil : sdnnVals.reduce(0, +) / Double(sdnnVals.count)
            )
        }.sorted { $0.date > $1.date }
    }
}
