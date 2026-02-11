import SwiftUI

/// Main dashboard view showing current status and quick actions
struct DashboardView: View {
    @ObservedObject var bleViewModel: BLEViewModel
    @ObservedObject var monitoringViewModel: MonitoringViewModel
    @Binding var selectedTab: MainTabView.Tab
    
    let sampleService: any SampleServiceProtocol
    
    @State private var todaySampleCount: Int = 0
    @State private var todayAvgHeartRate: Double?
    @State private var todayTotalMinutes: Int = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection status card
                    connectionCard
                    
                    // Today's summary card
                    todaySummaryCard
                    
                    // Quick actions
                    quickActionsSection
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Dashboard")
            .task {
                await loadTodaySummary()
            }
            .refreshable {
                await loadTodaySummary()
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadTodaySummary() async {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
        
        do {
            let samples = try await sampleService.fetchSamples(from: startOfToday, to: endOfToday)
            todaySampleCount = samples.count
            todayTotalMinutes = samples.count // Each sample is 1 minute
            
            if !samples.isEmpty {
                let totalHR = samples.map { $0.avgHeartRate }.reduce(0, +)
                todayAvgHeartRate = totalHR / Double(samples.count)
            } else {
                todayAvgHeartRate = nil
            }
        } catch {
            // Silently fail - show empty state
            todaySampleCount = 0
            todayAvgHeartRate = nil
            todayTotalMinutes = 0
        }
    }
    
    // MARK: - Connection Card
    
    private var connectionCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Heart Rate Sensor")
                    .font(.appHeadline)
                    .foregroundColor(.appTextPrimary)
                
                Spacer()
                
                ConnectionStatusBadge(status: bleViewModel.connectionStatus)
            }
            
            if bleViewModel.isConnected {
                // Show current heart rate
                HeartRateDisplay(
                    heartRate: monitoringViewModel.currentHeartRate,
                    size: .large
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                
                if let deviceName = bleViewModel.connectedDeviceName {
                    Text(deviceName)
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
            } else {
                // Not connected state
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.appTextSecondary)
                    
                    Text("Not Connected")
                        .font(.appBody)
                        .foregroundColor(.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            
            // Quick connect button
            quickConnectButton
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    // MARK: - Quick Connect Button
    
    @ViewBuilder
    private var quickConnectButton: some View {
        if bleViewModel.isConnected {
            NavigationLink {
                LiveMonitoringView(
                    bleViewModel: bleViewModel,
                    monitoringViewModel: monitoringViewModel
                )
            } label: {
                HStack {
                    if monitoringViewModel.isMonitoring {
                        // Pulsing indicator when actively monitoring
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                        Text("Monitoring • \(monitoringViewModel.formattedDuration)")
                    } else {
                        Image(systemName: "waveform.path.ecg")
                        Text("Start Monitoring")
                    }
                }
                .font(.appHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(monitoringViewModel.isMonitoring ? Color.statusGreen : Color.appPrimary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        } else if bleViewModel.hasRememberedDevice {
            Button {
                bleViewModel.quickConnect()
            } label: {
                HStack {
                    if bleViewModel.isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                    Text(bleViewModel.isConnecting ? "Connecting..." : "Quick Connect")
                }
                .font(.appHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appPrimary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(bleViewModel.isConnecting)
        } else {
            Button {
                selectedTab = .monitoring
            } label: {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Connect Sensor")
                }
                .font(.appHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appPrimary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Today's Summary Card
    
    private var todaySummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Summary")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            if todaySampleCount > 0 {
                HStack(spacing: 0) {
                    summaryItem(
                        title: "Samples",
                        value: "\(todaySampleCount)",
                        icon: "chart.bar.fill"
                    )
                    
                    summaryItem(
                        title: "Avg HR",
                        value: todayAvgHeartRate.map { "\(Int($0))" } ?? "--",
                        icon: "heart.fill"
                    )
                    
                    summaryItemWithUnit(
                        title: "Duration",
                        value: "\(todayTotalMinutes)",
                        unit: "min",
                        icon: "clock.fill"
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 32))
                        .foregroundColor(.appTextSecondary)
                    
                    Text("No monitoring data today")
                        .font(.appBody)
                        .foregroundColor(.appTextSecondary)
                    
                    Text("Connect your sensor to start tracking")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    private func summaryItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.appPrimary)
            
            Text(value)
                .font(.metricDisplay)
                .foregroundColor(.appTextPrimary)
            
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func summaryItemWithUnit(title: String, value: String, unit: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.appPrimary)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.metricDisplay)
                    .foregroundColor(.appTextPrimary)
                Text(unit)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
            
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            HStack(spacing: 12) {
                Button {
                    selectedTab = .monitoring
                } label: {
                    quickActionCard(
                        title: "Devices",
                        icon: "antenna.radiowaves.left.and.right",
                        color: .statusBlue
                    )
                }
                
                Button {
                    selectedTab = .history
                } label: {
                    quickActionCard(
                        title: "History",
                        icon: "chart.xyaxis.line",
                        color: .statusGreen
                    )
                }
            }
        }
    }
    
    private func quickActionCard(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
            
            Text(title)
                .font(.appCallout)
                .foregroundColor(.appTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.appSurface)
        .cornerRadius(12)
    }
}

#Preview {
    DashboardView(
        bleViewModel: BLEViewModel(bleService: BLEService()),
        monitoringViewModel: MonitoringViewModel(
            bleService: BLEService(),
            sampleService: SampleService()
        ),
        selectedTab: .constant(.dashboard),
        sampleService: SampleService()
    )
}
