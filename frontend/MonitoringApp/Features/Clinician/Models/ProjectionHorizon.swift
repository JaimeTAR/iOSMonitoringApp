import Foundation

/// Horizonte de proyección predictiva
enum ProjectionHorizon: String, CaseIterable {
    case oneWeek = "1 sem"
    case twoWeeks = "2 sem"
    case fourWeeks = "4 sem"

    var weeks: Int {
        switch self {
        case .oneWeek: return 1
        case .twoWeeks: return 2
        case .fourWeeks: return 4
        }
    }

    /// Calcula la fecha futura desde una fecha de referencia
    func targetDate(from reference: Date) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: reference) ?? reference
    }
}
