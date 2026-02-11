import Foundation

/// Errors that can occur during profile operations
enum ProfileError: LocalizedError {
    case notAuthenticated
    case profileNotFound
    case invalidProfileData(String)
    case createFailed(String)
    case updateFailed(String)
    case fetchFailed(String)
    case networkError
    case offlineOperationFailed
    case insufficientDataForBaseline(daysAvailable: Int, daysRequired: Int)
    case baselineCalculationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to access your profile."
        case .profileNotFound:
            return "Profile not found. Please complete your profile setup."
        case .invalidProfileData(let reason):
            return "Invalid profile data: \(reason)"
        case .createFailed(let reason):
            return "Failed to create profile: \(reason)"
        case .updateFailed(let reason):
            return "Failed to update profile: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to load profile: \(reason)"
        case .networkError:
            return "Network error. Please check your connection."
        case .offlineOperationFailed:
            return "This operation requires an internet connection."
        case .insufficientDataForBaseline(let daysAvailable, let daysRequired):
            return "Insufficient data for baseline calculation. You have \(daysAvailable) days of data, but \(daysRequired) days are required."
        case .baselineCalculationFailed(let reason):
            return "Failed to calculate baseline: \(reason)"
        }
    }
}
