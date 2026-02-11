import Foundation

/// Protocol for HRV (Heart Rate Variability) calculations
protocol HRVCalculatorProtocol {
    /// Calculate RMSSD (Root Mean Square of Successive Differences) from RR intervals
    /// - Parameter rrIntervals: Array of RR intervals in seconds
    /// - Returns: RMSSD value in milliseconds, or nil if insufficient data
    func calculateRMSSD(rrIntervals: [Double]) -> Double?
    
    /// Calculate SDNN (Standard Deviation of NN intervals) from RR intervals
    /// - Parameter rrIntervals: Array of RR intervals in seconds
    /// - Returns: SDNN value in milliseconds, or nil if insufficient data
    func calculateSDNN(rrIntervals: [Double]) -> Double?
}

/// HRV calculator implementation for computing heart rate variability metrics
struct HRVCalculator: HRVCalculatorProtocol {
    
    // MARK: - Configuration
    
    /// Minimum number of RR intervals required for calculations
    private let minimumIntervals = 2
    
    /// Minimum valid RR interval in seconds (corresponds to ~200 BPM)
    private let minRRInterval: Double = 0.3
    
    /// Maximum valid RR interval in seconds (corresponds to ~30 BPM)
    private let maxRRInterval: Double = 2.0
    
    // MARK: - HRVCalculatorProtocol
    
    /// Root Mean Square of Successive Differences
    /// Measures short-term HRV and reflects parasympathetic activity
    /// Requires minimum 2 RR intervals
    func calculateRMSSD(rrIntervals: [Double]) -> Double? {
        let filtered = filterOutliers(rrIntervals)
        guard filtered.count >= minimumIntervals else { return nil }
        
        var sumSquaredDiffs: Double = 0
        for i in 1..<filtered.count {
            let diff = filtered[i] - filtered[i - 1]
            sumSquaredDiffs += diff * diff
        }
        
        let rmssd = sqrt(sumSquaredDiffs / Double(filtered.count - 1))
        // Convert from seconds to milliseconds
        return rmssd * 1000
    }
    
    /// Standard Deviation of NN intervals
    /// Measures overall HRV and reflects both sympathetic and parasympathetic activity
    /// Requires minimum 2 RR intervals
    func calculateSDNN(rrIntervals: [Double]) -> Double? {
        let filtered = filterOutliers(rrIntervals)
        guard filtered.count >= minimumIntervals else { return nil }
        
        let mean = filtered.reduce(0, +) / Double(filtered.count)
        let variance = filtered.map { pow($0 - mean, 2) }.reduce(0, +) / Double(filtered.count)
        let sdnn = sqrt(variance)
        
        // Convert from seconds to milliseconds
        return sdnn * 1000
    }
    
    // MARK: - Private Helpers
    
    /// Filter out physiologically implausible RR intervals
    /// - Parameter rrIntervals: Raw RR intervals in seconds
    /// - Returns: Filtered array with outliers removed
    private func filterOutliers(_ rrIntervals: [Double]) -> [Double] {
        rrIntervals.filter { interval in
            interval >= minRRInterval && interval <= maxRRInterval
        }
    }
}
