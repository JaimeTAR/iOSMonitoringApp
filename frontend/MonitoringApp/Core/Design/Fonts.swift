import SwiftUI

extension Font {
    // MARK: - Typography Scale
    static let appLargeTitle = Font.system(size: 34, weight: .bold)
    static let appTitle = Font.system(size: 28, weight: .bold)
    static let appTitle2 = Font.system(size: 22, weight: .bold)
    static let appHeadline = Font.system(size: 17, weight: .semibold)
    static let appBody = Font.system(size: 17, weight: .regular)
    static let appCallout = Font.system(size: 16, weight: .regular)
    static let appSubheadline = Font.system(size: 15, weight: .regular)
    static let appFootnote = Font.system(size: 13, weight: .regular)
    static let appCaption = Font.system(size: 12, weight: .regular)
    static let appCaption2 = Font.system(size: 11, weight: .regular)
    
    // MARK: - Special Display Fonts
    static let heartRateDisplay = Font.system(size: 72, weight: .bold, design: .rounded)
    static let heartRateDisplaySmall = Font.system(size: 48, weight: .bold, design: .rounded)
    static let metricDisplay = Font.system(size: 32, weight: .semibold, design: .rounded)
}
