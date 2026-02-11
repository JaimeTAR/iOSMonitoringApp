import Foundation
import Combine
import Supabase

/// ViewModel for the clinician profile screen
@MainActor
final class ClinicianProfileViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var profile: UserProfile?
    @Published private(set) var activePatientCount: Int = 0
    @Published private(set) var accountCreatedDate: Date?
    @Published private(set) var isLoading = false
    @Published var error: String?

    // MARK: - Dependencies

    private let service: ClinicianServiceProtocol
    private let clinicianId: UUID

    // MARK: - Initialization

    init(service: ClinicianServiceProtocol, clinicianId: UUID) {
        self.service = service
        self.clinicianId = clinicianId
    }

    // MARK: - Public Methods

    /// Loads the clinician profile and computes stats
    func loadProfile() async {
        isLoading = true
        error = nil
        do {
            let fetchedProfile = try await service.fetchClinicianProfile(userId: clinicianId)
            profile = fetchedProfile
            accountCreatedDate = fetchedProfile.createdAt

            // Fetch patients to compute active count
            let patients = try await service.fetchPatients(for: clinicianId)
            activePatientCount = patients.count
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Signs out the current user
    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Pull-to-refresh support
    func refresh() async {
        await loadProfile()
    }
}
