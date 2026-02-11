import SwiftUI

/// View displaying AI-powered wellness reports
struct ReportsView: View {
    @State private var selectedTimeRange: TimeRange = .week
    @State private var isGenerating = false
    
    enum TimeRange: String, CaseIterable {
        case week = "7 Days"
        case twoWeeks = "14 Days"
        case month = "30 Days"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Placeholder Report Card
                    placeholderReportCard
                    
                    // Generate Button
                    generateButton
                    
                    // Previous Reports Section
                    previousReportsSection
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("AI Reports")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Report Period")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            HStack(spacing: 8) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button {
                        selectedTimeRange = range
                    } label: {
                        Text(range.rawValue)
                            .font(.appSubheadline)
                            .foregroundColor(selectedTimeRange == range ? .white : .appTextPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedTimeRange == range ? Color.appPrimary : Color.appSurface)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Placeholder Report Card
    
    private var placeholderReportCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What You'll Get")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            VStack(spacing: 12) {
                reportFeatureRow(
                    icon: "heart.text.square",
                    title: "Heart Health Summary",
                    description: "Analysis of your heart rate patterns and trends"
                )
                
                Divider()
                
                reportFeatureRow(
                    icon: "waveform.path.ecg",
                    title: "HRV Analysis",
                    description: "Stress and recovery insights from HRV data"
                )
                
                Divider()
                
                reportFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Trend Detection",
                    description: "Identify patterns in your wellness data"
                )
                
                Divider()
                
                reportFeatureRow(
                    icon: "lightbulb",
                    title: "Personalized Tips",
                    description: "AI-generated recommendations for improvement"
                )
            }
            .padding()
            .background(Color.appSurface)
            .cornerRadius(12)
        }
    }
    
    private func reportFeatureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.appPrimary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appSubheadline)
                    .foregroundColor(.appTextPrimary)
                
                Text(description)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Generate Button
    
    private var generateButton: some View {
        Button {
            // Placeholder action
            isGenerating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isGenerating = false
            }
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isGenerating ? "Generating..." : "Generate Report")
                    .font(.appHeadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.appPrimary.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(true) // Disabled until feature is implemented
    }
    
    // MARK: - Previous Reports Section
    
    private var previousReportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Previous Reports")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            // Empty state
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.appTextSecondary)
                
                Text("No reports yet")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                
                Text("Generate your first AI wellness report to see it here")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color.appSurface)
            .cornerRadius(12)
        }
    }
}

#Preview {
    ReportsView()
}
