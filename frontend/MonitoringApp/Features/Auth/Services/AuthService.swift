import Foundation
import Combine
import Supabase

/// Service handling authentication operations
@MainActor
final class AuthService: ObservableObject, AuthServiceProtocol {
    @Published private(set) var currentUser: User?
    
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    init() {
        Task {
            await refreshSession()
        }
    }
    
    // MARK: - Session Management
    
    func refreshSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
        } catch {
            currentUser = nil
        }
    }
    
    // MARK: - Invitation Code Validation
    
    func validateInvitationCode(_ code: String) async throws -> InvitationCode {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard trimmedCode.count == 5 else {
            throw AuthError.invalidInvitationCode
        }
        
        do {
            let invitationCodes: [InvitationCode] = try await supabase
                .from("clinician_invitation_codes")
                .select()
                .eq("code", value: trimmedCode)
                .execute()
                .value
            
            guard let invitationCode = invitationCodes.first else {
                throw AuthError.invalidInvitationCode
            }
            
            // Check status
            switch invitationCode.status {
            case .used:
                throw AuthError.invitationCodeUsed
            case .expired:
                throw AuthError.invitationCodeExpired
            case .revoked:
                throw AuthError.invitationCodeRevoked
            case .pending:
                // Check if expired by date
                if invitationCode.expiresAt < Date() {
                    throw AuthError.invitationCodeExpired
                }
                return invitationCode
            }
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError
        }
    }
    
    // MARK: - Registration
    
    func register(email: String, password: String, invitationCode: InvitationCode) async throws -> User {
        do {
            // 1. Create user account
            let authResponse = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            let user = authResponse.user
            
            // 2. Create or update user profile with patient role
            // Using upsert to handle case where database trigger may have already created profile
            let now = Date()
            let profile = NewUserProfile(
                userId: user.id,
                role: .patient,
                createdAt: now,
                updatedAt: now
            )
            
            try await supabase
                .from("user_profile")
                .upsert(profile, onConflict: "user_id")
                .execute()
            
            // 3. Mark invitation code as used
            try await supabase
                .from("clinician_invitation_codes")
                .update(["status": InvitationStatus.used.rawValue])
                .eq("id", value: invitationCode.id)
                .execute()
            
            // 4. Create clinician-patient relationship
            let relationship = NewClinicianPatient(
                clinicianId: invitationCode.clinicianId,
                patientId: user.id,
                invitationCodeId: invitationCode.id,
                startDate: now,
                status: .activo,
                createdAt: now
            )
            
            try await supabase
                .from("clinician_patients")
                .insert(relationship)
                .execute()
            
            currentUser = user
            return user
            
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.registrationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws -> User {
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            currentUser = session.user
            return session.user
        } catch {
            throw AuthError.signInFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        do {
            try await supabase.auth.signOut()
            currentUser = nil
        } catch {
            throw AuthError.signOutFailed(error.localizedDescription)
        }
    }
}

// MARK: - Helper Models for Insert Operations

/// Model for creating a new user profile (without id which is auto-generated)
private struct NewUserProfile: Codable {
    let userId: UUID
    let role: UserRole
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Model for creating a new clinician-patient relationship
private struct NewClinicianPatient: Codable {
    let clinicianId: UUID
    let patientId: UUID
    let invitationCodeId: UUID
    let startDate: Date
    let status: RelationshipStatus
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case clinicianId = "clinician_id"
        case patientId = "patient_id"
        case invitationCodeId = "invitation_code_id"
        case startDate = "start_date"
        case status
        case createdAt = "created_at"
    }

}