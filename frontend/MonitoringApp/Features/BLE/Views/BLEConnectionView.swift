import SwiftUI

/// View for managing BLE heart rate sensor connection
struct BLEConnectionView: View {
    @StateObject private var viewModel: BLEViewModel
    
    init(bleService: any BLEServiceProtocol) {
        _viewModel = StateObject(wrappedValue: BLEViewModel(bleService: bleService))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Connection Status Header
                connectionStatusSection
                
                // Main Content based on state
                if viewModel.isBluetoothOff {
                    bluetoothDisabledSection
                } else if viewModel.isConnected {
                    connectedDeviceSection
                } else if viewModel.isScanning {
                    scanningSection
                } else if viewModel.isConnecting {
                    connectingSection
                } else {
                    disconnectedSection
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Heart Rate Sensor")
        .navigationBarTitleDisplayMode(.large)
        .alert("Connection Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Connection Status Section
    
    private var connectionStatusSection: some View {
        HStack {
            Text("Status")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            Spacer()
            
            ConnectionStatusBadge(status: viewModel.connectionStatus)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    // MARK: - Bluetooth Disabled Section
    
    private var bluetoothDisabledSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "bluetooth.slash")
                .font(.system(size: 48))
                .foregroundColor(.statusRed)
            
            Text("Bluetooth is Disabled")
                .font(.appTitle)
                .foregroundColor(.appTextPrimary)
            
            Text("Please enable Bluetooth in your device settings to connect to your heart rate monitor.")
                .font(.appBody)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(.appHeadline)
                .foregroundColor(.appPrimary)
            }
            .padding(.top, 8)
        }
        .padding(32)
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    // MARK: - Disconnected Section
    
    private var disconnectedSection: some View {
        VStack(spacing: 20) {
            // Quick Connect (if remembered device exists)
            if viewModel.hasRememberedDevice {
                quickConnectCard
            }
            
            // Scan Button
            PrimaryButton(title: "Scan for Devices", action: {
                viewModel.startScanning()
            })
            
            // Help text
            Text("Make sure your heart rate monitor is powered on and nearby.")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Quick Connect Card
    
    private var quickConnectCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.appPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Connected")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                    
                    Text(viewModel.rememberedDeviceName ?? "Unknown Device")
                        .font(.appHeadline)
                        .foregroundColor(.appTextPrimary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button {
                    viewModel.quickConnect()
                } label: {
                    Text("Quick Connect")
                        .font(.appHeadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.appPrimary)
                        .cornerRadius(8)
                }
                
                Button {
                    viewModel.forgetDevice()
                } label: {
                    Text("Forget")
                        .font(.appHeadline)
                        .foregroundColor(.appTextSecondary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.appSurface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.appBorder, lineWidth: 1)
                        )
                }
            }
        }
        .padding()
        .background(Color.appSurfaceElevated)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Scanning Section
    
    private var scanningSection: some View {
        VStack(spacing: 20) {
            // Scanning indicator
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.appPrimary)
                
                Text("Scanning for devices...")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.vertical, 24)
            
            // Discovered devices list
            if !viewModel.discoveredDevices.isEmpty {
                discoveredDevicesList
            }
            
            // Stop scanning button
            Button {
                viewModel.stopScanning()
            } label: {
                Text("Stop Scanning")
                    .font(.appHeadline)
                    .foregroundColor(.appTextSecondary)
            }
        }
    }
    
    // MARK: - Discovered Devices List
    
    private var discoveredDevicesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discovered Devices")
                .font(.appHeadline)
                .foregroundColor(.appTextPrimary)
            
            ForEach(viewModel.discoveredDevices) { device in
                DiscoveredDeviceRow(device: device) {
                    viewModel.connect(to: device)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    // MARK: - Connecting Section
    
    private var connectingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.appPrimary)
            
            Text("Connecting...")
                .font(.appTitle)
                .foregroundColor(.appTextPrimary)
            
            Text("Please wait while we establish a connection to your device.")
                .font(.appBody)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(Color.appSurface)
        .cornerRadius(16)
    }
    
    // MARK: - Connected Device Section
    
    private var connectedDeviceSection: some View {
        VStack(spacing: 20) {
            // Connected device card
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.statusGreen)
                
                Text(viewModel.connectedDeviceName ?? "Heart Rate Monitor")
                    .font(.appTitle)
                    .foregroundColor(.appTextPrimary)
                
                Text("Connected and receiving data")
                    .font(.appBody)
                    .foregroundColor(.appTextSecondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color.appSurface)
            .cornerRadius(16)
            
            // Disconnect button
            Button {
                viewModel.disconnect()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Disconnect")
                }
                .font(.appHeadline)
                .foregroundColor(.statusRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.appSurface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.statusRed, lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Discovered Device Row

private struct DiscoveredDeviceRow: View {
    let device: DiscoveredDevice
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.appPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.appHeadline)
                        .foregroundColor(.appTextPrimary)
                    
                    Text(signalStrengthText)
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
                
                Spacer()
                
                // Signal strength indicator
                signalStrengthIcon
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.appTextSecondary)
            }
            .padding()
            .background(Color.appSurfaceElevated)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var signalStrengthText: String {
        switch device.rssi {
        case -50...0:
            return "Excellent signal"
        case -70..<(-50):
            return "Good signal"
        case -85..<(-70):
            return "Fair signal"
        default:
            return "Weak signal"
        }
    }
    
    private var signalStrengthIcon: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < signalBars ? Color.statusGreen : Color.appBorder)
                    .frame(width: 4, height: CGFloat(6 + index * 3))
            }
        }
    }
    
    private var signalBars: Int {
        switch device.rssi {
        case -50...0:
            return 4
        case -65..<(-50):
            return 3
        case -80..<(-65):
            return 2
        default:
            return 1
        }
    }
}

#Preview {
    NavigationStack {
        BLEConnectionView(bleService: BLEService())
    }
}
