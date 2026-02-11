import Foundation
import Combine
import Network

/// Monitors network connectivity status
@MainActor
final class NetworkMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    // MARK: - Private Properties
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Types
    
    enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
    }
    
    // MARK: - Initialization
    
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            let connectionType = NetworkMonitor.getConnectionType(path)
            Task { @MainActor [weak self] in
                self?.isConnected = isConnected
                self?.connectionType = connectionType
            }
        }
        monitor.start(queue: queue)
    }
    
    private nonisolated static func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        }
        return .unknown
    }
}
