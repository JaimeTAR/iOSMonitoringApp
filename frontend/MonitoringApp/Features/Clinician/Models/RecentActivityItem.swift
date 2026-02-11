import Foundation

/// A monitoring session entry in the dashboard recent activity feed
struct RecentActivityItem: Identifiable {
    let id: UUID
    let patientId: UUID
    let patientName: String
    let sessionDate: Date
    let durationMinutes: Int
    let avgHeartRate: Double
}
