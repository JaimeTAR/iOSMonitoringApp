import Foundation
import Combine
import Supabase

/// Authentication state for the auth flow
enum AuthState: Equatable {
    case unauthenticated
    case validatingCode
    case codeValidated(InvitationCode)
    case registering
    case authenticated
    
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated),
             (.validatingCode, .validatingCode),
             (.registering, .registering),
             (.authenticated, .authenticated):
            return true
        case (.codeValidated(let lhsCode), .codeValidated(let rhsCode)):
            return lhsCode.id == rhsCode.id
        default:
            return false
        }
    }
}

/// ViewModel managing authentication state and operations
@MainActor
final class AuthViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var state: AuthState = .unauthenticated
    @Published private(set) var currentUser: User?
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // Input fields
    @Published var invitationCode: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    
    // MARK: - Dependencies
    
    private let authService: AuthService
    
    // MARK: - Computed Properties
    
    var isAuthenticated: Bool {
        state == .authenticated
    }
    
    var isLoading: Bool {
        state == .validatingCode || state == .registering
    }
    
    var canValidateCode: Bool {
        invitationCode.trimmingCharacters(in: .whitespacesAndNewlines).count == 5
    }
    
    var canRegister: Bool {
        isValidEmail && isValidPassword && passwordsMatch
    }
    
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    var isValidPassword: Bool {
        password.count >= 8
    }
    
    var passwordsMatch: Bool {
        password == confirmPassword && !password.isEmpty
    }
    
    // MARK: - Initialization
    
    init(authService: AuthService? = nil) {
        self.authService = authService ?? AuthService()
        
        Task {
            await checkAuthState()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check current authentication state
    func checkAuthState() async {
        await authService.refreshSession()
        if authService.isAuthenticated {
            currentUser = authService.currentUser
            state = .authenticated
        } else {
            state = .unauthenticated
        }
    }
    
    /// Validate the entered invitation code
    func validateInvitationCode() async {
        guard canValidateCode else { return }
        
        state = .validatingCode
        clearError()
        
        do {
            let validCode = try await authService.validateInvitationCode(invitationCode)
            state = .codeValidated(validCode)
        } catch let error as AuthError {
            showError(error.errorDescription ?? "Invalid code")
            state = .unauthenticated
        } catch {
            showError("An unexpected error occurred")
            state = .unauthenticated
        }
    }
    
    /// Register a new user with the validated invitation code
    func register() async {
        guard case .codeValidated(let validCode) = state else { return }
        guard canRegister else { return }
        
        state = .registering
        clearError()
        
        do {
            let user = try await authService.register(
                email: email,
                password: password,
                invitationCode: validCode
            )
            currentUser = user
            state = .authenticated
            clearInputs()
        } catch let error as AuthError {
            showError(error.errorDescription ?? "Registration failed")
            state = .codeValidated(validCode)
        } catch {
            showError("An unexpected error occurred")
            state = .codeValidated(validCode)
        }
    }
    
    /// Sign in an existing user
    func signIn() async {
        guard isValidEmail, !password.isEmpty else { return }
        
        state = .validatingCode // Reuse for loading state
        clearError()
        
        do {
            let user = try await authService.signIn(email: email, password: password)
            currentUser = user
            state = .authenticated
            clearInputs()
        } catch let error as AuthError {
            showError(error.errorDescription ?? "Sign in failed")
            state = .unauthenticated
        } catch {
            showError("An unexpected error occurred")
            state = .unauthenticated
        }
    }
    
    /// Sign out the current user
    func signOut() async {
        do {
            try await authService.signOut()
            currentUser = nil
            state = .unauthenticated
            clearInputs()
        } catch let error as AuthError {
            showError(error.errorDescription ?? "Sign out failed")
        } catch {
            showError("An unexpected error occurred")
        }
    }
    
    /// Reset to initial state (e.g., when user wants to go back)
    func resetToInitial() {
        state = .unauthenticated
        clearInputs()
        clearError()
    }
    
    /// Go back from registration to code entry
    func goBackToCodeEntry() {
        state = .unauthenticated
        email = ""
        password = ""
        confirmPassword = ""
        clearError()
    }
    
    // MARK: - Private Methods
    
    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func clearError() {
        errorMessage = nil
        showError = false
    }
    
    private func clearInputs() {
        invitationCode = ""
        email = ""
        password = ""
        confirmPassword = ""
    }
}
