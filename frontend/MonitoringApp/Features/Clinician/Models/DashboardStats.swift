import Foundation

/// Aggregate metrics displayed on the clinician dashboard stat cards
struct DashboardStats {
    let totalActivePatients: Int
    let patientsActiveToday: Int
    let pendingInvitations: Int
}
