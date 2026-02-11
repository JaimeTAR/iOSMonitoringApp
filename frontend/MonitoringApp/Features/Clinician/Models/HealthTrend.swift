import SwiftUI

/// Represents a patient's recent health trajectory based on 7-day comparisons
enum HealthTrend: String, CaseIterable {
    case improving
    case stable
    case declining

    var color: Color {
        switch self {
        case .improving: return .statusGreen
        case .stable: return .statusYellow
        case .declining: return .statusRed
        }
    }
}
