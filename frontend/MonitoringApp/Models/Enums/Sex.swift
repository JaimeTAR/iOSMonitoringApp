import Foundation

/// Biological sex for profile data
/// Maps to user_profile.sex in database
enum Sex: String, Codable, CaseIterable {
    case male
    case female
    case other
    case preferNotToSay = "prefer_not_to_say"
}
