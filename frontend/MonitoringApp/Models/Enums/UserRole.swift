import Foundation

/// User role in the system
/// Maps to user_profile.role in database
enum UserRole: String, Codable, CaseIterable {
    case patient
    case clinician
}
