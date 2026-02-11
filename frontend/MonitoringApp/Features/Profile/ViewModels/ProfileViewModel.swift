import Foundation
import Combine

/// ViewModel managing profile state and operations
@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var profile: UserProfile?
    @Published private(set) var clinician: ClinicianInfo?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var error: ProfileError?
    @Published var isEditing: Bool = false
    
    // MARK: - Editable Fields
    
    @Published var editName: String = ""
    @Published var editAge: String = ""
    @Published var editSex: Sex?
    @Published var editHeightCm: String = ""
    @Published var editWeightKg: String = ""
    @Published var editExerciseFrequency: String = ""
    @Published var editActivityLevel: ActivityLevel?
    
    // MARK: - Dependencies
    
    private let profileService: ProfileService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Whether required fields are filled for profile setup
    var canCompleteSetup: Bool {
        guard let age = Int(editAge), UserProfile.isValidAge(age) else {
            return false
        }
        return editSex != nil
    }
    
    /// Whether the current edits are valid for saving
    var canSave: Bool {
        // Age validation (required)
        if !editAge.isEmpty {
            guard let age = Int(editAge), UserProfile.isValidAge(age) else {
                return false
            }
        }
        
        // Height validation (optional)
        if !editHeightCm.isEmpty {
            guard let height = Double(editHeightCm), UserProfile.isValidHeight(height) else {
                return false
            }
        }
        
        // Weight validation (optional)
        if !editWeightKg.isEmpty {
            guard let weight = Double(editWeightKg), UserProfile.isValidWeight(weight) else {
                return false
            }
        }
        
        // Exercise frequency validation (optional)
        if !editExerciseFrequency.isEmpty {
            guard let freq = Int(editExerciseFrequency), UserProfile.isValidExerciseFrequency(freq) else {
                return false
            }
        }
        
        return true
    }
    
    /// Validation error message for display
    var validationError: String? {
        if !editAge.isEmpty {
            if let age = Int(editAge) {
                if !UserProfile.isValidAge(age) {
                    return "Age must be between 1 and 149"
                }
            } else {
                return "Please enter a valid age"
            }
        }
        
        if !editHeightCm.isEmpty {
            if let height = Double(editHeightCm) {
                if !UserProfile.isValidHeight(height) {
                    return "Height must be between 0 and 300 cm"
                }
            } else {
                return "Please enter a valid height"
            }
        }
        
        if !editWeightKg.isEmpty {
            if let weight = Double(editWeightKg) {
                if !UserProfile.isValidWeight(weight) {
                    return "Weight must be between 0 and 500 kg"
                }
            } else {
                return "Please enter a valid weight"
            }
        }
        
        if !editExerciseFrequency.isEmpty {
            if let freq = Int(editExerciseFrequency) {
                if !UserProfile.isValidExerciseFrequency(freq) {
                    return "Exercise frequency must be between 0 and 21 per week"
                }
            } else {
                return "Please enter a valid exercise frequency"
            }
        }
        
        return nil
    }
    
    // MARK: - Initialization
    
    init(profileService: ProfileService? = nil) {
        self.profileService = profileService ?? ProfileService()
        
        // Observe profile changes from service
        self.profileService.$profile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.profile = profile
                if let profile = profile {
                    self?.populateEditFields(from: profile)
                }
            }
            .store(in: &cancellables)
        
        self.profileService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
    }
    
    // MARK: - Public Methods
    
    /// Loads the user's profile and clinician info
    func loadProfile() async {
        error = nil
        
        do {
            _ = try await profileService.fetchProfile()
            clinician = try await profileService.getAssignedClinician()
        } catch let profileError as ProfileError {
            error = profileError
        } catch {
            self.error = .fetchFailed(error.localizedDescription)
        }
    }
    
    /// Saves the current profile setup (for new users)
    func saveProfileSetup(userId: UUID) async -> Bool {
        guard canCompleteSetup else { return false }
        
        isSaving = true
        error = nil
        defer { isSaving = false }
        
        let now = Date()
        let newProfile = UserProfile(
            id: UUID(),
            userId: userId,
            role: .patient,
            name: editName.isEmpty ? nil : editName,
            age: Int(editAge),
            sex: editSex,
            heightCm: Double(editHeightCm),
            weightKg: Double(editWeightKg),
            exerciseFrequency: Int(editExerciseFrequency),
            activityLevel: editActivityLevel,
            restingHeartRate: nil,
            createdAt: now,
            updatedAt: now
        )
        
        do {
            try await profileService.createProfile(newProfile)
            return true
        } catch let profileError as ProfileError {
            error = profileError
            return false
        } catch {
            self.error = .createFailed(error.localizedDescription)
            return false
        }
    }
    
    /// Saves changes to an existing profile
    func saveProfileChanges() async -> Bool {
        guard let existingProfile = profile, canSave else { return false }
        
        isSaving = true
        error = nil
        defer { isSaving = false }
        
        let updatedProfile = UserProfile(
            id: existingProfile.id,
            userId: existingProfile.userId,
            role: existingProfile.role,
            name: editName.isEmpty ? nil : editName,
            age: editAge.isEmpty ? nil : Int(editAge),
            sex: editSex,
            heightCm: editHeightCm.isEmpty ? nil : Double(editHeightCm),
            weightKg: editWeightKg.isEmpty ? nil : Double(editWeightKg),
            exerciseFrequency: editExerciseFrequency.isEmpty ? nil : Int(editExerciseFrequency),
            activityLevel: editActivityLevel,
            restingHeartRate: existingProfile.restingHeartRate,
            createdAt: existingProfile.createdAt,
            updatedAt: Date()
        )
        
        do {
            try await profileService.updateProfile(updatedProfile)
            isEditing = false
            return true
        } catch let profileError as ProfileError {
            error = profileError
            return false
        } catch {
            self.error = .updateFailed(error.localizedDescription)
            return false
        }
    }
    
    /// Starts editing mode
    func startEditing() {
        if let profile = profile {
            populateEditFields(from: profile)
        }
        isEditing = true
    }
    
    /// Cancels editing and reverts changes
    func cancelEditing() {
        if let profile = profile {
            populateEditFields(from: profile)
        }
        isEditing = false
    }
    
    /// Clears the error state
    func clearError() {
        error = nil
    }
    
    /// Resets all edit fields
    func resetEditFields() {
        editName = ""
        editAge = ""
        editSex = nil
        editHeightCm = ""
        editWeightKg = ""
        editExerciseFrequency = ""
        editActivityLevel = nil
    }
    
    // MARK: - Private Methods
    
    private func populateEditFields(from profile: UserProfile) {
        editName = profile.name ?? ""
        editAge = profile.age.map { String($0) } ?? ""
        editSex = profile.sex
        editHeightCm = profile.heightCm.map { String(format: "%.1f", $0) } ?? ""
        editWeightKg = profile.weightKg.map { String(format: "%.1f", $0) } ?? ""
        editExerciseFrequency = profile.exerciseFrequency.map { String($0) } ?? ""
        editActivityLevel = profile.activityLevel
    }
}
