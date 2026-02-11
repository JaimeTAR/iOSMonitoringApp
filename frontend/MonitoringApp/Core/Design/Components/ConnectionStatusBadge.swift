import SwiftUI

enum ConnectionStatus {
    case connected
    case connecting
    case scanning
    case disconnected
    case bluetoothOff
    
    var color: Color {
        switch self {
        case .connected:
            return .statusGreen
        case .connecting, .scanning:
            return .statusYellow
        case .disconnected, .bluetoothOff:
            return .statusRed
        }
    }
    
    var text: String {
        switch self {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .scanning:
            return "Scanning..."
        case .disconnected:
            return "Disconnected"
        case .bluetoothOff:
            return "Bluetooth Off"
        }
    }
}

struct ConnectionStatusBadge: View {
    let status: ConnectionStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .overlay {
                    if status == .scanning {
                        Circle()
                            .stroke(status.color, lineWidth: 2)
                            .scaleEffect(1.5)
                            .opacity(0.5)
                    }
                }
            
            Text(status.text)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.appSurface)
        .cornerRadius(16)
    }
}

#Preview {
    VStack(spacing: 12) {
        ConnectionStatusBadge(status: .connected)
        ConnectionStatusBadge(status: .connecting)
        ConnectionStatusBadge(status: .scanning)
        ConnectionStatusBadge(status: .disconnected)
        ConnectionStatusBadge(status: .bluetoothOff)
    }
    .padding()
}
