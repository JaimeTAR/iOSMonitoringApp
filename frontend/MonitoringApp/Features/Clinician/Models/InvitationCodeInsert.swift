import Foundation

/// Codable struct for inserting a new invitation code into Supabase
/// Excludes the auto-generated `id` field
struct InvitationCodeInsert: Codable {
    let clinicianId: UUID
    let code: String
    let status: InvitationStatus
    let createdAt: Date
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case clinicianId = "clinician_id"
        case code
        case status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}
