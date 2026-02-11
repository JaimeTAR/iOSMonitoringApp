import Foundation

/// Clinician invitation code for patient registration
/// Maps to clinician_invitation_codes table in database
struct InvitationCode: Codable, Identifiable {
    let id: UUID
    let clinicianId: UUID
    let code: String
    let status: InvitationStatus
    let createdAt: Date
    let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case clinicianId = "clinician_id"
        case code
        case status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
    
    /// Checks if the invitation code is valid (pending status and not expired)
    var isValid: Bool {
        status == .pending && expiresAt > Date()
    }
}
