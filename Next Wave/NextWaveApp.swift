import SwiftUI
import UserNotifications

@main
struct NextWaveApp: App {
    @StateObject private var viewModel = ScheduleViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
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
    
    init() {
        requestNotificationPermissions()
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
} 