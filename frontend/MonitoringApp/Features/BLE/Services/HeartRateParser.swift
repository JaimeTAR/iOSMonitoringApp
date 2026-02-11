import Foundation

/// Parser for BLE Heart Rate Measurement characteristic (UUID: 0x2A37)
/// Follows Bluetooth SIG Heart Rate Service specification
struct HeartRateParser {
    
    // MARK: - Flag Bit Masks
    
    /// Bit 0: Heart Rate Value Format (0 = UINT8, 1 = UINT16)
    private static let heartRateFormatMask: UInt8 = 0x01
    
    /// Bits 1-2: Sensor Contact Status
    /// 00 or 01 = Sensor Contact feature not supported
    /// 10 = Sensor Contact feature supported, contact not detected
    /// 11 = Sensor Contact feature supported, contact detected
    private static let sensorContactSupportedMask: UInt8 = 0x04
    private static let sensorContactDetectedMask: UInt8 = 0x02
    
    /// Bit 3: Energy Expended Status (0 = not present, 1 = present)
    private static let energyExpendedMask: UInt8 = 0x08
    
    /// Bit 4: RR-Interval (0 = not present, 1 = one or more values present)
    private static let rrIntervalMask: UInt8 = 0x10
    
    // MARK: - Parsing
    
    /// Parse heart rate measurement data from BLE characteristic value
    /// - Parameter data: Raw data from Heart Rate Measurement characteristic
    /// - Returns: Parsed HeartRateData or nil if data is invalid
    static func parse(_ data: Data) -> HeartRateData? {
        guard data.count >= 2 else { return nil }
        
        let bytes = [UInt8](data)
        let flags = bytes[0]
        var offset = 1
        
        // Parse heart rate value
        let heartRate: Int
        if flags & heartRateFormatMask != 0 {
            // 16-bit heart rate value
            guard bytes.count >= offset + 2 else { return nil }
            heartRate = Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
            offset += 2
        } else {
            // 8-bit heart rate value
            heartRate = Int(bytes[offset])
            offset += 1
        }
        
        // Parse sensor contact status
        let sensorContact: Bool?
        if flags & sensorContactSupportedMask != 0 {
            sensorContact = (flags & sensorContactDetectedMask) != 0
        } else {
            sensorContact = nil
        }
        
        // Parse energy expended (if present)
        var energyExpended: Int? = nil
        if flags & energyExpendedMask != 0 {
            guard bytes.count >= offset + 2 else { return nil }
            energyExpended = Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
            offset += 2
        }
        
        // Parse RR intervals (if present)
        var rrIntervals: [Double] = []
        if flags & rrIntervalMask != 0 {
            while offset + 1 < bytes.count {
                let rrValue = Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
                // RR interval is in 1/1024 seconds, convert to seconds
                let rrSeconds = Double(rrValue) / 1024.0
                rrIntervals.append(rrSeconds)
                offset += 2
            }
        }
        
        return HeartRateData(
            heartRate: heartRate,
            sensorContact: sensorContact,
            energyExpended: energyExpended,
            rrIntervals: rrIntervals
        )
    }
    
    /// Validate if heart rate is within physiological range
    /// - Parameter heartRate: Heart rate in BPM
    /// - Returns: True if within valid range (30-220 BPM)
    static func isValidHeartRate(_ heartRate: Int) -> Bool {
        heartRate >= 30 && heartRate <= 220
    }
}
