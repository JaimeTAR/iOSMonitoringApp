import Foundation

/// Aggregated physiological data for a 1-minute window
/// Maps to physiological_samples table in database
struct PhysiologicalSample: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let windowStart: Date
    let avgHeartRate: Double
    let rmssd: Double?
    let sdnn: Double?
    let sampleCount: Int
    let createdAt: Date
    var isSynced: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case windowStart = "window_start"
        case avgHeartRate = "avg_heart_rate"
        case rmssd
        case sdnn
        case sampleCount = "sample_count"
        case createdAt = "created_at"
    }
    
    /// Custom decoder to handle missing isSynced field from database
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        windowStart = try container.decode(Date.self, forKey: .windowStart)
        avgHeartRate = try container.decode(Double.self, forKey: .avgHeartRate)
        rmssd = try container.decodeIfPresent(Double.self, forKey: .rmssd)
        sdnn = try container.decodeIfPresent(Double.self, forKey: .sdnn)
        sampleCount = try container.decode(Int.self, forKey: .sampleCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        // isSynced is local-only, default to true for fetched records
        isSynced = true
    }
    
    /// Creates a new sample with auto-generated id and timestamp
    init(userId: UUID, windowStart: Date, avgHeartRate: Double, rmssd: Double?, sdnn: Double?, sampleCount: Int) {
        self.id = UUID()
        self.userId = userId
        self.windowStart = windowStart
        self.avgHeartRate = avgHeartRate
        self.rmssd = rmssd
        self.sdnn = sdnn
        self.sampleCount = sampleCount
        self.createdAt = Date()
        self.isSynced = false
    }
    
    // MARK: - Validation
    
    /// Validates avgHeartRate is within acceptable range (0-300 BPM)
    static func isValidHeartRate(_ heartRate: Double) -> Bool {
        heartRate >= 0 && heartRate <= 300
    }
    
    /// Validates RMSSD is non-negative
    static func isValidRMSSD(_ rmssd: Double) -> Bool {
        rmssd >= 0
    }
    
    /// Validates SDNN is non-negative
    static func isValidSDNN(_ sdnn: Double) -> Bool {
        sdnn >= 0
    }
    
    /// Validates all sample fields
    var isValid: Bool {
        guard Self.isValidHeartRate(avgHeartRate) else { return false }
        if let rmssd = rmssd, !Self.isValidRMSSD(rmssd) { return false }
        if let sdnn = sdnn, !Self.isValidSDNN(sdnn) { return false }
        return true
    }
}
