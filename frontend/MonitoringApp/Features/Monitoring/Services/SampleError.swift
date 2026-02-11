import Foundation

/// Errors that can occur during sample operations
enum SampleError: LocalizedError {
    case notAuthenticated
    case invalidSample(String)
    case saveFailed(String)
    case fetchFailed(String)
    case syncFailed(String)
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to save samples."
        case .invalidSample(let reason):
            return "Invalid sample data: \(reason)"
        case .saveFailed(let reason):
            return "Failed to save sample: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch samples: \(reason)"
        case .syncFailed(let reason):
            return "Failed to sync samples: \(reason)"
        case .networkUnavailable:
            return "Network unavailable. Samples will sync when online."
        }
    }
}
