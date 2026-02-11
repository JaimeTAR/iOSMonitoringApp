import Foundation
import Combine
import Supabase
#if canImport(UIKit)
import UIKit
#endif

/// Filter options for invitation codes
enum InvitationStatusFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case used = "Used"
    case expired = "Expired"
}

/// Status counts for the invitation counter row
struct InvitationStatusCounts {
    let pending: Int
    let used: Int
    let expired: Int
}

/// ViewModel for the invitation code management screen
@MainActor
final class InvitationManagerViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var invitationCodes: [InvitationCode] = []
    @Published private(set) var filteredCodes: [InvitationCode] = []
    @Published private(set) var statusCounts = InvitationStatusCounts(pending: 0, used: 0, expired: 0)
    @Published var statusFilter: InvitationStatusFilter = .all {
        didSet { updateFilteredCodes() }
    }
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

    /// Loads all invitation codes (excludes revoked)
    func loadData() async {
        isLoading = true
        error = nil
        do {
            let allCodes = try await service.fetchInvitationCodes(for: clinicianId)
            invitationCodes = allCodes.filter { $0.status != .revoked }
            statusCounts = Self.computeStatusCounts(invitationCodes)
            updateFilteredCodes()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Generates a new invitation code
    func generateCode() async {
        error = nil
        do {
            let newCode = try await service.generateInvitationCode(for: clinicianId)
            invitationCodes.insert(newCode, at: 0)
            statusCounts = Self.computeStatusCounts(invitationCodes)
            updateFilteredCodes()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Revokes a pending invitation code
    func revokeCode(id: UUID) async {
        error = nil
        do {
            try await service.revokeInvitationCode(id: id)
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Copies the code text to the system clipboard
    func copyToClipboard(code: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #endif
    }

    /// Pull-to-refresh support
    func refresh() async {
        await loadData()
    }

    // MARK: - Static Helpers (pure functions for testability)

    /// Computes status counts from a list of invitation codes
    nonisolated static func computeStatusCounts(_ codes: [InvitationCode]) -> InvitationStatusCounts {
        InvitationStatusCounts(
            pending: codes.filter { $0.status == .pending }.count,
            used: codes.filter { $0.status == .used }.count,
            expired: codes.filter { $0.status == .expired }.count
        )
    }

    /// Filters codes by the selected status filter
    nonisolated static func filterCodes(_ codes: [InvitationCode], by filter: InvitationStatusFilter) -> [InvitationCode] {
        switch filter {
        case .all: return codes
        case .pending: return codes.filter { $0.status == .pending }
        case .used: return codes.filter { $0.status == .used }
        case .expired: return codes.filter { $0.status == .expired }
        }
    }

    /// Whether the revoke action is available for a given code
    nonisolated static func canRevoke(_ code: InvitationCode) -> Bool {
        code.status == .pending
    }

    // MARK: - Private Methods

    private func updateFilteredCodes() {
        filteredCodes = Self.filterCodes(invitationCodes, by: statusFilter)
    }
}
