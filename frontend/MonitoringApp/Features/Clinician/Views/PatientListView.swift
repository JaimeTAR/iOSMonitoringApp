import SwiftUI
import Combine

/// Displays all patients linked to the clinician with search, sort, and trend indicators
struct PatientListView: View {
    @StateObject var viewModel: PatientListViewModel
    let service: ClinicianServiceProtocol

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.patients.isEmpty {
                    loadingView
                } else if let errorMsg = viewModel.error, viewModel.patients.isEmpty {
                    errorView(errorMsg)
                } else if viewModel.patients.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Patients")
            .searchable(text: $viewModel.searchText, prompt: "Search patients")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    sortMenu
                }
            }
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
        List {
            ForEach(viewModel.filteredPatients) { patient in
                NavigationLink(value: patient.id) {
                    patientRow(patient)
                }
                .listRowBackground(Color.appSurface)
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }

    private func patientRow(_ patient: PatientSummary) -> some View {
        HStack(spacing: 12) {
            TrendIndicator(trend: patient.trend)

            VStack(alignment: .leading, spacing: 2) {
                Text(patient.name)
                    .font(.appHeadline)
                    .foregroundColor(.appTextPrimary)
                if let lastActive = patient.lastActiveDate {
                    Text("Last active: \(formattedDate(lastActive))")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                } else {
                    Text("No activity recorded")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
            }

            Spacer()

            if let avgHR = patient.avgHeartRate7d {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(avgHR))")
                        .font(.appHeadline)
                        .foregroundColor(.appTextPrimary)
                    Text("BPM")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(PatientSortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.sortOption = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundColor(.appPrimary)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Loading patients...")
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
            Button("Retry") { Task { await viewModel.loadData() } }
                .buttonStyle(.borderedProminent)
                .tint(.appPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 64))
                .foregroundColor(.appTextSecondary)
            VStack(spacing: 8) {
                Text("No Patients Yet")
                    .font(.appTitle2)
                    .foregroundColor(.appTextPrimary)
                Text("Generate an invitation code to link patients to your account.")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}
