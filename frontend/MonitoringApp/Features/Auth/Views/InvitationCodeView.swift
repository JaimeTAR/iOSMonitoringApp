import SwiftUI

/// View for entering and validating invitation code
struct InvitationCodeView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onBack: () -> Void
    
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
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
            
            Spacer()
            
            // Content
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "ticket.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.appPrimary)
                
                // Title and description
                VStack(spacing: 8) {
                    Text("Enter Invitation Code")
                        .font(.appTitle)
                        .foregroundColor(.appTextPrimary)
                    
                    Text("Enter the 5-digit code provided by your clinician")
                        .font(.appBody)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Code input field
                TextField("", text: $viewModel.invitationCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.appSurface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
                    .focused($isCodeFieldFocused)
                    .onChange(of: viewModel.invitationCode) { _, newValue in
                        // Limit to 5 characters and uppercase
                        let filtered = String(newValue.uppercased().prefix(5))
                        if filtered != newValue {
                            viewModel.invitationCode = filtered
                        }
                    }
                
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
                    .background(Color.statusRed.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Submit button
            PrimaryButton(
                title: "Continue",
                action: {
                    Task {
                        await viewModel.validateInvitationCode()
                    }
                },
                isLoading: viewModel.state == .validatingCode,
                isDisabled: !viewModel.canValidateCode
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color.appBackground)
        .onAppear {
            isCodeFieldFocused = true
        }
    }
}

#Preview {
    InvitationCodeView(
        viewModel: AuthViewModel(),
        onBack: {}
    )
}
