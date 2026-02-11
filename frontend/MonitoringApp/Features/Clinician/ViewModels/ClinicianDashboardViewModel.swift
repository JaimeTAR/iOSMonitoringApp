import Foundation
import Combine
import Supabase

/// ViewModel for the clinician dashboard screen
@MainActor
final class ClinicianDashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var stats: DashboardStats?
    @Published private(set) var needsAttentionItems: [NeedsAttentionItem] = []
    @Published private(set) var recentActivity: [RecentActivityItem] = []
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

    /// Loads all dashboard data: stats, needs-attention, and recent activity
    func loadData() async {
        isLoading = true
        error = nil
        do {
            async let fetchedStats = service.fetchDashboardStats(for: clinicianId)
            async let fetchedAttention = service.fetchNeedsAttention(for: clinicianId)
            async let fetchedActivity = service.fetchRecentActivity(for: clinicianId, limit: 10)

            stats = try await fetchedStats
            needsAttentionItems = try await fetchedAttention
            recentActivity = try await fetchedActivity
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Pull-to-refresh support
    func refresh() async {
        await loadData()
    }
}
