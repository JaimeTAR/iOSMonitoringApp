import Foundation
import Combine

/// Protocol defining sample service capabilities for physiological data storage
protocol SampleServiceProtocol: ObservableObject {
    /// Number of samples pending sync
    var pendingSyncCount: Int { get }
    
    /// Whether a sync operation is in progress
    var isSyncing: Bool { get }
    
    /// Saves a physiological sample locally with isSynced flag
    /// - Parameter sample: The sample to save
    /// - Throws: SampleError if save fails
    func saveSample(_ sample: PhysiologicalSample) async throws
    
    /// Fetches samples within a date range
    /// - Parameters:
    ///   - from: Start date (inclusive)
    ///   - to: End date (inclusive)
    /// - Returns: Array of samples within the range
    /// - Throws: SampleError if fetch fails
    func fetchSamples(from: Date, to: Date) async throws -> [PhysiologicalSample]
    
    /// Syncs all pending (unsynced) samples to the server
    /// - Throws: SampleError if sync fails
    func syncPendingSamples() async throws
}
