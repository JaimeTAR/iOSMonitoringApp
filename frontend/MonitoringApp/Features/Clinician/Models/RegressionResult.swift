import Foundation

/// Result of ordinary least squares (OLS) linear regression on physiological samples.
/// Slope is expressed in BPM per second internally; use `slopePerWeek` for display.
struct RegressionResult {
    /// Slope in BPM per second
    let slope: Double
    /// Intercept in BPM (predicted value at epoch 0)
    let intercept: Double
    /// Start timestamp of the analyzed range
    let startDate: Date
    /// End timestamp of the analyzed range
    let endDate: Date

    /// Slope converted to BPM per week (slope × 604 800 seconds)
    var slopePerWeek: Double {
        slope * 604_800
    }
}
