import SwiftUI

extension Color {
    // MARK: - Primary Colors
    static let appPrimary = Color(hex: "E53E3E")
    static let appSecondary = Color(hex: "C53030")
    static let appAccent = Color(hex: "FC8181")
    
    // MARK: - Status Colors
    static let statusGreen = Color(hex: "48BB78")
    static let statusYellow = Color(hex: "ECC94B")
    static let statusRed = Color(hex: "E53E3E")
    static let statusBlue = Color(hex: "4299E1")
    
    // MARK: - Semantic Colors (adapt to color scheme via Assets)
    static let appBackground = Color("Background")
    static let appSurface = Color("Surface")
    static let appSurfaceElevated = Color("SurfaceElevated")
    static let appTextPrimary = Color("TextPrimary")
    static let appTextSecondary = Color("TextSecondary")
    static let appBorder = Color("Border")
    
    // MARK: - Heart Rate Zone Colors
    static func heartRateColor(for bpm: Int) -> Color {
        switch bpm {
        case ..<60:
            return statusBlue
        case 60..<100:
            return statusGreen
        case 100..<140:
            return statusYellow
        default:
            return statusRed
        }
    }
    
    // MARK: - Connection Status Colors
    static func connectionStatusColor(isConnected: Bool, isConnecting: Bool) -> Color {
        if isConnected {
            return statusGreen
        } else if isConnecting {
            return statusYellow
        } else {
            return statusRed
        }
    }
}
