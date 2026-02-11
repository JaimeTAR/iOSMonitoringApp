import SwiftUI
import Combine

/// Clinician home screen: stat cards, needs-attention list, recent activity feed
struct ClinicianDashboardView: View {
    @StateObject var viewModel: ClinicianDashboardViewModel
    let service: ClinicianServiceProtocol

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.stats == nil {
                    loadingView
                } else if let errorMsg = viewModel.error, viewModel.stats == nil {
                    errorView(errorMsg)
                } else {
                    contentView
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Dashboard")
            .navigationDestination(for: UUID.self) { patientId in
                PatientDetailView(
                    viewModel: PatientDetailViewModel(service: service, patientId: patientId),
                    service: service
                )
            }
            .task { await viewModel.loadData() }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                statCardsRow
                needsAttentionSection
                recentActivitySection
            }
            .padding()
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Stat Cards

    private var statCardsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Total Patients",
                value: "\(viewModel.stats?.totalActivePatients ?? 0)",
                icon: "person.2.fill"
            )
            StatCard(
                title: "Active Today",
                value: "\(viewModel.stats?.patientsActiveToday ?? 0)",
                icon: "waveform.path.ecg"
            )
            StatCard(
                title: "Pending",
                value: "\(viewModel.stats?.pendingInvitations ?? 0)",
                icon: "envelope.fill"
            )
        }
    }

    // MARK: - Needs Attention

    private var needsAttentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Needs Attention")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)

            if viewModel.needsAttentionItems.isEmpty {
                Text("All patients are on track.")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(viewModel.needsAttentionItems) { item in
                    NavigationLink(value: item.id) {
                        needsAttentionRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    private func needsAttentionRow(_ item: NeedsAttentionItem) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(reasonColor(item.reason).opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: reasonIcon(item.reason))
                        .foregroundColor(reasonColor(item.reason))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.patientName)
                    .font(.appHeadline)
                    .foregroundColor(.appTextPrimary)
                Text(item.detail)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.appTextSecondary)
        }
        .padding(.vertical, 4)
    }

    private func reasonColor(_ reason: AttentionReason) -> Color {
        switch reason {
        case .inactivity: return .statusYellow
        case .elevatedHeartRate: return .statusRed
        case .decliningHRV: return .statusRed
        }
    }

    private func reasonIcon(_ reason: AttentionReason) -> String {
        switch reason {
        case .inactivity: return "clock.fill"
        case .elevatedHeartRate: return "heart.fill"
        case .decliningHRV: return "waveform.path.ecg"
        }
    }

    // MARK: - Recent Activity (aggregated by patient)

    private var recentActivitySection: some View {
        let grouped = groupedActivity(viewModel.recentActivity)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)

            if grouped.isEmpty {
                Text("No recent sessions available.")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(grouped, id: \.patientId) { group in
                    NavigationLink(value: group.patientId) {
                        aggregatedActivityRow(group)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    private struct PatientActivityGroup {
        let patientId: UUID
        let patientName: String
        let sessionCount: Int
        let lastSessionDate: Date
        let totalMinutes: Int
        let avgHeartRate: Double
    }

    private func groupedActivity(_ items: [RecentActivityItem]) -> [PatientActivityGroup] {
        let byPatient = Dictionary(grouping: items) { $0.patientId }
        return byPatient.compactMap { (patientId, sessions) -> PatientActivityGroup? in
            guard let latest = sessions.max(by: { $0.sessionDate < $1.sessionDate }) else { return nil }
            let totalMin = sessions.reduce(0) { $0 + $1.durationMinutes }
            let avgHR = sessions.reduce(0.0) { $0 + $1.avgHeartRate } / Double(sessions.count)
            return PatientActivityGroup(
                patientId: patientId,
                patientName: latest.patientName,
                sessionCount: sessions.count,
                lastSessionDate: latest.sessionDate,
                totalMinutes: totalMin,
                avgHeartRate: avgHR
            )
        }.sorted { $0.lastSessionDate > $1.lastSessionDate }
    }

    private func aggregatedActivityRow(_ group: PatientActivityGroup) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.patientName)
                    .font(.appHeadline)
                    .foregroundColor(.appTextPrimary)
                Text("\(group.sessionCount) session\(group.sessionCount == 1 ? "" : "s") · \(formattedDuration(group.totalMinutes))")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(group.avgHeartRate)) BPM")
                    .font(.appCallout)
                    .foregroundColor(.appTextPrimary)
                Text(formattedRelativeDate(group.lastSessionDate))
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.appTextSecondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formattedRelativeDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func formattedDuration(_ totalMinutes: Int) -> String {
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if totalMinutes < 1440 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        let days = totalMinutes / 1440
        let remainingHours = (totalMinutes % 1440) / 60
        return remainingHours > 0 ? "\(days)d \(remainingHours)h" : "\(days)d"
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading dashboard...")
                .font(.appBody)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.statusYellow)
            Text(message)
                .font(.appBody)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.appPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
