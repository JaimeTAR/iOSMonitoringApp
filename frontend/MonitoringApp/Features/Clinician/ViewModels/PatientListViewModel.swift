import Foundation
import Combine
import Supabase

/// Sort options for the patient list
enum PatientSortOption: String, CaseIterable {
    case name = "Name"
    case lastActive = "Last Active"
    case avgHeartRate = "Avg HR"
}

/// ViewModel for the patient list screen
@MainActor
final class PatientListViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var patients: [PatientSummary] = []
    @Published private(set) var isLoading = false
    @Published var error: String?
    @Published var searchText = "" {
        didSet { updateFilteredPatients() }
    }
    @Published var sortOption: PatientSortOption = .name {
        didSet { updateFilteredPatients() }
    }
    @Published private(set) var filteredPatients: [PatientSummary] = []

    // MARK: - Dependencies

    private let service: ClinicianServiceProtocol
    private let clinicianId: UUID

    // MARK: - Initialization

    init(service: ClinicianServiceProtocol, clinicianId: UUID) {
        self.service = service
        self.clinicianId = clinicianId
    }

    // MARK: - Public Methods

    /// Loads the patient list from the service
    func loadData() async {
        isLoading = true
        error = nil
        do {
            patients = try await service.fetchPatients(for: clinicianId)
            updateFilteredPatients()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Pull-to-refresh support
    func refresh() async {
        await loadData()
    }

    // MARK: - Static Helpers (pure functions for testability)

    /// Filters patients by search text (case-insensitive name match)
    nonisolated static func filterPatients(_ patients: [PatientSummary], searchText: String) -> [PatientSummary] {
        guard !searchText.isEmpty else { return patients }
        let query = searchText.lowercased()
        return patients.filter { $0.name.lowercased().contains(query) }
    }

    /// Sorts patients by the given option
    nonisolated static func sortPatients(_ patients: [PatientSummary], by option: PatientSortOption) -> [PatientSummary] {
        switch option {
        case .name:
            return patients.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .lastActive:
            return patients.sorted { ($0.lastActiveDate ?? .distantPast) > ($1.lastActiveDate ?? .distantPast) }
        case .avgHeartRate:
            return patients.sorted { ($0.avgHeartRate7d ?? Double.greatestFiniteMagnitude) < ($1.avgHeartRate7d ?? Double.greatestFiniteMagnitude) }
        }
    }

    // MARK: - Private Methods

    private func updateFilteredPatients() {
        let filtered = Self.filterPatients(patients, searchText: searchText)
        filteredPatients = Self.sortPatients(filtered, by: sortOption)
    }
}
