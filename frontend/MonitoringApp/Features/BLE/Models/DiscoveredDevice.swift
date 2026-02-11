import Foundation
import CoreBluetooth

/// Represents a BLE device discovered during scanning
struct DiscoveredDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int
    let advertisementData: [String: Any]
    
    init(peripheral: CBPeripheral, rssi: Int, advertisementData: [String: Any]) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
        self.rssi = rssi
        self.advertisementData = advertisementData
    }
}

extension DiscoveredDevice: Equatable {
    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}

extension DiscoveredDevice: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
