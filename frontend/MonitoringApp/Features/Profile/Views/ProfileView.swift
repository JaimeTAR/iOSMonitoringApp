import SwiftUI

/// View displaying user profile information with edit and sign out options
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingSignOutAlert = false
    
    let onSignOut: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                    } else if let profile = viewModel.profile {
                        // Profile Header
                        ProfileHeaderSection(profile: profile)
                        
                        // Clinician Info
                        if let clinician = viewModel.clinician {
                            ClinicianSection(clinician: clinician)
                        }
                        
                        // Profile Details
                        ProfileDetailsSection(profile: profile)
                        
                        // Baselines Section
                        BaselinesSection(profile: profile)
                        
                        // Actions
                        VStack(spacing: 12) {
                            NavigationLink {
                                ProfileEditView(viewModel: viewModel)
                            } label: {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Edit Profile")
                                }
                                .font(.appHeadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.appSurface)
                                .foregroundColor(.appPrimary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appPrimary, lineWidth: 1)
                                )
                            }
                            
                            Button {
                                showingSignOutAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Sign Out")
                                }
                                .font(.appHeadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.appSurface)
                                .foregroundColor(.statusRed)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.statusRed, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.top, 8)
                    } else {
                        // No profile state
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 60))
                                .foregroundColor(.appTextSecondary)
                            
                            Text("Profile not found")
                                .font(.appHeadline)
                                .foregroundColor(.appTextPrimary)
                            
                            Text("Please complete your profile setup")
                                .font(.appBody)
                                .foregroundColor(.appTextSecondary)
                        }
                        .padding(.top, 100)
                    }
                    
                    // Error Message
                    if let error = viewModel.error {
                        Text(error.localizedDescription)
                            .font(.appCaption)
                            .foregroundColor(.statusRed)
                            .padding()
                            .background(Color.statusRed.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(24)
            }
            .background(Color.appBackground)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    onSignOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .task {
                await viewModel.loadProfile()
            }
            .refreshable {
                await viewModel.loadProfile()
            }
        }
    }
}

// MARK: - Profile Header Section

private struct ProfileHeaderSection: View {
    let profile: UserProfile
    
    var body: some View {
        VStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.appPrimary.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.appPrimary)
                )
            
            // Role badge
            Text(profile.role.rawValue.capitalized)
                .font(.appCaption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.appPrimary)
                .cornerRadius(12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Clinician Section

private struct ClinicianSection: View {
    let clinician: ClinicianInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Clinician")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.statusBlue.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "stethoscope")
                            .foregroundColor(.statusBlue)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(clinician.displayName)
                        .font(.appBody)
                        .foregroundColor(.appTextPrimary)
                    
                    Text("Healthcare Provider")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.appSurface)
            .cornerRadius(12)
        }
    }
}

// MARK: - Profile Details Section

private struct ProfileDetailsSection: View {
    let profile: UserProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Information")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            VStack(spacing: 0) {
                ProfileDetailRow(label: "Name", value: profile.name ?? "Not set")
                Divider().padding(.leading, 16)
                
                ProfileDetailRow(label: "Age", value: profile.age.map { "\($0) years" } ?? "Not set")
                Divider().padding(.leading, 16)
                
                ProfileDetailRow(label: "Sex", value: profile.sex?.displayName ?? "Not set")
                Divider().padding(.leading, 16)
                
                ProfileDetailRow(label: "Height", value: profile.heightCm.map { String(format: "%.1f cm", $0) } ?? "Not set")
                Divider().padding(.leading, 16)
                
                ProfileDetailRow(label: "Weight", value: profile.weightKg.map { String(format: "%.1f kg", $0) } ?? "Not set")
                Divider().padding(.leading, 16)
                
                ProfileDetailRow(label: "Exercise Frequency", value: profile.exerciseFrequency.map { "\($0)x per week" } ?? "Not set")
                Divider().padding(.leading, 16)
                
                ProfileDetailRow(label: "Activity Level", value: profile.activityLevel?.displayName ?? "Not set")
            }
            .background(Color.appSurface)
            .cornerRadius(12)
        }
    }
}

// MARK: - Baselines Section

private struct BaselinesSection: View {
    let profile: UserProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Physiological Baselines")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            VStack(spacing: 0) {
                if let restingHR = profile.restingHeartRate {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resting Heart Rate")
                                .font(.appSubheadline)
                                .foregroundColor(.appTextSecondary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.0f", restingHR))
                                    .font(.appTitle2)
                                    .foregroundColor(.appPrimary)
                                
                                Text("BPM")
                                    .font(.appCaption)
                                    .foregroundColor(.appTextSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(.appPrimary)
                    }
                    .padding()
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resting Heart Rate")
                                .font(.appSubheadline)
                                .foregroundColor(.appTextSecondary)
                            
                            Text("Ask your doctor to set your resting heart rate")
                                .font(.appBody)
                                .foregroundColor(.appTextSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding()
                }
            }
            .background(Color.appSurface)
            .cornerRadius(12)
        }
    }
}

// MARK: - Profile Detail Row

private struct ProfileDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.appBody)
                .foregroundColor(.appTextSecondary)
            
            Spacer()
            
            Text(value)
                .font(.appBody)
                .foregroundColor(value == "Not set" ? .appTextSecondary : .appTextPrimary)
        }
        .padding()
    }
}

#Preview {
    ProfileView {
        print("Sign out tapped")
    }
}
