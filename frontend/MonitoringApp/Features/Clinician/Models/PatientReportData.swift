import Foundation

/// Data used to render and export a patient summary report
struct PatientReportData {
    let patientName: String
    let reportPeriod: String
    let generatedDate: Date
    let avgHeartRate: Double?
    let avgRMSSD: Double?
    let avgSDNN: Double?
    let sessionCount: Int
    let totalMonitoringMinutes: Int
}
