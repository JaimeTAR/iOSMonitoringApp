import Foundation

/// Clinician-patient relationship model
/// Maps to clinician_patients table in database
struct ClinicianPatient: Codable, Identifiable {
    let id: UUID
    let clinicianId: UUID
    let patientId: UUID
    let invitationCodeId: UUID?
    let startDate: Date
    let endDate: Date?
    let status: RelationshipStatus
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case clinicianId = "clinician_id"
        case patientId = "patient_id"
        case invitationCodeId = "invitation_code_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case status
        case createdAt = "created_at"
    }
    
    /// Checks if the relationship is currently active
    var isActive: Bool {
        status == .activo && endDate == nil
    }
}

/// Relationship status enum
enum RelationshipStatus: String, Codable {
    case activo
    case inactivo
}
