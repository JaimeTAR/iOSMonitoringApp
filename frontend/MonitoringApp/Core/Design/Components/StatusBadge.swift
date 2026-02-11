import SwiftUI

/// Color-coded badge for invitation code status
struct StatusBadge: View {
    let status: InvitationStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.appCaption)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.badgeColor)
            .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusBadge(status: .pending)
        StatusBadge(status: .used)
        StatusBadge(status: .expired)
        StatusBadge(status: .revoked)
    }
    .padding()
}
