import Foundation

/// Result of IQR-based outlier detection on physiological samples.
/// Partitions input samples into inliers (within IQR bounds) and outliers (outside IQR bounds).
struct OutlierResult {
    let inliers: [PhysiologicalSample]
    let outliers: [PhysiologicalSample]
}
