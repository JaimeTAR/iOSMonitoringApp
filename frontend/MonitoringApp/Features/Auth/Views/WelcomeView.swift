import SwiftUI

/// Welcome screen displayed on first launch
struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // App branding
            VStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.appPrimary)
                
                Text("Monitoring App")
                    .font(.appLargeTitle)
                    .foregroundColor(.appTextPrimary)
                
                Text("Track your heart rate and wellness with your clinician")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                PrimaryButton(title: "Get Started", action: onGetStarted)
                
                Button(action: onSignIn) {
                    Text("Already have an account? Sign In")
                        .font(.appHeadline)
                        .foregroundColor(.appPrimary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color.appBackground)
    }
}

#Preview {
    WelcomeView(
        onGetStarted: {},
        onSignIn: {}
    )
}
