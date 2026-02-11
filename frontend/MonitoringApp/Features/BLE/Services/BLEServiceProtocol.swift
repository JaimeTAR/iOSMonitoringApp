import Foundation
import Combine

/// Protocol defining the interface for BLE heart rate service
protocol BLEServiceProtocol: ObservableObject {
    /// Current state of the BLE service
    var state: BLEState { get }
    
    /// List of discovered devices (max 5, sorted by signal strength)
    var discoveredDevices: [DiscoveredDevice] { get }
    
    /// Currently connected device, if any
    var connectedDevice: ConnectedDevice? { get }
    
    /// Latest heart rate data received from the connected device
    var heartRateData: HeartRateData? { get }
    
    /// Publisher for BLE errors
    var errorPublisher: AnyPublisher<BLEError, Never> { get }
    
    /// Start scanning for heart rate devices
    func startScanning()
    
    /// Stop scanning for devices
    func stopScanning()
    
    /// Connect to a discovered device
    /// - Parameter device: The device to connect to
    func connect(to device: DiscoveredDevice)
    
    /// Disconnect from the currently connected device
    func disconnect()
    
    /// Attempt to reconnect to the last connected device
    func reconnectToLastDevice()
}
