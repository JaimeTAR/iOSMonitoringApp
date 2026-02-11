import Foundation

/// Protocol defining all clinician-specific data operations
protocol ClinicianServiceProtocol {
    // MARK: - Patient Data

    /// Fetches all patients linked to the clinician with trend indicators
    func fetchPatients(for clinicianId: UUID) async throws -> [PatientSummary]

    /// Fetches detailed patient profile and 7-day overview
    func fetchPatientDetail(patientId: UUID) async throws -> PatientDetail

    /// Fetches physiological samples for a patient within a date range
    func fetchPatientSamples(patientId: UUID, from: Date, to: Date) async throws -> [PhysiologicalSample]

    // MARK: - Dashboard

    /// Computes dashboard stat card values
    func fetchDashboardStats(for clinicianId: UUID) async throws -> DashboardStats

    /// Identifies patients needing clinician attention
    func fetchNeedsAttention(for clinicianId: UUID) async throws -> [NeedsAttentionItem]

    /// Fetches the most recent monitoring sessions across all linked patients
    func fetchRecentActivity(for clinicianId: UUID, limit: Int) async throws -> [RecentActivityItem]

    // MARK: - Invitations

    /// Fetches all invitation codes for the clinician
    func fetchInvitationCodes(for clinicianId: UUID) async throws -> [InvitationCode]

    /// Generates a new 5-character invitation code with pending status and 7-day expiry
    func generateInvitationCode(for clinicianId: UUID) async throws -> InvitationCode

    /// Revokes a pending invitation code
    func revokeInvitationCode(id: UUID) async throws

    // MARK: - Patient Updates

    /// Updates the resting heart rate for a patient
    func updatePatientRestingHeartRate(patientId: UUID, bpm: Double) async throws

    // MARK: - Profile

    /// Fetches the clinician's user profile
    func fetchClinicianProfile(userId: UUID) async throws -> UserProfile
}
