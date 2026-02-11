import SwiftUI

/// View displaying historical monitoring data with filtering and summaries
struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
    
    init(sampleService: any SampleServiceProtocol) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(sampleService: sampleService))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && !viewModel.hasData {
                    loadingView
                } else if viewModel.hasData {
                    contentView
                } else {
                    emptyStateView
                }
            }
            .background(Color.appBackground)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterMenu
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadData()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.error ?? "An error occurred")
            }
        }
    }
    
    // MARK: - Filter Menu
    
    private var filterMenu: some View {
        Menu {
            ForEach(DateRangeFilter.allCases, id: \.self) { filter in
                Button {
                    viewModel.selectedFilter = filter
                } label: {
                    HStack {
                        Text(filter.rawValue)
                        if viewModel.selectedFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.selectedFilter.rawValue)
                    .font(.appCallout)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .foregroundColor(.appPrimary)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading history...")
                .font(.appBody)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary card
                summaryCard
                
                // Daily chart
                if !viewModel.dailySummaries.isEmpty {
                    dailyChartCard
                }
                
                // Sessions list
                sessionsSection
            }
            .padding()
        }
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Summary")
                    .font(.appHeadline)
                    .foregroundColor(.appTextPrimary)
                Spacer()
                Text(viewModel.selectedFilter.rawValue)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
            
            HStack(spacing: 16) {
                summaryItem(
                    title: "Total Time",
                    value: viewModel.totalMonitoringTime,
                    icon: "clock.fill",
                    color: .statusBlue
                )
                
                summaryItem(
                    title: "Avg HR",
                    value: viewModel.periodAvgHeartRate.map { "\(Int($0))" } ?? "--",
                    icon: "heart.fill",
                    color: .appPrimary
                )
                
                summaryItem(
                    title: "Sessions",
                    value: "\(viewModel.sessions.count)",
                    icon: "chart.bar.fill",
                    color: .statusGreen
                )
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    private func summaryItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.metricDisplay)
                .foregroundColor(.appTextPrimary)
            
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Daily Chart Card
    
    private var dailyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Activity")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            // Simple bar chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.dailySummaries.prefix(7).reversed()) { summary in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.appPrimary)
                            .frame(width: 32, height: barHeight(for: summary))
                        
                        // Day label
                        Text(summary.shortDate)
                            .font(.appCaption2)
                            .foregroundColor(.appTextSecondary)
                    }
                }
                
                Spacer()
            }
            .frame(height: 120)
            
            // Legend
            HStack(spacing: 16) {
                legendItem(color: .appPrimary, text: "Minutes monitored")
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    private func barHeight(for summary: DailySummary) -> CGFloat {
        let maxMinutes = viewModel.dailySummaries.map { $0.totalMinutes }.max() ?? 1
        let ratio = CGFloat(summary.totalMinutes) / CGFloat(max(maxMinutes, 1))
        return max(ratio * 80, 4) // Min height of 4
    }
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
    }
    
    // MARK: - Sessions Section
    
    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sessions")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            // Group sessions by day
            ForEach(groupedSessionsByDay, id: \.date) { dayGroup in
                DaySessionsCard(dayGroup: dayGroup)
            }
        }
    }
    
    /// Sessions grouped by day
    private var groupedSessionsByDay: [DaySessionGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.sessions) { session in
            calendar.startOfDay(for: session.date)
        }
        
        return grouped.map { date, sessions in
            DaySessionGroup(date: date, sessions: sessions.sorted { $0.date > $1.date })
        }.sorted { $0.date > $1.date }
    }
    
    private func sessionRow(_ session: MonitoringSession) -> some View {
        HStack(spacing: 12) {
            // Heart icon with color based on avg HR
            Circle()
                .fill(Color.heartRateColor(for: Int(session.avgHeartRate)).opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "heart.fill")
                        .foregroundColor(Color.heartRateColor(for: Int(session.avgHeartRate)))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.formattedDateTime)
                    .font(.appHeadline)
                    .foregroundColor(.appTextPrimary)
                
                Text(session.formattedDuration)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(Int(session.avgHeartRate))")
                        .font(.appHeadline)
                        .foregroundColor(.appTextPrimary)
                    Text("BPM")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
                
                if let rmssd = session.avgRMSSD {
                    Text("RMSSD: \(Int(rmssd))")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.appTextSecondary)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.appTextSecondary)
            
            VStack(spacing: 8) {
                Text("No History Yet")
                    .font(.appTitle2)
                    .foregroundColor(.appTextPrimary)
                
                Text("Your monitoring sessions will appear here.")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                
                Text("Try adjusting the time filter above.")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HistoryView(sampleService: SampleService())
}

// MARK: - Day Session Group Model

struct DaySessionGroup {
    let date: Date
    let sessions: [MonitoringSession]
    
    var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
    
    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }
    
    var formattedTotalDuration: String {
        let minutes = Int(totalDuration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
    
    var avgHeartRate: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map { $0.avgHeartRate }.reduce(0, +) / Double(sessions.count)
    }
}

// MARK: - Day Sessions Card

struct DaySessionsCard: View {
    let dayGroup: DaySessionGroup
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Day header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayGroup.formattedDate)
                            .font(.appHeadline)
                            .foregroundColor(.appTextPrimary)
                        
                        HStack(spacing: 12) {
                            Label(dayGroup.formattedTotalDuration, systemImage: "clock")
                            Label("\(dayGroup.sessions.count) session\(dayGroup.sessions.count == 1 ? "" : "s")", systemImage: "waveform.path.ecg")
                            Label("\(Int(dayGroup.avgHeartRate)) BPM", systemImage: "heart.fill")
                        }
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                }
                .padding()
                .background(Color.appSurface)
            }
            .buttonStyle(.plain)
            
            // Sessions list (expandable)
            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(dayGroup.sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            sessionRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .cornerRadius(12)
        .clipped()
    }
    
    private func sessionRow(_ session: MonitoringSession) -> some View {
        HStack(spacing: 12) {
            // Time
            Text(timeString(from: session.date))
                .font(.appCallout)
                .foregroundColor(.appTextSecondary)
                .frame(width: 60, alignment: .leading)
            
            // Heart rate indicator
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
                
                if let rmssd = session.avgRMSSD {
                    Text("RMSSD: \(Int(rmssd))")
                        .font(.appCaption2)
                        .foregroundColor(.appTextSecondary)
                }
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
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.appTextSecondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.appSurfaceElevated)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
