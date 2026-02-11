import Foundation

/// Clinician information for display purposes
struct ClinicianInfo: Codable, Identifiable {
    let id: UUID
    let email: String?
    let name: String?
    
    /// Display name for the clinician
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        if let email = email {
            return email
        }
        return "Unknown Clinician"
    }
}
