import SwiftUI

/// Coordinates the authentication flow navigation
struct AuthFlowView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var currentScreen: AuthScreen = .welcome
    
    private enum AuthScreen {
        case welcome
        case invitationCode
        case registration
        case signIn
    }
    
    var body: some View {
        Group {
            switch currentScreen {
            case .welcome:
                WelcomeView(
                    onGetStarted: { currentScreen = .invitationCode },
                    onSignIn: { currentScreen = .signIn }
                )
                
            case .invitationCode:
                InvitationCodeView(
                    viewModel: viewModel,
                    onBack: {
                        viewModel.resetToInitial()
                        currentScreen = .welcome
                    }
                )
                .onChange(of: viewModel.state) { _, newState in
                    if case .codeValidated = newState {
                        currentScreen = .registration
                    }
                }
                
            case .registration:
                RegistrationView(
                    viewModel: viewModel,
                    onBack: {
                        viewModel.goBackToCodeEntry()
                        currentScreen = .invitationCode
                    }
                )
                
            case .signIn:
                SignInView(
                    viewModel: viewModel,
                    onBack: {
                        viewModel.resetToInitial()
                        currentScreen = .welcome
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentScreen)
    }
}

/// Simple sign in view for existing users
struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onBack: () -> Void
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email, password
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.appHeadline)
                            .foregroundColor(.appPrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Content
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "person.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appPrimary)
                        .padding(.top, 32)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Welcome Back")
                            .font(.appTitle)
                            .foregroundColor(.appTextPrimary)
                        
                        Text("Sign in to your account")
                            .font(.appBody)
                            .foregroundColor(.appTextSecondary)
                    }
                    
                    // Form fields
                    VStack(spacing: 16) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.appFootnote)
                                .foregroundColor(.appTextSecondary)
                            
                            TextField("your@email.com", text: $viewModel.email)
                                .font(.appBody)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .background(Color.appSurface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appBorder, lineWidth: 1)
                                )
                                .focused($focusedField, equals: .email)
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.appFootnote)
                                .foregroundColor(.appTextSecondary)
                            
                            SecureField("Enter password", text: $viewModel.password)
                                .font(.appBody)
                                .textContentType(.password)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .background(Color.appSurface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appBorder, lineWidth: 1)
                                )
                                .focused($focusedField, equals: .password)
                        }
                    }
                    .padding(.top, 8)
                    
                    // Error message
                    if viewModel.showError, let errorMessage = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.statusRed)
                            Text(errorMessage)
                                .font(.appFootnote)
                                .foregroundColor(.statusRed)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.statusRed.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Sign in button
                    PrimaryButton(
                        title: "Sign In",
                        action: {
                            Task {
                                await viewModel.signIn()
                            }
                        },
                        isLoading: viewModel.isLoading,
                        isDisabled: !viewModel.isValidEmail || viewModel.password.isEmpty
                    )
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .background(Color.appBackground)
        .onAppear {
            focusedField = .email
        }
    }
}

#Preview("Auth Flow") {
    AuthFlowView()
        .environmentObject(AuthViewModel())
}

#Preview("Sign In") {
    SignInView(
        viewModel: AuthViewModel(),
        onBack: {}
    )
}
