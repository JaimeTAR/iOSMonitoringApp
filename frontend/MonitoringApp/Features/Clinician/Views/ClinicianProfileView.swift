import SwiftUI
import Combine

/// Clinician profile screen: name, email, stats, and sign-out
struct ClinicianProfileView: View {
    @StateObject var viewModel: ClinicianProfileViewModel
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.profile == nil {
                    loadingView
                } else if let errorMsg = viewModel.error, viewModel.profile == nil {
                    errorView(errorMsg)
                } else {
                    contentView
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Profile")
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadProfile() }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                statsCard
                signOutButton
            }
            .padding()
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.appPrimary)

            if let profile = viewModel.profile {
                Text(profile.name ?? "Clinician")
                    .font(.appTitle2)
                    .foregroundColor(.appTextPrimary)

                // Display email from auth user if available, otherwise show role
                Text("Clinician")
                    .font(.appCallout)
                    .foregroundColor(.appTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 16) {
            Text("Account Info")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                statItem(
                    title: "Active Patients",
                    value: "\(viewModel.activePatientCount)",
                    icon: "person.2.fill"
                )
                statItem(
                    title: "Member Since",
                    value: viewModel.accountCreatedDate.map { formattedDate($0) } ?? "N/A",
                    icon: "calendar"
                )
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }

    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.appHeadline)
                .foregroundColor(.appPrimary)
            Text(value)
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button(role: .destructive) {
            Task {
                await viewModel.signOut()
                onSignOut()
            }
        } label: {
            Text("Sign Out")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.statusRed)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Loading profile...")
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
            Button("Retry") { Task { await viewModel.loadProfile() } }
                .buttonStyle(.borderedProminent)
                .tint(.appPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}
