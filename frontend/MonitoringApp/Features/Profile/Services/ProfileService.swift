import Foundation
import Combine
import Supabase

/// Service handling user profile operations with offline caching support
@MainActor
final class ProfileService: ObservableObject, ProfileServiceProtocol {
    @Published private(set) var profile: UserProfile?
    @Published private(set) var isLoading: Bool = false
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let cachedProfile = "cached_user_profile"
        static let cachedClinician = "cached_clinician_info"
    }
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Profile Operations
    
    func createProfile(_ profile: UserProfile) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Validate profile data
        guard profile.isValid else {
            throw ProfileError.invalidProfileData("Profile validation failed")
        }
        
        do {
            // Create profile update model (without id which is auto-generated)
            let profileData = ProfileCreateData(
                userId: profile.userId,
                role: profile.role,
                name: profile.name,
                age: profile.age,
                sex: profile.sex,
                heightCm: profile.heightCm,
                weightKg: profile.weightKg,
                exerciseFrequency: profile.exerciseFrequency,
                activityLevel: profile.activityLevel,
                restingHeartRate: profile.restingHeartRate,
                createdAt: profile.createdAt,
                updatedAt: Date()
            )
            
            // Use upsert to handle case where profile may already exist from registration
            try await supabase
                .from("user_profile")
                .upsert(profileData, onConflict: "user_id")
                .execute()
            
            // Update local state and cache
            self.profile = profile
            cacheProfile(profile)
            
        } catch let error as ProfileError {
            throw error
        } catch {
            throw ProfileError.createFailed(error.localizedDescription)
        }
    }
    
    func updateProfile(_ profile: UserProfile) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Validate profile data
        guard profile.isValid else {
            throw ProfileError.invalidProfileData("Profile validation failed")
        }
        
        do {
            let updateData = ProfileUpdateData(
                name: profile.name,
                age: profile.age,
                sex: profile.sex,
                heightCm: profile.heightCm,
                weightKg: profile.weightKg,
                exerciseFrequency: profile.exerciseFrequency,
                activityLevel: profile.activityLevel,
                restingHeartRate: profile.restingHeartRate,
                updatedAt: Date()
            )
            
            try await supabase
                .from("user_profile")
                .update(updateData)
                .eq("user_id", value: profile.userId)
                .execute()
            
            // Update local state and cache
            self.profile = profile
            cacheProfile(profile)
            
        } catch let error as ProfileError {
            throw error
        } catch {
            throw ProfileError.updateFailed(error.localizedDescription)
        }
    }
    
    func fetchProfile() async throws -> UserProfile? {
        isLoading = true
        defer { isLoading = false }
        
        // Get current user
        guard let user = try? await supabase.auth.session.user else {
            // Try to return cached profile if offline
            if let cached = getCachedProfile() {
                self.profile = cached
                return cached
            }
            throw ProfileError.notAuthenticated
        }
        
        do {
            let profiles: [UserProfile] = try await supabase
                .from("user_profile")
                .select()
                .eq("user_id", value: user.id)
                .execute()
                .value
            
            guard let fetchedProfile = profiles.first else {
                // Clear cache if profile doesn't exist
                clearCache()
                return nil
            }
            
            // Update local state and cache
            self.profile = fetchedProfile
            cacheProfile(fetchedProfile)
            
            return fetchedProfile
            
        } catch {
            // Try to return cached profile if network fails
            if let cached = getCachedProfile() {
                self.profile = cached
                return cached
            }
            throw ProfileError.fetchFailed(error.localizedDescription)
        }
    }
    
    func getAssignedClinician() async throws -> ClinicianInfo? {
        // Get current user
        guard let user = try? await supabase.auth.session.user else {
            // Try to return cached clinician if offline
            return getCachedClinician()
        }
        
        do {
            // First get the clinician-patient relationship
            let relationships: [ClinicianPatient] = try await supabase
                .from("clinician_patients")
                .select()
                .eq("patient_id", value: user.id)
                .eq("status", value: RelationshipStatus.activo.rawValue)
                .execute()
                .value
            
            guard let relationship = relationships.first else {
                return nil
            }
            
            // Fetch clinician profile to get their name
            let clinicianProfiles: [UserProfile] = try await supabase
                .from("user_profile")
                .select()
                .eq("user_id", value: relationship.clinicianId)
                .execute()
                .value
            
            // Create ClinicianInfo from available data
            let clinicianProfile = clinicianProfiles.first
            let clinicianInfo = ClinicianInfo(
                id: relationship.clinicianId,
                email: nil,
                name: clinicianProfile?.name
            )
            
            // Cache the clinician info
            cacheClinician(clinicianInfo)
            
            return clinicianInfo
            
        } catch {
            // Try to return cached clinician if network fails
            if let cached = getCachedClinician() {
                return cached
            }
            throw ProfileError.fetchFailed(error.localizedDescription)
        }
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: CacheKeys.cachedProfile)
        UserDefaults.standard.removeObject(forKey: CacheKeys.cachedClinician)
        profile = nil
    }
    
    // MARK: - Baseline Calculation
    
    /// Minimum number of days required for baseline calculation
    private static let minimumDaysForBaseline = 7
    
    func calculateRestingHeartRateBaseline() async throws -> BaselineCalculationResult {
        // Get current user
        guard let user = try? await supabase.auth.session.user else {
            throw ProfileError.notAuthenticated
        }
        
        // Calculate date range for the past 30 days (to find at least 7 days of data)
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        do {
            // Fetch samples from the past 30 days
            let samples: [PhysiologicalSample] = try await supabase
                .from("physiological_samples")
                .select()
                .eq("user_id", value: user.id)
                .gte("window_start", value: ISO8601DateFormatter().string(from: startDate))
                .lte("window_start", value: ISO8601DateFormatter().string(from: endDate))
                .order("window_start", ascending: true)
                .execute()
                .value
            
            return calculateBaselineFromSamples(samples)
            
        } catch {
            throw ProfileError.baselineCalculationFailed(error.localizedDescription)
        }
    }
    
    func recalculateBaseline() async throws -> UserProfile? {
        isLoading = true
        defer { isLoading = false }
        
        // Calculate the baseline
        let result = try await calculateRestingHeartRateBaseline()
        
        // Check if we have sufficient data
        guard result.hasSufficientData, let restingHeartRate = result.restingHeartRate else {
            throw ProfileError.insufficientDataForBaseline(
                daysAvailable: result.daysOfData,
                daysRequired: Self.minimumDaysForBaseline
            )
        }
        
        // Fetch current profile
        guard var currentProfile = try await fetchProfile() else {
            throw ProfileError.profileNotFound
        }
        
        // Update profile with new baseline
        currentProfile.restingHeartRate = restingHeartRate
        currentProfile.updatedAt = Date()
        
        // Save updated profile
        try await updateProfile(currentProfile)
        
        return currentProfile
    }
    
    /// Calculates resting heart rate from physiological samples
    /// Uses the lowest 10th percentile of heart rate readings during rest periods
    /// - Parameter samples: Array of physiological samples to analyze
    /// - Returns: BaselineCalculationResult with calculated baseline and metadata
    private func calculateBaselineFromSamples(_ samples: [PhysiologicalSample]) -> BaselineCalculationResult {
        guard !samples.isEmpty else {
            return BaselineCalculationResult(
                restingHeartRate: nil,
                daysOfData: 0,
                hasSufficientData: false,
                sampleCount: 0
            )
        }
        
        // Group samples by day to count unique days
        let calendar = Calendar.current
        let uniqueDays = Set(samples.map { calendar.startOfDay(for: $0.windowStart) })
        let daysOfData = uniqueDays.count
        
        // Check if we have minimum required days
        let hasSufficientData = daysOfData >= Self.minimumDaysForBaseline
        
        guard hasSufficientData else {
            return BaselineCalculationResult(
                restingHeartRate: nil,
                daysOfData: daysOfData,
                hasSufficientData: false,
                sampleCount: samples.count
            )
        }
        
        // Extract all heart rate values and sort them
        let heartRates = samples.map { $0.avgHeartRate }.sorted()
        
        // Calculate resting heart rate using the lowest 10th percentile
        // This approximates resting heart rate by taking the lowest readings
        let percentileIndex = max(0, Int(Double(heartRates.count) * 0.10) - 1)
        let restingHeartRates = Array(heartRates.prefix(max(1, percentileIndex + 1)))
        
        // Calculate average of the lowest percentile
        let restingHeartRate = restingHeartRates.reduce(0, +) / Double(restingHeartRates.count)
        
        // Round to one decimal place
        let roundedRestingHeartRate = (restingHeartRate * 10).rounded() / 10
        
        return BaselineCalculationResult(
            restingHeartRate: roundedRestingHeartRate,
            daysOfData: daysOfData,
            hasSufficientData: true,
            sampleCount: samples.count
        )
    }
    
    // MARK: - Private Cache Methods
    
    private func cacheProfile(_ profile: UserProfile) {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: CacheKeys.cachedProfile)
        }
    }
    
    private func getCachedProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: CacheKeys.cachedProfile),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return nil
        }
        return profile
    }
    
    private func cacheClinician(_ clinician: ClinicianInfo) {
        if let encoded = try? JSONEncoder().encode(clinician) {
            UserDefaults.standard.set(encoded, forKey: CacheKeys.cachedClinician)
        }
    }
    
    private func getCachedClinician() -> ClinicianInfo? {
        guard let data = UserDefaults.standard.data(forKey: CacheKeys.cachedClinician),
              let clinician = try? JSONDecoder().decode(ClinicianInfo.self, from: data) else {
            return nil
        }
        return clinician
    }
}


// MARK: - Helper Models for Database Operations

/// Model for creating a new user profile
private struct ProfileCreateData: Codable {
    let userId: UUID
    let role: UserRole
    let name: String?
    let age: Int?
    let sex: Sex?
    let heightCm: Double?
    let weightKg: Double?
    let exerciseFrequency: Int?
    let activityLevel: ActivityLevel?
    let restingHeartRate: Double?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case name
        case age
        case sex
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case exerciseFrequency = "exercise_frequency"
        case activityLevel = "activity_level"
        case restingHeartRate = "resting_heart_rate"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Model for updating an existing user profile
private struct ProfileUpdateData: Codable {
    let name: String?
    let age: Int?
    let sex: Sex?
    let heightCm: Double?
    let weightKg: Double?
    let exerciseFrequency: Int?
    let activityLevel: ActivityLevel?
    let restingHeartRate: Double?
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case name
        case age
        case sex
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case exerciseFrequency = "exercise_frequency"
        case activityLevel = "activity_level"
        case restingHeartRate = "resting_heart_rate"
        case updatedAt = "updated_at"
    }
}
