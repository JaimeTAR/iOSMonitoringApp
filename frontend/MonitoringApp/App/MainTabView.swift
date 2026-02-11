import SwiftUI
import Auth

/// Main tab bar navigation for authenticated users
/// Contains Dashboard, Monitoring, History, Reports, and Profile tabs
struct MainTabView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    // Shared services
    // @StateObject private var bleService: BLEService
    @StateObject private var bleService: MockBLEService
    @StateObject private var sampleService: SampleService
    
    // Shared view models to persist across tab changes
    @StateObject private var bleViewModel: BLEViewModel
    @StateObject private var monitoringViewModel: MonitoringViewModel
    
    @State private var selectedTab: Tab = .dashboard
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        
        // Create shared services
        let bleService = MockBLEService(autoConnect: true)
        //let bleService = BLEService()
        let sampleService = SampleService()
        let monitoringVM = MonitoringViewModel(bleService: bleService, sampleService: sampleService)
        
        // Set user ID for sample storage
        if let userId = authViewModel.currentUser?.id {
            monitoringVM.setUserId(userId)
        }
        
        _bleService = StateObject(wrappedValue: bleService)
        _sampleService = StateObject(wrappedValue: sampleService)
        _bleViewModel = StateObject(wrappedValue: BLEViewModel(bleService: bleService))
        _monitoringViewModel = StateObject(wrappedValue: monitoringVM)
    }
    
    enum Tab: Int, CaseIterable {
        case dashboard
        case monitoring
        case history
        case reports
        case profile
        
        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .monitoring: return "Device"
            case .history: return "History"
            case .reports: return "Reports"
            case .profile: return "Profile"
            }
        }
        
        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .monitoring: return "waveform.path.ecg"
            case .history: return "chart.xyaxis.line"
            case .reports: return "sparkles"
            case .profile: return "person.fill"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            DashboardView(
                bleViewModel: bleViewModel,
                monitoringViewModel: monitoringViewModel,
                selectedTab: $selectedTab,
                sampleService: sampleService
            )
            .tabItem {
                Label(Tab.dashboard.title, systemImage: Tab.dashboard.icon)
            }
            .tag(Tab.dashboard)
            
            // Monitoring Tab
            monitoringTab
                .tabItem {
                    Label(Tab.monitoring.title, systemImage: Tab.monitoring.icon)
                }
                .tag(Tab.monitoring)
            
            // History Tab
            HistoryView(sampleService: sampleService)
                .tabItem {
                    Label(Tab.history.title, systemImage: Tab.history.icon)
                }
                .tag(Tab.history)
            
            // Reports Tab
            ReportsView()
                .tabItem {
                    Label(Tab.reports.title, systemImage: Tab.reports.icon)
                }
                .tag(Tab.reports)
            
            // Profile Tab
            ProfileView {
                Task {
                    await authViewModel.signOut()
                }
            }
            .tabItem {
                Label(Tab.profile.title, systemImage: Tab.profile.icon)
            }
            .tag(Tab.profile)
        }
        .tint(.appPrimary)
    }
    
    // MARK: - Monitoring Tab Content
    
    @ViewBuilder
    private var monitoringTab: some View {
        NavigationStack {
            BLEConnectionView(bleService: bleService)
        }
    }
}

#Preview {
    MainTabView(authViewModel: AuthViewModel())
}
