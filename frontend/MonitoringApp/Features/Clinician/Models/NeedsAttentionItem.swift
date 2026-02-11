import Foundation

/// Reason a patient was flagged for clinician attention
enum AttentionReason: String {
    case inactivity
    case elevatedHeartRate
    case decliningHRV
}

/// A patient entry in the "Needs Attention" dashboard section
struct NeedsAttentionItem: Identifiable {
    let id: UUID
    let patientName: String
    let reason: AttentionReason
    let detail: String
}
