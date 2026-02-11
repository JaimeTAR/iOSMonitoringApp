import SwiftUI

/// Colored dot representing a patient's recent health trend
struct TrendIndicator: View {
    let trend: HealthTrend

    var body: some View {
        Circle()
            .fill(trend.color)
            .frame(width: 10, height: 10)
            .accessibilityLabel(trend.rawValue)
    }
}

#Preview {
    HStack(spacing: 16) {
        TrendIndicator(trend: .improving)
        TrendIndicator(trend: .stable)
        TrendIndicator(trend: .declining)
    }
    .padding()
}
