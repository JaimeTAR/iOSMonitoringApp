import SwiftUI

/// Compact metric card for the clinician dashboard
struct StatCard: View {
    let title: String
    let value: String
    var icon: String?

    var body: some View {
        VStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.appHeadline)
                    .foregroundColor(.appPrimary)
            }
            Text(value)
                .font(.metricDisplay)
                .foregroundColor(.appTextPrimary)
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.appSurface)
        .cornerRadius(12)
    }
}

#Preview {
    HStack(spacing: 12) {
        StatCard(title: "Total Patients", value: "24", icon: "person.2.fill")
        StatCard(title: "Active Today", value: "8", icon: "waveform.path.ecg")
        StatCard(title: "Pending", value: "3", icon: "envelope.fill")
    }
    .padding()
}
