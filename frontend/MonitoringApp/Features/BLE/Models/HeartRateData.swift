import Foundation

/// Represents heart rate data received from a BLE heart rate monitor
struct HeartRateData {
    /// Heart rate in beats per minute
    let heartRate: Int
    
    /// Whether the sensor has contact with skin (nil if not supported)
    let sensorContact: Bool?
    
    /// Energy expended in kilojoules (if available)
    let energyExpended: Int?
    
    /// RR intervals in seconds (time between heartbeats)
    let rrIntervals: [Double]
    
    /// Timestamp when the data was received
    let timestamp: Date
    
    /// Whether the heart rate is within physiological range (30-220 BPM)
    var isValid: Bool {
        heartRate >= 30 && heartRate <= 220
    }
    
    init(
        heartRate: Int,
        sensorContact: Bool? = nil,
        energyExpended: Int? = nil,
        rrIntervals: [Double] = [],
        timestamp: Date = Date()
    ) {
        self.heartRate = heartRate
        self.sensorContact = sensorContact
        self.energyExpended = energyExpended
        self.rrIntervals = rrIntervals
        self.timestamp = timestamp
    }
}
