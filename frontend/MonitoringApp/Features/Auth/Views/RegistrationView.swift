import SwiftUI

/// View for user registration with email and password
struct RegistrationView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onBack: () -> Void
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email, password, confirmPassword
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
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appPrimary)
                        .padding(.top, 32)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Create Account")
                            .font(.appTitle)
                            .foregroundColor(.appTextPrimary)
                        
                        Text("Enter your email and create a password")
                            .font(.appBody)
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
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
                                        .stroke(emailBorderColor, lineWidth: 1)
                                )
                                .focused($focusedField, equals: .email)
                            
                            if !viewModel.email.isEmpty && !viewModel.isValidEmail {
                                Text("Please enter a valid email address")
                                    .font(.appCaption)
                                    .foregroundColor(.statusRed)
                            }
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.appFootnote)
                                .foregroundColor(.appTextSecondary)
                            
                            SecureField("Minimum 8 characters", text: $viewModel.password)
                                .font(.appBody)
                                .textContentType(.newPassword)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .background(Color.appSurface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(passwordBorderColor, lineWidth: 1)
                                )
                                .focused($focusedField, equals: .password)
                            
                            if !viewModel.password.isEmpty && !viewModel.isValidPassword {
                                Text("Password must be at least 8 characters")
                                    .font(.appCaption)
                                    .foregroundColor(.statusRed)
                            }
                        }
                        
                        // Confirm password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.appFootnote)
                                .foregroundColor(.appTextSecondary)
                            
                            SecureField("Re-enter password", text: $viewModel.confirmPassword)
                                .font(.appBody)
                                .textContentType(.newPassword)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .background(Color.appSurface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(confirmPasswordBorderColor, lineWidth: 1)
                                )
                                .focused($focusedField, equals: .confirmPassword)
                            
                            if !viewModel.confirmPassword.isEmpty && !viewModel.passwordsMatch {
                                Text("Passwords do not match")
                                    .font(.appCaption)
                                    .foregroundColor(.statusRed)
                            }
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
                    
                    // Register button
                    PrimaryButton(
                        title: "Create Account",
                        action: {
                            Task {
                                await viewModel.register()
                            }
                        },
                        isLoading: viewModel.state == .registering,
                        isDisabled: !viewModel.canRegister
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
    
    // MARK: - Border Colors
    
    private var emailBorderColor: Color {
        if viewModel.email.isEmpty {
            return Color.appBorder
        }
        return viewModel.isValidEmail ? Color.statusGreen : Color.statusRed
    }
    
    private var passwordBorderColor: Color {
        if viewModel.password.isEmpty {
            return Color.appBorder
        }
        return viewModel.isValidPassword ? Color.statusGreen : Color.statusRed
    }
    
    private var confirmPasswordBorderColor: Color {
        if viewModel.confirmPassword.isEmpty {
            return Color.appBorder
        }
        return viewModel.passwordsMatch ? Color.statusGreen : Color.statusRed
    }
}

#Preview {
    RegistrationView(
        viewModel: AuthViewModel(),
        onBack: {}
    )
}
