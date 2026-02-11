import Foundation

/// Authentication-related errors with user-friendly messages
enum AuthError: LocalizedError {
    case invalidInvitationCode
    case invitationCodeExpired
    case invitationCodeUsed
    case invitationCodeRevoked
    case registrationFailed(String)
    case signInFailed(String)
    case signOutFailed(String)
    case networkError
    case unauthorized
    case userNotFound
    case profileCreationFailed(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInvitationCode:
            return "Invalid invitation code. Please check and try again."
        case .invitationCodeExpired:
            return "This invitation code has expired. Please request a new one from your clinician."
        case .invitationCodeUsed:
            return "This invitation code has already been used."
        case .invitationCodeRevoked:
            return "This invitation code has been revoked. Please request a new one."
        case .registrationFailed(let reason):
            return "Registration failed: \(reason)"
        case .signInFailed(let reason):
            return "Sign in failed: \(reason)"
        case .signOutFailed(let reason):
            return "Sign out failed: \(reason)"
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .userNotFound:
            return "User not found."
        case .profileCreationFailed(let reason):
            return "Failed to create profile: \(reason)"
        case .unknown(let message):
            return message
        }
    }
}
