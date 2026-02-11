import Foundation

/// 7-day overview data for a patient
struct PatientOverview {
    let avgHeartRate7d: Double
    let avgRMSSD7d: Double?
    let avgSDNN7d: Double?
    let sessionCount7d: Int
    let totalMinutes7d: Int
    let dailyHeartRates: [(date: Date, value: Double)]
    let dailyRMSSD: [(date: Date, value: Double)]
}

/// Combined patient profile and overview for the detail screen
struct PatientDetail {
    var profile: UserProfile
    let overview: PatientOverview?
}
