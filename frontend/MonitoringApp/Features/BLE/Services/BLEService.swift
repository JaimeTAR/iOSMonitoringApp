import Foundation
import CoreBluetooth
import Combine

/// BLE Service for heart rate monitor connectivity
final class BLEService: NSObject, BLEServiceProtocol, ObservableObject {
    
    // MARK: - BLE UUIDs
    
    private static let heartRateServiceUUID = CBUUID(string: "180D")
    private static let heartRateMeasurementUUID = CBUUID(string: "2A37")
    
    // MARK: - State Restoration
    
    private static let restorationIdentifier = "com.monitoringapp.bleservice"
    
    // MARK: - Published Properties
    
    @Published private(set) var state: BLEState = .unknown
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var connectedDevice: ConnectedDevice? = nil
    @Published private(set) var heartRateData: HeartRateData? = nil
    
    // MARK: - Error Publisher
    
    private let errorSubject = PassthroughSubject<BLEError, Never>()
    var errorPublisher: AnyPublisher<BLEError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?
    
    private var scanTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    
    private let maxDiscoveredDevices = 5
    private let scanTimeout: TimeInterval = 10.0
    
    // MARK: - Device Persistence
    
    private let devicePersistence: DevicePersistence
    
    // MARK: - Initialization
    
    init(devicePersistence: DevicePersistence = DevicePersistence()) {
        self.devicePersistence = devicePersistence
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restorationIdentifier]
        )
    }
    
    // MARK: - BLEServiceProtocol
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            handleBluetoothState(centralManager.state)
            return
        }
        
        discoveredDevices = []
        state = .scanning
        
        centralManager.scanForPeripherals(
            withServices: [Self.heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Set scan timeout
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanTimeout, repeats: false) { [weak self] _ in
            self?.handleScanTimeout()
        }
    }
    
    func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
        centralManager.stopScan()
        
        if case .scanning = state {
            state = .poweredOn
        }
    }
    
    func connect(to device: DiscoveredDevice) {
        stopScanning()
        state = .connecting(device)
        reconnectAttempts = 0
        centralManager.connect(device.peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        cleanupConnection()
    }
    
    func reconnectToLastDevice() {
        guard let deviceId = devicePersistence.lastConnectedDeviceId else { return }
        
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [deviceId])
        if let peripheral = peripherals.first {
            let device = DiscoveredDevice(peripheral: peripheral, rssi: 0, advertisementData: [:])
            connect(to: device)
        } else {
            // Device not available, start scanning
            startScanning()
        }
    }

    
    // MARK: - Private Methods
    
    private func handleBluetoothState(_ state: CBManagerState) {
        switch state {
        case .poweredOff:
            self.state = .poweredOff
            errorSubject.send(.bluetoothPoweredOff)
        case .unauthorized:
            self.state = .unauthorized
            errorSubject.send(.bluetoothUnauthorized)
        case .poweredOn:
            self.state = .poweredOn
        case .unknown, .resetting, .unsupported:
            self.state = .unknown
        @unknown default:
            self.state = .unknown
        }
    }
    
    private func handleScanTimeout() {
        if discoveredDevices.isEmpty {
            errorSubject.send(.scanTimeout)
        }
        stopScanning()
    }
    
    private func cleanupConnection() {
        connectedPeripheral = nil
        heartRateCharacteristic = nil
        connectedDevice = nil
        heartRateData = nil
        state = .disconnected
    }
    
    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts,
              let deviceId = devicePersistence.lastConnectedDeviceId else {
            state = .disconnected
            return
        }
        
        reconnectAttempts += 1
        
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [deviceId])
        if let peripheral = peripherals.first {
            centralManager.connect(peripheral, options: nil)
        } else {
            state = .disconnected
        }
    }
    
    private func updateDiscoveredDevices(with device: DiscoveredDevice) {
        // Update existing or add new
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }
        
        // Sort by RSSI (strongest first) and limit to max devices
        discoveredDevices.sort { $0.rssi > $1.rssi }
        if discoveredDevices.count > maxDiscoveredDevices {
            discoveredDevices = Array(discoveredDevices.prefix(maxDiscoveredDevices))
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEService: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        handleBluetoothState(central.state)
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        // Handle state restoration after app is relaunched in background
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                if peripheral.state == .connected {
                    connectedPeripheral = peripheral
                    peripheral.delegate = self
                    
                    let device = ConnectedDevice(peripheral: peripheral)
                    connectedDevice = device
                    state = .connected(device)
                    
                    // Re-discover services to get characteristic reference
                    peripheral.discoverServices([Self.heartRateServiceUUID])
                }
            }
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let device = DiscoveredDevice(
            peripheral: peripheral,
            rssi: RSSI.intValue,
            advertisementData: advertisementData
        )
        updateDiscoveredDevices(with: device)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        
        let device = ConnectedDevice(peripheral: peripheral)
        connectedDevice = device
        state = .connected(device)
        
        // Save device for quick reconnect
        devicePersistence.saveLastConnectedDevice(id: peripheral.identifier, name: device.name)
        
        // Reset reconnect attempts on successful connection
        reconnectAttempts = 0
        
        // Discover heart rate service
        peripheral.discoverServices([Self.heartRateServiceUUID])
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let reason = error?.localizedDescription ?? "Unknown error"
        errorSubject.send(.connectionFailed(reason))
        cleanupConnection()
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        cleanupConnection()
        
        if error != nil {
            // Unexpected disconnection - attempt reconnect
            errorSubject.send(.connectionLost)
            attemptReconnect()
        }
    }
}


// MARK: - CBPeripheralDelegate

extension BLEService: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            errorSubject.send(.characteristicNotFound)
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == Self.heartRateServiceUUID {
                peripheral.discoverCharacteristics([Self.heartRateMeasurementUUID], for: service)
            }
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else {
            errorSubject.send(.characteristicNotFound)
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == Self.heartRateMeasurementUUID {
                heartRateCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == Self.heartRateMeasurementUUID,
              let data = characteristic.value else {
            return
        }
        
        if let parsedData = HeartRateParser.parse(data) {
            heartRateData = parsedData
        } else {
            errorSubject.send(.invalidData)
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            print("Failed to subscribe to heart rate notifications: \(error.localizedDescription)")
        }
    }
}
