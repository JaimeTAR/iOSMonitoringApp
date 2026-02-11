import Foundation

/// App-level network errors
/// Wraps Supabase SDK errors with user-friendly messages
enum NetworkError: LocalizedError {
    case unauthorized
    case networkUnavailable
    case serverError(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .networkUnavailable:
            return "No network connection. Please check your internet."
        case .serverError(let message):
            return message
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable:
            return true
        default:
            return false
        }
    }
}
