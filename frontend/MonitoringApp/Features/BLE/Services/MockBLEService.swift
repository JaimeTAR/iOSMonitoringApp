import Foundation
import Combine

/// Mock BLE service for testing and previews - simulates a connected heart rate monitor
final class MockBLEService: BLEServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var state: BLEState = .poweredOn
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var connectedDevice: ConnectedDevice? = nil
    @Published private(set) var heartRateData: HeartRateData? = nil
    
    // MARK: - Error Publisher
    
    private let errorSubject = PassthroughSubject<BLEError, Never>()
    var errorPublisher: AnyPublisher<BLEError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private var heartRateTimer: Timer?
    private var baseHeartRate: Int = 72
    private var rrIntervals: [Double] = []
    
    // MARK: - Configuration
    
    /// Set to true to auto-connect on init
    var autoConnect: Bool
    
    /// Simulated device name
    var mockDeviceName: String = "Mock HR Sensor"
    
    // MARK: - Initialization
    
    init(autoConnect: Bool = false) {
        self.autoConnect = autoConnect
        if autoConnect {
            simulateConnection()
        }
    }
    
    deinit {
        heartRateTimer?.invalidate()
    }
    
    // MARK: - BLEServiceProtocol
    
    func startScanning() {
        state = .scanning
        
        // Simulate finding a device after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.stopScanning()
        }
    }
    
    func stopScanning() {
        if case .scanning = state {
            state = .poweredOn
        }
    }
    
    func connect(to device: DiscoveredDevice) {
        simulateConnection()
    }
    
    func disconnect() {
        heartRateTimer?.invalidate()
        heartRateTimer = nil
        connectedDevice = nil
        heartRateData = nil
        state = .disconnected
    }
    
    func reconnectToLastDevice() {
        simulateConnection()
    }
    
    // MARK: - Simulation Methods
    
    private func simulateConnection() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            let device = ConnectedDevice(name: self.mockDeviceName)
            self.connectedDevice = device
            self.state = .connected(device)
            
            // Start sending heart rate data
            self.startHeartRateSimulation()
        }
    }
    
    private func startHeartRateSimulation() {
        heartRateTimer?.invalidate()
        
        // Send data every second
        heartRateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.generateHeartRateData()
        }
        
        // Send initial data immediately
        generateHeartRateData()
    }
    
    private func generateHeartRateData() {
        // Simulate realistic heart rate variation (±5 BPM)
        let variation = Int.random(in: -3...3)
        let heartRate = max(50, min(180, baseHeartRate + variation))
        
        // Gradually drift the base heart rate for more realistic simulation
        if Int.random(in: 0...10) == 0 {
            baseHeartRate = max(60, min(100, baseHeartRate + Int.random(in: -2...2)))
        }
        
        // Generate RR intervals in seconds (time between heartbeats)
        // RR interval ≈ 60 / heart rate
        let baseRR = 60.0 / Double(heartRate)
        let rrVariation = Double.random(in: -0.05...0.05)
        let newRR = max(0.3, min(1.5, baseRR + rrVariation))
        
        // Keep last 10 RR intervals for HRV calculation
        rrIntervals.append(newRR)
        if rrIntervals.count > 10 {
            rrIntervals.removeFirst()
        }
        
        heartRateData = HeartRateData(
            heartRate: heartRate,
            sensorContact: true,
            rrIntervals: rrIntervals,
            timestamp: Date()
        )
    }
    
    // MARK: - Test Helpers
    
    /// Simulate a specific heart rate
    func setHeartRate(_ hr: Int) {
        baseHeartRate = hr
        generateHeartRateData()
    }
    
    /// Simulate connection loss
    func simulateConnectionLoss() {
        heartRateTimer?.invalidate()
        heartRateTimer = nil
        connectedDevice = nil
        heartRateData = nil
        state = .disconnected
        errorSubject.send(.connectionLost)
    }
}
