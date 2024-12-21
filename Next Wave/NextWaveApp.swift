import SwiftUI
import UserNotifications

@main
struct NextWaveApp: App {
    @StateObject private var viewModel = ScheduleViewModel()
    @StateObject private var appSettings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemColorScheme
    
    init() {
        requestNotificationPermissions()
        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.backgroundColor = UIColor(Color("background-color"))
        
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
        
        UITableView.appearance().backgroundColor = UIColor(Color("background-color"))
        UICollectionView.appearance().backgroundColor = UIColor(Color("background-color"))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(appSettings)
                .preferredColorScheme(appSettings.theme == .system ? nil : (appSettings.isDarkMode ? .dark : .light))
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
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
        }
    }
}