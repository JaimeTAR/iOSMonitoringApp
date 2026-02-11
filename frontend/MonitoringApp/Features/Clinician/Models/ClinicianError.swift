import Foundation

/// Errors specific to clinician feature operations
enum ClinicianError: LocalizedError {
    case notAuthenticated
    case profileNotFound
    case fetchPatientsFailed(String)
    case fetchSamplesFailed(String)
    case fetchInvitationsFailed(String)
    case generateCodeFailed(String)
    case revokeCodeFailed(String)
    case pdfGenerationFailed(String)
    case updateRestingHRFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .profileNotFound:
            return "Profile not found"
        case .fetchPatientsFailed(let msg):
            return "Failed to load patients: \(msg)"
        case .fetchSamplesFailed(let msg):
            return "Failed to load data: \(msg)"
        case .fetchInvitationsFailed(let msg):
            return "Failed to load invitations: \(msg)"
        case .generateCodeFailed(let msg):
            return "Failed to generate code: \(msg)"
        case .revokeCodeFailed(let msg):
            return "Failed to revoke code: \(msg)"
        case .pdfGenerationFailed(let msg):
            return "Failed to generate PDF: \(msg)"
        case .updateRestingHRFailed(let msg):
            return "Failed to update resting heart rate: \(msg)"
        }
    }
}
