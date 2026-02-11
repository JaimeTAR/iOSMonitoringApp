import SwiftUI

struct HeartRateDisplay: View {
    let heartRate: Int?
    var showUnit: Bool = true
    var size: DisplaySize = .large
    
    enum DisplaySize {
        case small
        case large
        
        var font: Font {
            switch self {
            case .small:
                return .heartRateDisplaySmall
            case .large:
                return .heartRateDisplay
            }
        }
        
        var unitFont: Font {
            switch self {
            case .small:
                return .appCaption
            case .large:
                return .appSubheadline
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            if let heartRate = heartRate {
                Text("\(heartRate)")
                    .font(size.font)
                    .foregroundColor(Color.heartRateColor(for: heartRate))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: heartRate)
                
                if showUnit {
                    Text("BPM")
                        .font(size.unitFont)
                        .foregroundColor(.appTextSecondary)
                }
            } else {
                Text("--")
                    .font(size.font)
                    .foregroundColor(.appTextSecondary)
                
                if showUnit {
                    Text("BPM")
                        .font(size.unitFont)
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        HeartRateDisplay(heartRate: 72)
        HeartRateDisplay(heartRate: 55)
        HeartRateDisplay(heartRate: 110)
        HeartRateDisplay(heartRate: 150)
        HeartRateDisplay(heartRate: nil)
        HeartRateDisplay(heartRate: 72, size: .small)
    }
    .padding()
}
