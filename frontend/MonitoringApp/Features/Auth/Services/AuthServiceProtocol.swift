import Foundation
import Combine
import Supabase

/// Protocol defining authentication service capabilities
protocol AuthServiceProtocol: ObservableObject {
    /// The currently authenticated user, if any
    var currentUser: User? { get }
    
    /// Whether a user is currently authenticated
    var isAuthenticated: Bool { get }
    
    /// Validates an invitation code
    /// - Parameter code: The 5-digit invitation code
    /// - Returns: The validated InvitationCode if valid
    /// - Throws: AuthError if code is invalid, expired, used, or revoked
    func validateInvitationCode(_ code: String) async throws -> InvitationCode
    
    /// Registers a new user with an invitation code
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - invitationCode: The validated invitation code
    /// - Returns: The created User
    /// - Throws: AuthError if registration fails
    func register(email: String, password: String, invitationCode: InvitationCode) async throws -> User
    
    /// Signs in an existing user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: The authenticated User
    /// - Throws: AuthError if sign in fails
    func signIn(email: String, password: String) async throws -> User
    
    /// Signs out the current user
    /// - Throws: AuthError if sign out fails
    func signOut() async throws
    
    /// Refreshes the current session and user state
    func refreshSession() async
}
