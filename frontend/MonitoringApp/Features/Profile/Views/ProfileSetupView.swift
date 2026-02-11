import SwiftUI

/// View for initial profile setup after registration
struct ProfileSetupView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let userId: UUID
    let onComplete: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Complete Your Profile")
                            .font(.appTitle)
                            .foregroundColor(.appTextPrimary)
                        
                        Text("Help us personalize your wellness experience")
                            .font(.appBody)
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.bottom, 8)
                    
                    // Required Fields Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Required Information")
                            .font(.appHeadline)
                            .foregroundColor(.appTextPrimary)
                        
                        // Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.appSubheadline)
                                .foregroundColor(.appTextSecondary)
                            
                            TextField("Enter your name", text: $viewModel.editName)
                                .textContentType(.name)
                                .textFieldStyle(ProfileTextFieldStyle())
                        }
                        
                        // Age Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Age")
                                .font(.appSubheadline)
                                .foregroundColor(.appTextSecondary)
                            
                            TextField("Enter your age", text: $viewModel.editAge)
                                .keyboardType(.numberPad)
                                .textFieldStyle(ProfileTextFieldStyle())
                        }
                        
                        // Sex Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sex")
                                .font(.appSubheadline)
                                .foregroundColor(.appTextSecondary)
                            
                            Picker("Sex", selection: $viewModel.editSex) {
                                Text("Select").tag(nil as Sex?)
                                ForEach(Sex.allCases, id: \.self) { sex in
                                    Text(sex.displayName).tag(sex as Sex?)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.appBorder, lineWidth: 1)
                            )
                        }
                    }
                    
                    // Optional Fields Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Optional Information")
                            .font(.appHeadline)
                            .foregroundColor(.appTextPrimary)
                        
                        Text("These help improve wellness assessments")
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)
                        
                        // Height Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Height (cm)")
                                .font(.appSubheadline)
                                .foregroundColor(.appTextSecondary)
                            
                            TextField("Enter height", text: $viewModel.editHeightCm)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(ProfileTextFieldStyle())
                        }
                        
                        // Weight Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weight (kg)")
                                .font(.appSubheadline)
                                .foregroundColor(.appTextSecondary)
                            
                            TextField("Enter weight", text: $viewModel.editWeightKg)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(ProfileTextFieldStyle())
                        }
                        
                        // Exercise Frequency Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exercise Frequency (times per week)")
                                .font(.appSubheadline)
                                .foregroundColor(.appTextSecondary)
                            
                            TextField("0-21", text: $viewModel.editExerciseFrequency)
                                .keyboardType(.numberPad)
                                .textFieldStyle(ProfileTextFieldStyle())
                        }
                        
                        // Activity Level Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Activity Level")
                                .font(.appSubheadline)
                                .foregroundColor(.appTextSecondary)
                            
                            Picker("Activity Level", selection: $viewModel.editActivityLevel) {
                                Text("Select").tag(nil as ActivityLevel?)
                                ForEach(ActivityLevel.allCases, id: \.self) { level in
                                    Text(level.displayName).tag(level as ActivityLevel?)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.appBorder, lineWidth: 1)
                            )
                        }
                    }
                    
                    // Validation Error
                    if let validationError = viewModel.validationError {
                        Text(validationError)
                            .font(.appCaption)
                            .foregroundColor(.statusRed)
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
                    
                    Spacer(minLength: 24)
                    
                    // Continue Button
                    PrimaryButton(
                        title: "Continue",
                        action: {
                            Task {
                                let success = await viewModel.saveProfileSetup(userId: userId)
                                if success {
                                    onComplete()
                                }
                            }
                        },
                        isLoading: viewModel.isSaving,
                        isDisabled: !viewModel.canCompleteSetup
                    )
                }
                .padding(24)
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Custom Text Field Style

struct ProfileTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.appSurface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
    }
}

// MARK: - Sex Display Extension

extension Sex {
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

// MARK: - ActivityLevel Display Extension

extension ActivityLevel {
    var displayName: String {
        switch self {
        case .bajo: return "Low"
        case .moderado: return "Moderate"
        case .alto: return "High"
        }
    }
}

#Preview {
    ProfileSetupView(userId: UUID()) {
        print("Profile setup complete")
    }
}
