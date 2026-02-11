import Foundation
import Combine

/// Summary of monitoring data for a specific day
struct DailySummary: Identifiable {
    let id: UUID = UUID()
    let date: Date
    let sampleCount: Int
    let avgHeartRate: Double
    let avgRMSSD: Double?
    let avgSDNN: Double?
    let totalMinutes: Int
    
    /// Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Short date string (e.g., "Mon 12")
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: date)
    }
}

/// Summary of monitoring data for a week
struct WeeklySummary: Identifiable {
    let id: UUID = UUID()
    let weekStart: Date
    let weekEnd: Date
    let totalSamples: Int
    let avgHeartRate: Double
    let avgRMSSD: Double?
    let avgSDNN: Double?
    let totalMinutes: Int
    let dailySummaries: [DailySummary]
    
    /// Formatted week range string
    var formattedRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekStart)
        let end = formatter.string(from: weekEnd)
        return "\(start) - \(end)"
    }
}

/// Represents a monitoring session (group of consecutive samples)
struct MonitoringSession: Identifiable {
    let id: UUID = UUID()
    let date: Date
    let samples: [PhysiologicalSample]
    let duration: TimeInterval
    let avgHeartRate: Double
    let avgRMSSD: Double?
    let avgSDNN: Double?
    
    /// Formatted date and time string
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Formatted duration string
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}


/// Date range filter options
enum DateRangeFilter: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    case all = "All"
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let end = calendar.startOfDay(for: now).addingTimeInterval(86400) // End of today
        
        let start: Date
        switch self {
        case .week:
            start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .threeMonths:
            start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .all:
            start = calendar.date(byAdding: .year, value: -10, to: now) ?? now
        }
        
        return (start, end)
    }
}

/// ViewModel for managing history data and filtering
@MainActor
final class HistoryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var sessions: [MonitoringSession] = []
    @Published private(set) var dailySummaries: [DailySummary] = []
    @Published private(set) var weeklySummary: WeeklySummary?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?
    @Published var selectedFilter: DateRangeFilter = .week {
        didSet {
            Task { await loadData() }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether there is any history data
    var hasData: Bool {
        !sessions.isEmpty
    }
    
    /// Total monitoring time in the selected period
    var totalMonitoringTime: String {
        let totalMinutes = dailySummaries.reduce(0) { $0 + $1.totalMinutes }
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours)h \(minutes)m"
        }
    }
    
    /// Average heart rate across the selected period
    var periodAvgHeartRate: Double? {
        guard !dailySummaries.isEmpty else { return nil }
        let total = dailySummaries.reduce(0.0) { $0 + $1.avgHeartRate * Double($1.sampleCount) }
        let count = dailySummaries.reduce(0) { $0 + $1.sampleCount }
        return count > 0 ? total / Double(count) : nil
    }
    
    // MARK: - Private Properties
    
    private let sampleService: any SampleServiceProtocol
    
    // MARK: - Initialization
    
    init(sampleService: any SampleServiceProtocol) {
        self.sampleService = sampleService
    }
    
    // MARK: - Public Methods
    
    /// Loads history data for the selected date range
    func loadData() async {
        isLoading = true
        error = nil
        
        let range = selectedFilter.dateRange
        
        do {
            let samples = try await sampleService.fetchSamples(from: range.start, to: range.end)
            processSamples(samples)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Refreshes the data
    func refresh() async {
        await loadData()
    }
    
    /// Clears the error state
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Methods
    
    private func processSamples(_ samples: [PhysiologicalSample]) {
        guard !samples.isEmpty else {
            sessions = []
            dailySummaries = []
            weeklySummary = nil
            return
        }
        
        // Group samples by day
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.windowStart)
        }
        
        // Create daily summaries
        dailySummaries = groupedByDay.map { date, daySamples in
            createDailySummary(date: date, samples: daySamples)
        }.sorted { $0.date > $1.date }
        
        // Create sessions from samples
        sessions = createSessions(from: samples)
        
        // Create weekly summary if we have data
        if !dailySummaries.isEmpty {
            weeklySummary = createWeeklySummary(from: dailySummaries)
        }
    }
    
    private func createDailySummary(date: Date, samples: [PhysiologicalSample]) -> DailySummary {
        let avgHR = samples.map { $0.avgHeartRate }.reduce(0, +) / Double(samples.count)
        
        let rmssdValues = samples.compactMap { $0.rmssd }
        let avgRMSSD = rmssdValues.isEmpty ? nil : rmssdValues.reduce(0, +) / Double(rmssdValues.count)
        
        let sdnnValues = samples.compactMap { $0.sdnn }
        let avgSDNN = sdnnValues.isEmpty ? nil : sdnnValues.reduce(0, +) / Double(sdnnValues.count)
        
        return DailySummary(
            date: date,
            sampleCount: samples.count,
            avgHeartRate: avgHR,
            avgRMSSD: avgRMSSD,
            avgSDNN: avgSDNN,
            totalMinutes: samples.count // Each sample represents 1 minute
        )
    }
    
    private func createWeeklySummary(from dailySummaries: [DailySummary]) -> WeeklySummary {
        let sortedDays = dailySummaries.sorted { $0.date < $1.date }
        let weekStart = sortedDays.first?.date ?? Date()
        let weekEnd = sortedDays.last?.date ?? Date()
        
        let totalSamples = dailySummaries.reduce(0) { $0 + $1.sampleCount }
        let totalMinutes = dailySummaries.reduce(0) { $0 + $1.totalMinutes }
        
        // Weighted average for heart rate
        let weightedHR = dailySummaries.reduce(0.0) { $0 + $1.avgHeartRate * Double($1.sampleCount) }
        let avgHR = totalSamples > 0 ? weightedHR / Double(totalSamples) : 0
        
        // Average RMSSD
        let rmssdValues = dailySummaries.compactMap { $0.avgRMSSD }
        let avgRMSSD = rmssdValues.isEmpty ? nil : rmssdValues.reduce(0, +) / Double(rmssdValues.count)
        
        // Average SDNN
        let sdnnValues = dailySummaries.compactMap { $0.avgSDNN }
        let avgSDNN = sdnnValues.isEmpty ? nil : sdnnValues.reduce(0, +) / Double(sdnnValues.count)
        
        return WeeklySummary(
            weekStart: weekStart,
            weekEnd: weekEnd,
            totalSamples: totalSamples,
            avgHeartRate: avgHR,
            avgRMSSD: avgRMSSD,
            avgSDNN: avgSDNN,
            totalMinutes: totalMinutes,
            dailySummaries: sortedDays
        )
    }
    
    private func createSessions(from samples: [PhysiologicalSample]) -> [MonitoringSession] {
        guard !samples.isEmpty else { return [] }
        
        // Sort samples by time
        let sortedSamples = samples.sorted { $0.windowStart < $1.windowStart }
        
        var sessions: [MonitoringSession] = []
        var currentSessionSamples: [PhysiologicalSample] = []
        
        for sample in sortedSamples {
            if let lastSample = currentSessionSamples.last {
                // Check if this sample is within 2 minutes of the last one (allowing for gaps)
                let timeDiff = sample.windowStart.timeIntervalSince(lastSample.windowStart)
                if timeDiff <= 120 { // 2 minutes threshold
                    currentSessionSamples.append(sample)
                } else {
                    // Start a new session
                    if !currentSessionSamples.isEmpty {
                        sessions.append(createSession(from: currentSessionSamples))
                    }
                    currentSessionSamples = [sample]
                }
            } else {
                currentSessionSamples.append(sample)
            }
        }
        
        // Don't forget the last session
        if !currentSessionSamples.isEmpty {
            sessions.append(createSession(from: currentSessionSamples))
        }
        
        // Sort sessions by date (most recent first)
        return sessions.sorted { $0.date > $1.date }
    }
    
    private func createSession(from samples: [PhysiologicalSample]) -> MonitoringSession {
        let sortedSamples = samples.sorted { $0.windowStart < $1.windowStart }
        let startTime = sortedSamples.first?.windowStart ?? Date()
        let endTime = sortedSamples.last?.windowStart ?? Date()
        let duration = endTime.timeIntervalSince(startTime) + 60 // Add 1 minute for the last sample
        
        let avgHR = samples.map { $0.avgHeartRate }.reduce(0, +) / Double(samples.count)
        
        let rmssdValues = samples.compactMap { $0.rmssd }
        let avgRMSSD = rmssdValues.isEmpty ? nil : rmssdValues.reduce(0, +) / Double(rmssdValues.count)
        
        let sdnnValues = samples.compactMap { $0.sdnn }
        let avgSDNN = sdnnValues.isEmpty ? nil : sdnnValues.reduce(0, +) / Double(sdnnValues.count)
        
        return MonitoringSession(
            date: startTime,
            samples: sortedSamples,
            duration: duration,
            avgHeartRate: avgHR,
            avgRMSSD: avgRMSSD,
            avgSDNN: avgSDNN
        )
    }
}
