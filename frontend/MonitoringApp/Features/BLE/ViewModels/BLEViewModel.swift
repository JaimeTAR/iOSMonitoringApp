import Foundation
import Combine

/// ViewModel for BLE connection UI
@MainActor
final class BLEViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var errorMessage: String?
    @Published var showError: Bool = false
    
    /// Whether there's a remembered device for quick connect
    @Published private(set) var hasRememberedDevice: Bool = false
    @Published private(set) var rememberedDeviceName: String?
    
    // MARK: - Computed Properties
    
    var isScanning: Bool {
        connectionStatus == .scanning
    }
    
    var isConnected: Bool {
        connectionStatus == .connected
    }
    
    var isConnecting: Bool {
        connectionStatus == .connecting
    }
    
    var canScan: Bool {
        connectionStatus == .disconnected || connectionStatus == .bluetoothOff
    }
    
    var isBluetoothOff: Bool {
        connectionStatus == .bluetoothOff
    }
    
    // MARK: - Private Properties
    
    private let bleService: any BLEServiceProtocol
    private let devicePersistence: DevicePersistence
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(bleService: any BLEServiceProtocol, devicePersistence: DevicePersistence? = nil) {
        self.bleService = bleService
        self.devicePersistence = devicePersistence ?? DevicePersistence()
        
        setupBindings()
        loadRememberedDevice()
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for heart rate devices
    func startScanning() {
        dismissError()
        bleService.startScanning()
    }
    
    /// Stop scanning for devices
    func stopScanning() {
        bleService.stopScanning()
    }
    
    /// Connect to a discovered device
    func connect(to device: DiscoveredDevice) {
        dismissError()
        bleService.connect(to: device)
    }
    
    /// Disconnect from the current device
    func disconnect() {
        bleService.disconnect()
    }
    
    /// Quick connect to the last remembered device
    func quickConnect() {
        dismissError()
        bleService.reconnectToLastDevice()
    }
    
    /// Forget the remembered device
    func forgetDevice() {
        devicePersistence.forgetDevice()
        loadRememberedDevice()
    }
    
    /// Dismiss the current error
    func dismissError() {
        showError = false
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Observe BLE state changes - support both real and mock services
        if let realService = bleService as? BLEService {
            realService.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.updateConnectionStatus(from: state)
                }
                .store(in: &cancellables)
            
            realService.$discoveredDevices
                .receive(on: DispatchQueue.main)
                .assign(to: &$discoveredDevices)
            
            realService.$connectedDevice
                .receive(on: DispatchQueue.main)
                .map { $0?.name }
                .assign(to: &$connectedDeviceName)
        } else if let mockService = bleService as? MockBLEService {
            mockService.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.updateConnectionStatus(from: state)
                }
                .store(in: &cancellables)
            
            mockService.$discoveredDevices
                .receive(on: DispatchQueue.main)
                .assign(to: &$discoveredDevices)
            
            mockService.$connectedDevice
                .receive(on: DispatchQueue.main)
                .map { $0?.name }
                .assign(to: &$connectedDeviceName)
        }
        
        // Observe errors
        bleService.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
    }
    
    private func updateConnectionStatus(from state: BLEState) {
        switch state {
        case .unknown, .disconnected:
            connectionStatus = .disconnected
        case .poweredOff:
            connectionStatus = .bluetoothOff
        case .unauthorized:
            connectionStatus = .bluetoothOff
        case .poweredOn:
            connectionStatus = .disconnected
        case .scanning:
            connectionStatus = .scanning
        case .connecting:
            connectionStatus = .connecting
        case .connected:
            connectionStatus = .connected
            // Refresh remembered device after successful connection
            loadRememberedDevice()
        }
    }
    
    private func handleError(_ error: BLEError) {
        errorMessage = error.errorDescription
        showError = true
    }
    
    private func loadRememberedDevice() {
        hasRememberedDevice = devicePersistence.hasRememberedDevice
        rememberedDeviceName = devicePersistence.lastConnectedDeviceName
    }
}
