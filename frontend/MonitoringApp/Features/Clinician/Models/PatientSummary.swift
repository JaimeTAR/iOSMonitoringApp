import Foundation

/// Aggregated patient data for the patient list view
struct PatientSummary: Identifiable {
    let id: UUID
    let name: String
    let lastActiveDate: Date?
    let avgHeartRate7d: Double?
    let avgRMSSD7d: Double?
    let trend: HealthTrend
}
