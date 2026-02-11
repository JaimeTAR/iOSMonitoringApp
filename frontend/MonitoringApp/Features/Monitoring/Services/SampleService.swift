import Foundation
import Combine
import Supabase

/// Service handling physiological sample storage with offline support
@MainActor
final class SampleService: ObservableObject, SampleServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var pendingSyncCount: Int = 0
    @Published private(set) var isSyncing: Bool = false
    
    // MARK: - Private Properties
    
    private let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let pendingSamples = "pending_physiological_samples"
    }
    
    // MARK: - Initialization
    
    init(networkMonitor: NetworkMonitor? = nil) {
        self.networkMonitor = networkMonitor ?? NetworkMonitor.shared
        loadPendingCount()
        setupNetworkObserver()
    }
    
    // MARK: - SampleServiceProtocol
    
    func saveSample(_ sample: PhysiologicalSample) async throws {
        // Validate sample
        guard sample.isValid else {
            throw SampleError.invalidSample("Heart rate or HRV values out of range")
        }
        
        // Check if online
        if networkMonitor.isConnected {
            do {
                try await saveToServer(sample)
            } catch {
                // If server save fails, save locally
                saveLocally(sample)
                throw SampleError.saveFailed(error.localizedDescription)
            }
        } else {
            // Save locally for later sync
            saveLocally(sample)
        }
    }
    
    func fetchSamples(from: Date, to: Date) async throws -> [PhysiologicalSample] {
        // Get current user
        guard let user = try? await supabase.auth.session.user else {
            // Return cached samples if offline
            return getCachedSamples(from: from, to: to)
        }
        
        do {
            let samples: [PhysiologicalSample] = try await supabase
                .from("physiological_samples")
                .select()
                .eq("user_id", value: user.id)
                .gte("window_start", value: ISO8601DateFormatter().string(from: from))
                .lte("window_start", value: ISO8601DateFormatter().string(from: to))
                .order("window_start", ascending: false)
                .execute()
                .value
            
            return samples
        } catch {
            // Return cached samples if network fails
            let cached = getCachedSamples(from: from, to: to)
            if !cached.isEmpty {
                return cached
            }
            throw SampleError.fetchFailed(error.localizedDescription)
        }
    }
    
    func syncPendingSamples() async throws {
        guard networkMonitor.isConnected else {
            throw SampleError.networkUnavailable
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let pendingSamples = getPendingSamples()
        guard !pendingSamples.isEmpty else { return }
        
        var failedSamples: [PhysiologicalSample] = []
        
        for sample in pendingSamples {
            do {
                try await saveToServer(sample)
            } catch {
                failedSamples.append(sample)
            }
        }
        
        // Update pending samples with only failed ones
        savePendingSamples(failedSamples)
        pendingSyncCount = failedSamples.count
        
        if !failedSamples.isEmpty {
            throw SampleError.syncFailed("\(failedSamples.count) samples failed to sync")
        }
    }
    
    // MARK: - Private Methods
    
    private func saveToServer(_ sample: PhysiologicalSample) async throws {
        let insertData = SampleInsertData(
            userId: sample.userId,
            windowStart: sample.windowStart,
            avgHeartRate: sample.avgHeartRate,
            rmssd: sample.rmssd,
            sdnn: sample.sdnn,
            sampleCount: sample.sampleCount
        )
        
        try await supabase
            .from("physiological_samples")
            .insert(insertData)
            .execute()
    }
    
    private func saveLocally(_ sample: PhysiologicalSample) {
        var pending = getPendingSamples()
        pending.append(sample)
        savePendingSamples(pending)
        pendingSyncCount = pending.count
    }
    
    private func getPendingSamples() -> [PhysiologicalSample] {
        guard let data = UserDefaults.standard.data(forKey: CacheKeys.pendingSamples),
              let samples = try? JSONDecoder().decode([PhysiologicalSample].self, from: data) else {
            return []
        }
        return samples
    }
    
    private func savePendingSamples(_ samples: [PhysiologicalSample]) {
        if let encoded = try? JSONEncoder().encode(samples) {
            UserDefaults.standard.set(encoded, forKey: CacheKeys.pendingSamples)
        }
    }
    
    private func getCachedSamples(from: Date, to: Date) -> [PhysiologicalSample] {
        getPendingSamples().filter { sample in
            sample.windowStart >= from && sample.windowStart <= to
        }
    }
    
    private func loadPendingCount() {
        pendingSyncCount = getPendingSamples().count
    }
    
    private func setupNetworkObserver() {
        networkMonitor.$isConnected
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { [weak self] in
                    try? await self?.syncPendingSamples()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Helper Models

/// Model for inserting samples to database (excludes auto-generated fields)
private struct SampleInsertData: Codable {
    let userId: UUID
    let windowStart: Date
    let avgHeartRate: Double
    let rmssd: Double?
    let sdnn: Double?
    let sampleCount: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case windowStart = "window_start"
        case avgHeartRate = "avg_heart_rate"
        case rmssd
        case sdnn
        case sampleCount = "sample_count"
    }
}
