import Foundation

/// Errors that can occur during BLE operations
enum BLEError: LocalizedError {
    case bluetoothPoweredOff
    case bluetoothUnauthorized
    case deviceNotFound
    case connectionFailed(String)
    case connectionLost
    case characteristicNotFound
    case invalidData
    case scanTimeout
    
    var errorDescription: String? {
        switch self {
        case .bluetoothPoweredOff:
            return "Bluetooth is turned off. Please enable it in Settings."
        case .bluetoothUnauthorized:
            return "Bluetooth permission is required. Please enable it in Settings."
        case .deviceNotFound:
            return "Device not found. Please try scanning again."
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .connectionLost:
            return "Connection lost. Attempting to reconnect..."
        case .characteristicNotFound:
            return "Heart rate service not available on this device."
        case .invalidData:
            return "Invalid data received from sensor."
        case .scanTimeout:
            return "No devices found. Please ensure your heart rate monitor is nearby and powered on."
        }
    }
}
