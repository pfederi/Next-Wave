import SwiftUI
import UserNotifications

@main
struct NextWaveApp: App {
    @StateObject private var viewModel = ScheduleViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        requestNotificationPermissions()
        // Setze die Hintergrundfarbe für die gesamte App
        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.backgroundColor = UIColor(Color("secondary-color"))
        
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
        
        // Setze die Hintergrundfarbe für die gesamte App
        UITableView.appearance().backgroundColor = UIColor(Color("secondary-color"))
        UICollectionView.appearance().backgroundColor = UIColor(Color("secondary-color"))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { 
                    if scenePhase == .active {
                        Task {
                            await MainActor.run {
                                viewModel.appWillEnterForeground()
                            }
                        }
                    }
                }
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
}