import SwiftUI
import Supabase

/// Root view that handles authentication state routing
/// Routes to AuthFlow when unauthenticated, MainTabView for patients,
/// ClinicianTabView for clinicians
struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var isCheckingAuth = true
    @State private var needsProfileSetup = false
    @State private var userRole: UserRole?
    
    var body: some View {
        Group {
            if isCheckingAuth {
                splashView
            } else if authViewModel.isAuthenticated {
                if needsProfileSetup, let userId = authViewModel.currentUser?.id {
                    ProfileSetupView(userId: userId) {
                        needsProfileSetup = false
                        Task { await fetchUserRole() }
                    }
                } else {
                    authenticatedView
                }
            } else {
                AuthFlowView()
                    .environmentObject(authViewModel)
            }
        }
        .task {
            await checkAuthState()
        }
        .onChange(of: authViewModel.state) { _, newState in
            if newState == .authenticated {
                Task {
                    await checkProfileSetup()
                }
            } else if newState == .unauthenticated {
                userRole = nil
            }
        }
    }
    
    // MARK: - Authenticated View (Role-Based Routing)
    
    @ViewBuilder
    private var authenticatedView: some View {
        switch RootView.resolveRoute(for: userRole) {
        case .clinician:
            if let userId = authViewModel.currentUser?.id {
                ClinicianTabView(
                    service: ClinicianService(),
                    clinicianId: userId,
                    onSignOut: {
                        Task { await authViewModel.signOut() }
                    }
                )
            }
        case .patient:
            MainTabView(authViewModel: authViewModel)
        }
    }
    
    /// Pure function: maps a UserRole? to the destination route.
    /// Defaults to `.patient` when role is nil.
    static func resolveRoute(for role: UserRole?) -> UserRole {
        role ?? .patient
    }
    
    // MARK: - Splash View
    
    private var splashView: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.appPrimary)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .appPrimary))
            }
        }
    }
    
    // MARK: - Auth Check
    
    private func checkAuthState() async {
        await authViewModel.checkAuthState()
        
        if authViewModel.isAuthenticated {
            await checkProfileSetup()
        }
        
        isCheckingAuth = false
    }
    
    private func checkProfileSetup() async {
        guard let userId = authViewModel.currentUser?.id else {
            needsProfileSetup = false
            return
        }
        
        do {
            let profiles: [UserProfile] = try await supabase
                .from("user_profile")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if let profile = profiles.first {
                needsProfileSetup = profile.age == nil || profile.sex == nil
                userRole = profile.role
            } else {
                needsProfileSetup = true
                userRole = nil
            }
        } catch {
            // Profile fetch failed — sign out per Requirement 1.3
            await authViewModel.signOut()
        }
    }
    
    private func fetchUserRole() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        do {
            let profile: UserProfile = try await supabase
                .from("user_profile")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
            userRole = profile.role
        } catch {
            await authViewModel.signOut()
        }
    }
}

#Preview {
    RootView()
}

