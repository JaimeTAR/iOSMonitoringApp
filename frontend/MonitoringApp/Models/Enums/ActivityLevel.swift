import Foundation

/// Activity level classification
/// Maps to user_profile.activity_level in database
enum ActivityLevel: String, Codable, CaseIterable {
    case bajo
    case moderado
    case alto
}
