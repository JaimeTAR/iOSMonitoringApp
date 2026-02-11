import SwiftUI

/// Detailed view for a single monitoring session
struct SessionDetailView: View {
    let session: MonitoringSession
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with main metrics
                headerCard
                
                // Heart rate trend chart
                heartRateTrendCard
                
                // HRV metrics card
                hrvMetricsCard
                
                // Session details
                sessionDetailsCard
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Date and duration
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.formattedDateTime)
                        .font(.appHeadline)
                        .foregroundColor(.appTextPrimary)
                    
                    Text(session.formattedDuration)
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
                
                Spacer()
                
                // Sample count badge
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                    Text("\(session.samples.count) samples")
                        .font(.appCaption)
                }
                .foregroundColor(.appTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appBackground)
                .cornerRadius(12)
            }
            
            Divider()
            
            // Main heart rate display
            VStack(spacing: 8) {
                Text("\(Int(session.avgHeartRate))")
                    .font(.heartRateDisplay)
                    .foregroundColor(Color.heartRateColor(for: Int(session.avgHeartRate)))
                
                Text("Average BPM")
                    .font(.appSubheadline)
                    .foregroundColor(.appTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
            // Min/Max heart rate
            HStack(spacing: 24) {
                heartRateStatItem(
                    title: "Min",
                    value: minHeartRate,
                    color: .statusBlue
                )
                
                heartRateStatItem(
                    title: "Max",
                    value: maxHeartRate,
                    color: .statusRed
                )
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    private var minHeartRate: Int {
        Int(session.samples.map { $0.avgHeartRate }.min() ?? 0)
    }
    
    private var maxHeartRate: Int {
        Int(session.samples.map { $0.avgHeartRate }.max() ?? 0)
    }
    
    private func heartRateStatItem(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.metricDisplay)
                    .foregroundColor(color)
                Text("BPM")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Heart Rate Trend Card
    
    private var heartRateTrendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Heart Rate Trend")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            // Chart with Y-axis labels
            HStack(alignment: .center, spacing: 4) {
                // Y-axis label
                Text("BPM")
                    .font(.appCaption2)
                    .foregroundColor(.appTextSecondary)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .frame(width: 12)
                
                // Y-axis values
                yAxisLabels
                
                // Chart area
                GeometryReader { geometry in
                    heartRateChart(in: geometry.size)
                }
            }
            .frame(height: 150)
            
            // X-axis with label
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    // Spacer for Y-axis width
                    Color.clear.frame(width: 44)
                    timeLabelsView
                }
                
                HStack {
                    Color.clear.frame(width: 44)
                    Text("Time")
                        .font(.appCaption2)
                        .foregroundColor(.appTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    private var yAxisLabels: some View {
        let heartRates = session.samples.map { $0.avgHeartRate }
        let minHR = Int(heartRates.min() ?? 60)
        let maxHR = Int(heartRates.max() ?? 100)
        
        // Round to nice values
        let roundedMin = (minHR / 10) * 10
        let roundedMax = ((maxHR / 10) + 1) * 10
        let midValue = (roundedMin + roundedMax) / 2
        
        return VStack {
            Text("\(roundedMax)")
                .font(.appCaption2)
                .foregroundColor(.appTextSecondary)
            Spacer()
            Text("\(midValue)")
                .font(.appCaption2)
                .foregroundColor(.appTextSecondary)
            Spacer()
            Text("\(roundedMin)")
                .font(.appCaption2)
                .foregroundColor(.appTextSecondary)
        }
        .frame(width: 28, alignment: .trailing)
    }
    
    private var timeLabelsView: some View {
        let samples = session.samples
        guard samples.count > 1 else {
            return AnyView(EmptyView())
        }
        
        // Get start and end times
        let startTime = samples.first?.windowStart ?? session.date
        let endTime = samples.last?.windowStart ?? session.date
        
        // Calculate middle time
        let middleTime = startTime.addingTimeInterval(endTime.timeIntervalSince(startTime) / 2)
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        return AnyView(
            HStack {
                Text(formatter.string(from: startTime))
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                Spacer()
                Text(formatter.string(from: middleTime))
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                Spacer()
                Text(formatter.string(from: endTime))
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
        )
    }
    
    private func heartRateChart(in size: CGSize) -> some View {
        let heartRates = session.samples.map { $0.avgHeartRate }
        let minHR = heartRates.min() ?? 0
        let maxHR = heartRates.max() ?? 100
        let range = max(maxHR - minHR, 10) // Minimum range of 10
        
        return ZStack {
            // Background grid lines
            VStack(spacing: 0) {
                ForEach(0..<4) { _ in
                    Divider()
                        .background(Color.appBorder.opacity(0.5))
                    Spacer()
                }
                Divider()
                    .background(Color.appBorder.opacity(0.5))
            }
            
            // Heart rate line
            Path { path in
                guard heartRates.count > 1 else { return }
                
                let stepX = size.width / CGFloat(heartRates.count - 1)
                
                for (index, hr) in heartRates.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedY = (hr - minHR) / range
                    let y = size.height - (CGFloat(normalizedY) * size.height)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.appPrimary, lineWidth: 2)
            
            // Data points
            ForEach(Array(heartRates.enumerated()), id: \.offset) { index, hr in
                let stepX = size.width / CGFloat(max(heartRates.count - 1, 1))
                let x = CGFloat(index) * stepX
                let normalizedY = (hr - minHR) / range
                let y = size.height - (CGFloat(normalizedY) * size.height)
                
                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: 6, height: 6)
                    .position(x: x, y: y)
            }
        }
    }
    
    // MARK: - HRV Metrics Card
    
    private var hrvMetricsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HRV Metrics")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            HStack(spacing: 16) {
                hrvMetricItem(
                    title: "RMSSD",
                    value: session.avgRMSSD,
                    unit: "ms",
                    description: "Heart rate variability"
                )
                
                hrvMetricItem(
                    title: "SDNN",
                    value: session.avgSDNN,
                    unit: "ms",
                    description: "Overall variability"
                )
            }
            
            if session.avgRMSSD == nil && session.avgSDNN == nil {
                Text("HRV data not available for this session")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    private func hrvMetricItem(title: String, value: Double?, unit: String, description: String) -> some View {
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
            
            Text(description)
                .font(.appCaption2)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Session Details Card
    
    private var sessionDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Details")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            VStack(spacing: 12) {
                detailRow(title: "Start Time", value: formatTime(session.date))
                
                Divider()
                
                detailRow(title: "End Time", value: formatTime(sessionEndTime))
                
                Divider()
                
                detailRow(title: "Duration", value: session.formattedDuration)
                
                Divider()
                
                detailRow(title: "Samples Collected", value: "\(session.samples.count)")
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    private var sessionEndTime: Date {
        session.date.addingTimeInterval(session.duration)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.appBody)
                .foregroundColor(.appTextSecondary)
            
            Spacer()
            
            Text(value)
                .font(.appBody)
                .foregroundColor(.appTextPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(
            session: MonitoringSession(
                date: Date(),
                samples: [
                    PhysiologicalSample(
                        userId: UUID(),
                        windowStart: Date(),
                        avgHeartRate: 72,
                        rmssd: 45.5,
                        sdnn: 52.3,
                        sampleCount: 60
                    ),
                    PhysiologicalSample(
                        userId: UUID(),
                        windowStart: Date().addingTimeInterval(60),
                        avgHeartRate: 75,
                        rmssd: 42.1,
                        sdnn: 48.7,
                        sampleCount: 60
                    ),
                    PhysiologicalSample(
                        userId: UUID(),
                        windowStart: Date().addingTimeInterval(120),
                        avgHeartRate: 78,
                        rmssd: 40.2,
                        sdnn: 46.5,
                        sampleCount: 60
                    )
                ],
                duration: 180,
                avgHeartRate: 75,
                avgRMSSD: 42.6,
                avgSDNN: 49.2
            )
        )
    }
}
