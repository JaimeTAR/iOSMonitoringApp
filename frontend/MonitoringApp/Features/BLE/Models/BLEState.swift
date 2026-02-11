import Foundation
import CoreBluetooth

/// Represents the current state of the BLE service
enum BLEState: Equatable {
    case unknown
    case poweredOff
    case unauthorized
    case poweredOn
    case scanning
    case connecting(DiscoveredDevice)
    case connected(ConnectedDevice)
    case disconnected
    
    static func == (lhs: BLEState, rhs: BLEState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown),
             (.poweredOff, .poweredOff),
             (.unauthorized, .unauthorized),
             (.poweredOn, .poweredOn),
             (.scanning, .scanning),
             (.disconnected, .disconnected):
            return true
        case (.connecting(let lDevice), .connecting(let rDevice)):
            return lDevice.id == rDevice.id
        case (.connected(let lDevice), .connected(let rDevice)):
            return lDevice.id == rDevice.id
        default:
            return false
        }
    }
}
