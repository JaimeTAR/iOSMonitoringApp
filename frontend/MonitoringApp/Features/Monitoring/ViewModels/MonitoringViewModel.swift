import Foundation
import Combine

/// ViewModel for managing monitoring sessions and coordinating BLE data with storage
@MainActor
final class MonitoringViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current heart rate from the sensor
    @Published private(set) var currentHeartRate: Int?
    
    /// Whether sensor has contact with skin
    @Published private(set) var sensorContact: Bool?
    
    /// Current RMSSD value (updated per window)
    @Published private(set) var currentRMSSD: Double?
    
    /// Current SDNN value (updated per window)
    @Published private(set) var currentSDNN: Double?
    
    /// Duration of current monitoring session
    @Published private(set) var sessionDuration: TimeInterval = 0
    
    /// Number of samples stored in current session
    @Published private(set) var sessionSampleCount: Int = 0
    
    /// Whether a monitoring session is active
    @Published private(set) var isMonitoring: Bool = false
    
    /// Error message to display
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Computed Properties
    
    /// Heart rate zone based on current reading
    var heartRateZone: HeartRateZone {
        guard let hr = currentHeartRate else { return .unknown }
        return HeartRateZone(heartRate: hr)
    }
    
    /// Formatted session duration string
    var formattedDuration: String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Whether heart rate is outside normal range
    var isHeartRateAnomalous: Bool {
        guard let hr = currentHeartRate else { return false }
        return hr < 30 || hr > 220
    }
    
    /// Whether sensor contact is lost
    var isSensorContactLost: Bool {
        sensorContact == false
    }
    
    // MARK: - Private Properties
    
    private let bleService: any BLEServiceProtocol
    private let sampleService: any SampleServiceProtocol
    private let windowAggregator: WindowAggregatorProtocol
    private var userId: UUID?
    
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimerCancellable: AnyCancellable?
    private var windowTimer: Timer?
    
    /// Start time of the monitoring session (for accurate duration tracking)
    private var sessionStartTime: Date?
    
    /// Heart rate samples collected in current 1-minute window
    private var currentWindowSamples: [HeartRateData] = []
    
    /// Start time of current window
    private var windowStartTime: Date?
    
    /// Window duration in seconds
    private let windowDuration: TimeInterval = 60
    
    // MARK: - Initialization
    
    init(
        bleService: any BLEServiceProtocol,
        sampleService: any SampleServiceProtocol,
        windowAggregator: WindowAggregatorProtocol? = nil
    ) {
        self.bleService = bleService
        self.sampleService = sampleService
        self.windowAggregator = windowAggregator ?? WindowAggregator()
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Set the current user ID for sample storage
    func setUserId(_ userId: UUID) {
        self.userId = userId
    }
    
    /// Start a monitoring session
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        sessionDuration = 0
        sessionSampleCount = 0
        currentWindowSamples = []
        sessionStartTime = Date()
        windowStartTime = Date()
        
        startSessionTimer()
        startWindowTimer()
    }
    
    /// Stop the monitoring session
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        // Save any remaining samples in current window
        saveCurrentWindow()
        
        isMonitoring = false
        sessionTimerCancellable?.cancel()
        sessionTimerCancellable = nil
        windowTimer?.invalidate()
        windowTimer = nil
        currentWindowSamples = []
        windowStartTime = nil
        sessionStartTime = nil
    }
    
    /// Dismiss error message
    func dismissError() {
        showError = false
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Observe heart rate data from BLE service - support both real and mock
        if let realService = bleService as? BLEService {
            realService.$heartRateData
                .receive(on: DispatchQueue.main)
                .compactMap { $0 }
                .sink { [weak self] data in
                    self?.handleHeartRateData(data)
                }
                .store(in: &cancellables)
        } else if let mockService = bleService as? MockBLEService {
            mockService.$heartRateData
                .receive(on: DispatchQueue.main)
                .compactMap { $0 }
                .sink { [weak self] data in
                    self?.handleHeartRateData(data)
                }
                .store(in: &cancellables)
        }
    }
    
    private func handleHeartRateData(_ data: HeartRateData) {
        // Update current values
        currentHeartRate = data.heartRate
        sensorContact = data.sensorContact
        
        // Collect sample if monitoring
        if isMonitoring {
            currentWindowSamples.append(data)
        }
    }
    
    private func startSessionTimer() {
        guard let startTime = sessionStartTime else { return }
        
        sessionTimerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.sessionDuration = Date().timeIntervalSince(startTime)
            }
    }
    
    private func startWindowTimer() {
        windowTimer = Timer.scheduledTimer(withTimeInterval: windowDuration, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveCurrentWindow()
            }
        }
    }
    
    private func saveCurrentWindow() {
        guard let userId = userId,
              let windowStart = windowStartTime,
              !currentWindowSamples.isEmpty else {
            // Reset for next window even if no samples
            currentWindowSamples = []
            windowStartTime = Date()
            return
        }
        
        // Aggregate samples into a physiological sample
        guard let sample = windowAggregator.aggregate(
            samples: currentWindowSamples,
            windowStart: windowStart,
            userId: userId
        ) else {
            currentWindowSamples = []
            windowStartTime = Date()
            return
        }
        
        // Update HRV display values
        currentRMSSD = sample.rmssd
        currentSDNN = sample.sdnn
        
        // Save sample
        Task {
            do {
                try await sampleService.saveSample(sample)
                sessionSampleCount += 1
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        
        // Reset for next window
        currentWindowSamples = []
        windowStartTime = Date()
    }
}

// MARK: - Heart Rate Zone

enum HeartRateZone {
    case low        // < 60 BPM
    case normal     // 60-100 BPM
    case elevated   // 100-140 BPM
    case high       // > 140 BPM
    case unknown
    
    init(heartRate: Int) {
        switch heartRate {
        case ..<60:
            self = .low
        case 60..<100:
            self = .normal
        case 100..<140:
            self = .elevated
        default:
            self = .high
        }
    }
}
