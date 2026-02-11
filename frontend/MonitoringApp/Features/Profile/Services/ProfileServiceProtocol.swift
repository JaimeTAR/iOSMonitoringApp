import Foundation
import Combine

/// Result of baseline calculation attempt
struct BaselineCalculationResult {
    /// The calculated resting heart rate, if successful
    let restingHeartRate: Double?
    /// Number of days of data used in calculation
    let daysOfData: Int
    /// Whether sufficient data was available (minimum 7 days)
    let hasSufficientData: Bool
    /// Total number of samples analyzed
    let sampleCount: Int
}

/// Protocol defining profile service capabilities
protocol ProfileServiceProtocol: ObservableObject {
    /// The current user's profile, if loaded
    var profile: UserProfile? { get }
    
    /// Whether the profile is currently being loaded or saved
    var isLoading: Bool { get }
    
    /// Creates a new user profile
    /// - Parameter profile: The profile data to create
    /// - Throws: ProfileError if creation fails
    func createProfile(_ profile: UserProfile) async throws
    
    /// Updates an existing user profile
    /// - Parameter profile: The updated profile data
    /// - Throws: ProfileError if update fails
    func updateProfile(_ profile: UserProfile) async throws
    
    /// Fetches the current user's profile
    /// - Returns: The user's profile if found
    /// - Throws: ProfileError if fetch fails
    func fetchProfile() async throws -> UserProfile?
    
    /// Gets the assigned clinician for the current user
    /// - Returns: The clinician info if the user has an assigned clinician
    /// - Throws: ProfileError if fetch fails
    func getAssignedClinician() async throws -> ClinicianInfo?
    
    /// Clears the cached profile data
    func clearCache()
    
    /// Calculates resting heart rate baseline from physiological samples
    /// Requires minimum 7 days of data for accurate calculation
    /// - Returns: BaselineCalculationResult with calculated value and metadata
    /// - Throws: ProfileError if calculation fails
    func calculateRestingHeartRateBaseline() async throws -> BaselineCalculationResult
    
    /// Recalculates and updates the user's resting heart rate baseline
    /// - Returns: The updated profile with new baseline, or nil if insufficient data
    /// - Throws: ProfileError if recalculation or update fails
    func recalculateBaseline() async throws -> UserProfile?
}
