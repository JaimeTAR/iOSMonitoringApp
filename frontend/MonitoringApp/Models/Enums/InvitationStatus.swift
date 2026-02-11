import SwiftUI

/// Status of a clinician invitation code
/// Maps to clinician_invitation_codes.status in database
enum InvitationStatus: String, Codable, CaseIterable {
    case pending
    case used
    case expired
    case revoked

    /// Badge color for invitation status display (Requirement 13.3)
    var badgeColor: Color {
        switch self {
        case .pending: return .statusYellow
        case .used: return .statusGreen
        case .expired: return .statusRed
        case .revoked: return .gray
        }
    }
}
