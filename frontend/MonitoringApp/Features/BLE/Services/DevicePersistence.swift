import Foundation

/// Handles persistence of BLE device information for quick reconnection
final class DevicePersistence {
    
    // MARK: - Storage Keys
    
    private enum Keys {
        static let lastConnectedDeviceId = "lastConnectedDeviceId"
        static let lastConnectedDeviceName = "lastConnectedDeviceName"
    }
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Last Connected Device
    
    /// The UUID of the last connected device
    var lastConnectedDeviceId: UUID? {
        guard let idString = userDefaults.string(forKey: Keys.lastConnectedDeviceId) else {
            return nil
        }
        return UUID(uuidString: idString)
    }
    
    /// The name of the last connected device
    var lastConnectedDeviceName: String? {
        userDefaults.string(forKey: Keys.lastConnectedDeviceName)
    }
    
    /// Whether there is a remembered device
    var hasRememberedDevice: Bool {
        lastConnectedDeviceId != nil
    }
    
    /// Save the last connected device information
    /// - Parameters:
    ///   - id: Device UUID
    ///   - name: Device name
    func saveLastConnectedDevice(id: UUID, name: String) {
        userDefaults.set(id.uuidString, forKey: Keys.lastConnectedDeviceId)
        userDefaults.set(name, forKey: Keys.lastConnectedDeviceName)
    }
    
    /// Clear the stored device information (forget device)
    func forgetDevice() {
        userDefaults.removeObject(forKey: Keys.lastConnectedDeviceId)
        userDefaults.removeObject(forKey: Keys.lastConnectedDeviceName)
    }
}
