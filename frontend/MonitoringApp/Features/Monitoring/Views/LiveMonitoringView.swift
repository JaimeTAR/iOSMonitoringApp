import SwiftUI

/// Live monitoring view displaying real-time heart rate and HRV data
struct LiveMonitoringView: View {
    @ObservedObject var bleViewModel: BLEViewModel
    @ObservedObject var monitoringViewModel: MonitoringViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Heart rate display
                    heartRateSection
                    
                    // Sensor warning if needed
                    if monitoringViewModel.isSensorContactLost {
                        sensorWarning
                    }
                    
                    // HRV metrics
                    hrvMetricsSection
                    
                    // Session info
                    sessionInfoSection
                }
                .padding()
            }
            
            // Bottom control bar
            controlBar
        }
        .background(Color.appBackground)
        .navigationTitle("Live Monitoring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ConnectionStatusBadge(status: bleViewModel.connectionStatus)
            }
        }
        .onAppear {
            if !monitoringViewModel.isMonitoring {
                monitoringViewModel.startMonitoring()
            }
        }
        .alert("Error", isPresented: $monitoringViewModel.showError) {
            Button("OK") {
                monitoringViewModel.dismissError()
            }
        } message: {
            Text(monitoringViewModel.errorMessage ?? "An error occurred")
        }
    }
    
    // MARK: - Heart Rate Section
    
    private var heartRateSection: some View {
        VStack(spacing: 16) {
            // Large heart rate display with color coding
            ZStack {
                // Background circle
                Circle()
                    .fill(heartRateBackgroundColor.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                // Heart rate value
                VStack(spacing: 4) {
                    if let hr = monitoringViewModel.currentHeartRate {
                        Text("\(hr)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(heartRateColor)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.2), value: hr)
                    } else {
                        Text("--")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(.appTextSecondary)
                    }
                    
                    Text("BPM")
                        .font(.appSubheadline)
                        .foregroundColor(.appTextSecondary)
                }
            }
            
            // Heart rate zone indicator
            heartRateZoneIndicator
            
            // Anomaly warning
            if monitoringViewModel.isHeartRateAnomalous {
                anomalyWarning
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    private var heartRateColor: Color {
        guard let hr = monitoringViewModel.currentHeartRate else {
            return .appTextSecondary
        }
        return Color.heartRateColor(for: hr)
    }
    
    private var heartRateBackgroundColor: Color {
        heartRateColor
    }
    
    private var heartRateZoneIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: zoneIcon)
                .foregroundColor(heartRateColor)
            
            Text(zoneText)
                .font(.appCallout)
                .foregroundColor(.appTextPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(heartRateColor.opacity(0.1))
        .cornerRadius(20)
    }
    
    private var zoneIcon: String {
        switch monitoringViewModel.heartRateZone {
        case .low:
            return "arrow.down.heart"
        case .normal:
            return "heart.fill"
        case .elevated:
            return "heart.fill"
        case .high:
            return "exclamationmark.heart"
        case .unknown:
            return "heart.slash"
        }
    }
    
    private var zoneText: String {
        switch monitoringViewModel.heartRateZone {
        case .low:
            return "Low"
        case .normal:
            return "Normal"
        case .elevated:
            return "Elevated"
        case .high:
            return "High"
        case .unknown:
            return "No Data"
        }
    }
    
    // MARK: - Warnings
    
    private var sensorWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.statusYellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Check Sensor Placement")
                    .font(.appHeadline)
                    .foregroundColor(.appTextPrimary)
                
                Text("Sensor contact not detected")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.statusYellow.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var anomalyWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.statusRed)
            
            Text("Heart rate outside normal range")
                .font(.appCaption)
                .foregroundColor(.statusRed)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.statusRed.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - HRV Metrics Section
    
    private var hrvMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HRV Metrics")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            HStack(spacing: 16) {
                hrvMetricCard(
                    title: "RMSSD",
                    value: monitoringViewModel.currentRMSSD,
                    unit: "ms"
                )
                
                hrvMetricCard(
                    title: "SDNN",
                    value: monitoringViewModel.currentSDNN,
                    unit: "ms"
                )
            }
            
            if monitoringViewModel.currentRMSSD == nil && monitoringViewModel.currentSDNN == nil {
                Text("HRV metrics will appear after the first minute of monitoring")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    private func hrvMetricCard(title: String, value: Double?, unit: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            
            if let value = value {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", value))
                        .font(.metricDisplay)
                        .foregroundColor(.appTextPrimary)
                    
                    Text(unit)
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
            } else {
                Text("--")
                    .font(.metricDisplay)
                    .foregroundColor(.appTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Session Info Section
    
    private var sessionInfoSection: some View {
        HStack(spacing: 16) {
            sessionInfoItem(
                title: "Duration",
                value: monitoringViewModel.formattedDuration,
                icon: "clock.fill"
            )
            
            sessionInfoItem(
                title: "Samples",
                value: "\(monitoringViewModel.sessionSampleCount)",
                icon: "chart.bar.fill"
            )
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    private func sessionInfoItem(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.appPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                
                Text(value)
                    .font(.appHeadline)
                    .foregroundColor(.appTextPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Control Bar
    
    private var controlBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                // Stop button
                Button {
                    monitoringViewModel.stopMonitoring()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.appHeadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appSurface)
                    .foregroundColor(.appPrimary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appPrimary, lineWidth: 2)
                    )
                }
            }
            .padding()
            .background(Color.appBackground)
        }
    }
}

#Preview {
    NavigationStack {
        LiveMonitoringView(
            bleViewModel: BLEViewModel(bleService: BLEService()),
            monitoringViewModel: MonitoringViewModel(
                bleService: BLEService(),
                sampleService: SampleService()
            )
        )
    }
}
