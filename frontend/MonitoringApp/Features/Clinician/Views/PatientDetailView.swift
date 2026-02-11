import SwiftUI
import Combine

/// Patient detail screen with profile card and segmented Overview / History / Reports
struct PatientDetailView: View {
    @StateObject var viewModel: PatientDetailViewModel
    let service: ClinicianServiceProtocol
    @State private var showRestingHREditor = false

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.patientDetail == nil {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.2)
                    Text("Loading patient data...")
                        .font(.appBody)
                        .foregroundColor(.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else if let errorMsg = viewModel.error, viewModel.patientDetail == nil {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.statusYellow)
                    Text(errorMsg)
                        .font(.appBody)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await viewModel.loadPatientDetail() } }
                        .buttonStyle(.borderedProminent)
                        .tint(.appPrimary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(spacing: 16) {
                    if let errorMsg = viewModel.error {
                        Text(errorMsg)
                            .font(.appCaption)
                            .foregroundColor(.statusRed)
                            .padding(.horizontal)
                    }

                    if let detail = viewModel.patientDetail {
                        profileCard(detail.profile)
                    }

                    Picker("Section", selection: $viewModel.selectedSegment) {
                        ForEach(PatientDetailSegment.allCases, id: \.self) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    segmentContent
                }
                .padding(.vertical)
            }
        }
        .refreshable { await viewModel.refresh() }
        .background(Color.appBackground)
        .navigationTitle("Patient Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task { await viewModel.loadPatientDetail() }
        .sheet(isPresented: $showRestingHREditor) {
            RestingHREditorSheet(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var segmentContent: some View {
        switch viewModel.selectedSegment {
        case .overview:
            PatientOverviewSection(overview: viewModel.patientDetail?.overview)
        case .history:
            PatientHistorySection(viewModel: viewModel)
        case .reports:
            PatientReportsSection(viewModel: viewModel)
        }
    }

    // MARK: - Profile Card

    private func profileCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.appPrimary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(PatientDetailViewModel.displayValue(profile.name, placeholder: "Unknown"))
                        .font(.appTitle2)
                        .foregroundColor(.appTextPrimary)

                    HStack(spacing: 12) {
                        profileField("Age", value: PatientDetailViewModel.displayValue(profile.age))
                        profileField("Sex", value: PatientDetailViewModel.displayValue(profile.sex?.rawValue.capitalized))
                    }
                }
                Spacer()
            }

            HStack(spacing: 16) {
                profileField("Activity", value: PatientDetailViewModel.displayValue(profile.activityLevel?.rawValue.capitalized))

                HStack(spacing: 4) {
                    profileField("Resting HR", value: PatientDetailViewModel.displayValue(profile.restingHeartRate))

                    Button {
                        showRestingHREditor = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.appPrimary)
                            .imageScale(.medium)
                    }
                    .accessibilityLabel("Edit resting heart rate")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func profileField(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            Text(value)
                .font(.appCallout)
                .foregroundColor(.appTextPrimary)
        }
    }

}
