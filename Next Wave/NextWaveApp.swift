import SwiftUI
import UserNotifications
import BackgroundTasks

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.nextwave.midnight", using: nil) { task in
            if let task = task as? BGProcessingTask {
                self.handleBackgroundTask(task)
            }
        }
        scheduleMidnightTask()
    }
    
    private func scheduleMidnightTask() {
        let request = BGProcessingTaskRequest(identifier: "com.nextwave.midnight")
        
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
              let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return
        }
        
        request.earliestBeginDate = nextMidnight
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled for midnight")
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
    
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("MidnightUpdate"), object: nil)
        
        scheduleMidnightTask()
        
        task.setTaskCompleted(success: true)
    }
}

@main
struct NextWaveApp: App {
    @StateObject private var appSettings: AppSettings
    @StateObject private var viewModel: ScheduleViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemColorScheme
    
    init() {
        let appSettings = AppSettings()
        let viewModel = ScheduleViewModel(appSettings: appSettings)
        self._appSettings = StateObject(wrappedValue: appSettings)
        self._viewModel = StateObject(wrappedValue: viewModel)
        
        requestNotificationPermissions()
        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.backgroundColor = UIColor(Color("background-color"))
        
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
        
        UITableView.appearance().backgroundColor = UIColor(Color("background-color"))
        UICollectionView.appearance().backgroundColor = UIColor(Color("background-color"))
        
        BackgroundTaskManager.shared.registerBackgroundTasks()
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