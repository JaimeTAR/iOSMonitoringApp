import Foundation

/// Protocol for aggregating heart rate samples into time windows
protocol WindowAggregatorProtocol {
    /// Aggregate heart rate samples into a physiological sample for a 1-minute window
    /// - Parameters:
    ///   - samples: Array of HeartRateData samples collected during the window
    ///   - windowStart: Start timestamp of the 1-minute window
    ///   - userId: User ID for the sample
    /// - Returns: Aggregated PhysiologicalSample, or nil if no valid samples
    func aggregate(samples: [HeartRateData], windowStart: Date, userId: UUID) -> PhysiologicalSample?
}

/// Aggregates heart rate data into 1-minute windows with HRV metrics
struct WindowAggregator: WindowAggregatorProtocol {
    
    private let hrvCalculator: HRVCalculatorProtocol
    
    init(hrvCalculator: HRVCalculatorProtocol = HRVCalculator()) {
        self.hrvCalculator = hrvCalculator
    }
    
    func aggregate(samples: [HeartRateData], windowStart: Date, userId: UUID) -> PhysiologicalSample? {
        // Filter to only valid heart rate readings
        let validSamples = samples.filter { $0.isValid }
        guard !validSamples.isEmpty else { return nil }
        
        // Calculate average heart rate
        let heartRates = validSamples.map { Double($0.heartRate) }
        let avgHeartRate = heartRates.reduce(0, +) / Double(heartRates.count)
        
        // Validate average heart rate is within acceptable range
        guard PhysiologicalSample.isValidHeartRate(avgHeartRate) else { return nil }
        
        // Collect all RR intervals from samples
        let allRRIntervals = validSamples.flatMap { $0.rrIntervals }
        
        // Calculate HRV metrics
        let rmssd = hrvCalculator.calculateRMSSD(rrIntervals: allRRIntervals)
        let sdnn = hrvCalculator.calculateSDNN(rrIntervals: allRRIntervals)
        
        return PhysiologicalSample(
            userId: userId,
            windowStart: windowStart,
            avgHeartRate: avgHeartRate,
            rmssd: rmssd,
            sdnn: sdnn,
            sampleCount: validSamples.count
        )
    }
}
