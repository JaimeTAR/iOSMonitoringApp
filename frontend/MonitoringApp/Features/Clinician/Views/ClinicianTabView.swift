import SwiftUI
import Combine

/// Root tab container for the clinician experience
/// Displays four tabs: Dashboard, Patients, Invitations, Profile
struct ClinicianTabView: View {
    let service: ClinicianServiceProtocol
    let clinicianId: UUID
    let onSignOut: () -> Void

    @State private var selectedTab: Tab = .dashboard

    @StateObject private var dashboardVM: ClinicianDashboardViewModel
    @StateObject private var patientListVM: PatientListViewModel
    @StateObject private var invitationVM: InvitationManagerViewModel
    @StateObject private var profileVM: ClinicianProfileViewModel

    init(service: ClinicianServiceProtocol, clinicianId: UUID, onSignOut: @escaping () -> Void) {
        self.service = service
        self.clinicianId = clinicianId
        self.onSignOut = onSignOut
        _dashboardVM = StateObject(wrappedValue: ClinicianDashboardViewModel(service: service, clinicianId: clinicianId))
        _patientListVM = StateObject(wrappedValue: PatientListViewModel(service: service, clinicianId: clinicianId))
        _invitationVM = StateObject(wrappedValue: InvitationManagerViewModel(service: service, clinicianId: clinicianId))
        _profileVM = StateObject(wrappedValue: ClinicianProfileViewModel(service: service, clinicianId: clinicianId))
    }

    enum Tab: Int, CaseIterable {
        case dashboard, patients, invitations, profile

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .patients: return "Patients"
            case .invitations: return "Invitations"
            case .profile: return "Profile"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .patients: return "person.2.fill"
            case .invitations: return "envelope.fill"
            case .profile: return "person.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ClinicianDashboardView(
                viewModel: dashboardVM,
                service: service
            )
            .tabItem { Label(Tab.dashboard.title, systemImage: Tab.dashboard.icon) }
            .tag(Tab.dashboard)

            PatientListView(
                viewModel: patientListVM,
                service: service
            )
            .tabItem { Label(Tab.patients.title, systemImage: Tab.patients.icon) }
            .tag(Tab.patients)

            InvitationManagerView(
                viewModel: invitationVM
            )
            .tabItem { Label(Tab.invitations.title, systemImage: Tab.invitations.icon) }
            .tag(Tab.invitations)

            ClinicianProfileView(
                viewModel: profileVM,
                onSignOut: onSignOut
            )
            .tabItem { Label(Tab.profile.title, systemImage: Tab.profile.icon) }
            .tag(Tab.profile)
        }
        .tint(.appPrimary)
    }
}
