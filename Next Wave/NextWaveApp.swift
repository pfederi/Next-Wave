import SwiftUI
import UserNotifications
import BackgroundTasks

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    func registerBackgroundTasks() {
        // Register midnight task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.nextwave.midnight", using: nil) { task in
            if let task = task as? BGProcessingTask {
                self.handleMidnightTask(task)
            }
        }
        
        // Register evening widget refresh task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.nextwave.widget-refresh", using: nil) { task in
            if let task = task as? BGProcessingTask {
                self.handleWidgetRefreshTask(task)
            }
        }
        
        scheduleMidnightTask()
        scheduleWidgetRefreshTask()
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
            // Background task scheduled for midnight
        } catch {
            // Could not schedule background task
        }
    }
    
    private func handleMidnightTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("MidnightUpdate"), object: nil)
        
        scheduleMidnightTask()
        
        task.setTaskCompleted(success: true)
    }
    
    private func handleWidgetRefreshTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Load fresh departure data for widgets
        Task {
            await refreshWidgetData()
            task.setTaskCompleted(success: true)
        }
        
        // Schedule next widget refresh
        scheduleWidgetRefreshTask()
    }
    
    private func scheduleWidgetRefreshTask() {
        let request = BGProcessingTaskRequest(identifier: "com.nextwave.widget-refresh")
        
        let calendar = Calendar.current
        let now = Date()
        
        // Schedule for 17:00 today, or 17:00 tomorrow if it's already past 17:00
        let hour = calendar.component(.hour, from: now)
        let targetTime: Date
        
        if hour < 17 {
            // Schedule for 17:00 today
            targetTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now) ?? now
        } else {
            // Schedule for 17:00 tomorrow
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            targetTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        }
        
        request.earliestBeginDate = targetTime
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📱 Scheduled widget refresh task for \(targetTime)")
        } catch {
            print("📱 Could not schedule widget refresh task: \(error)")
        }
    }
    
    @MainActor
    private func refreshWidgetData() async {
        print("🔄 Background widget data refresh started")
        
        // Check if widget requested refresh
        let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
        _ = userDefaults?.bool(forKey: "widget_needs_fresh_data") ?? false
        
        // Always try to refresh widget data in background, not just when requested
        let favorites = FavoriteStationsManager.shared.favorites
        if !favorites.isEmpty {
            print("🔄 Loading fresh departure data for \(favorites.count) favorite stations")
            
            // Load fresh departure data
            await FavoriteStationsManager.shared.loadDepartureDataForWidgets()
            
            // Clear any refresh flags
            userDefaults?.set(false, forKey: "widget_needs_fresh_data")
            userDefaults?.removeObject(forKey: "widget_requested_refresh")
            
            print("🔄 Background widget data refresh completed")
        } else {
            print("🔄 No favorite stations - skipping background refresh")
        }
    }
}

@main
struct NextWaveApp: App {
    @StateObject private var appSettings: AppSettings
    @StateObject private var viewModel: ScheduleViewModel
    @StateObject private var lakeStationsViewModel = LakeStationsViewModel()
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
                .environmentObject(lakeStationsViewModel)
                .preferredColorScheme(appSettings.theme == .system ? nil : (appSettings.isDarkMode ? .dark : .light))
                .task {
                    // Preload weather data first (faster, more important for users)
                    await WeatherAPI.shared.preloadData()
                    
                    // Then preload vessel data
                    await VesselAPI.shared.preloadData()
                    
                    // Load widget data when app first launches
                    await loadWidgetDataOnAppStart()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        Task {
                            await MainActor.run {
                                viewModel.appWillEnterForeground()
                            }
                            
                            // Load widget data every time app becomes active
                            await loadWidgetDataOnAppStart()
                        }
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    @MainActor
    private func loadWidgetDataOnAppStart() async {
        print("🚀 App became active - loading widget data...")
        
        // Check if we have favorite stations
        let favorites = FavoriteStationsManager.shared.favorites
        if favorites.isEmpty {
            print("🚀 No favorite stations - skipping widget data load")
            return
        }
        
        // Check when data was last refreshed
        let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
        let lastRefresh = userDefaults?.object(forKey: "last_data_refresh") as? Date
        let timeAgo = abs(lastRefresh?.timeIntervalSinceNow ?? 86400) // Default to 24h ago
        
        // Load widget data if it's old (> 30 minutes) or doesn't exist
        if timeAgo > 1800 { // 30 minutes
            print("🚀 Widget data is \(Int(timeAgo/60)) minutes old - refreshing...")
            await FavoriteStationsManager.shared.loadDepartureDataForWidgets()
            print("🚀 Widget data refresh completed")
        } else {
            print("🚀 Widget data is fresh (\(Int(timeAgo/60)) minutes old) - skipping refresh")
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("🔗 Deep link received: \(url)")
        
        guard url.scheme == "nextwave" else {
            print("🔗 Invalid scheme: \(url.scheme ?? "nil")")
            return
        }
        
        if url.host == "station" {
            // Parse station name and date from query parameters
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            guard let stationName = components?.queryItems?.first(where: { $0.name == "name" })?.value else {
                print("🔗 No station name in deep link")
                return
            }
            
            // Parse optional date parameter (ISO format: YYYY-MM-DD)
            var targetDate: Date? = nil
            if let dateString = components?.queryItems?.first(where: { $0.name == "date" })?.value {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                targetDate = formatter.date(from: dateString)
                print("🔗 Deep link date parameter: \(dateString) -> \(targetDate?.description ?? "invalid")")
            }
            
            print("🔗 Opening station: \(stationName)" + (targetDate != nil ? " on \(targetDate!)" : ""))
            
            // Find the station by name and select it
            Task { @MainActor in
                await lakeStationsViewModel.loadLakes()
                
                // Search for the station across all lakes
                for lake in lakeStationsViewModel.lakes {
                    if let station = lake.stations.first(where: { $0.name == stationName }) {
                        print("🔗 Found station: \(station.name) with ID: \(station.id)")
                        
                        // Set the target date if provided
                        if let targetDate = targetDate {
                            print("🔗 Setting date to: \(targetDate)")
                            lakeStationsViewModel.selectedDate = targetDate
                            viewModel.selectedDate = targetDate
                        }
                        
                        // Select the station (this will trigger departure loading)
                        lakeStationsViewModel.selectStation(station)
                        return
                    }
                }
                
                print("🔗 Station not found: \(stationName)")
            }
        } else {
            print("🔗 Unknown deep link host: \(url.host ?? "nil")")
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
        }
    }
}