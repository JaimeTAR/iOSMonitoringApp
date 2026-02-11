import Foundation
import CoreBluetooth

/// Represents a connected BLE heart rate device
struct ConnectedDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral?
    let name: String
    
    init(peripheral: CBPeripheral) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Unknown Device"
    }
    
    /// Mock initializer for testing/previews
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.peripheral = nil
        self.name = name
    }
}

extension ConnectedDevice: Equatable {
    static func == (lhs: ConnectedDevice, rhs: ConnectedDevice) -> Bool {
        lhs.id == rhs.id
    }
}
