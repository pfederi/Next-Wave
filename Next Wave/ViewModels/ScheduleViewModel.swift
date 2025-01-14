import Foundation
import UserNotifications
import SwiftUI
import BackgroundTasks

// Helper extension for async map
extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            try await values.append(transform(element))
        }
        return values
    }
}

class ScheduleViewModel: ObservableObject {
    @Published private(set) var settings: Settings {
        didSet {
            saveSettings()
        }
    }
    
    struct Settings: Codable {
        var leadTime: Int
        var selectedSound: String
        var shipName: String
        
        static let `default` = Settings(
            leadTime: 5,
            selectedSound: "boat-horn",
            shipName: "Unknown"
        )
    }
    
    let availableSounds = [
        "boat-horn": "Boat Horn",
        "happy": "Happy Tune",
        "let-the-fun-begin": "Fun Time",
        "short-beep": "Short Beep",
        "ukulele": "Ukulele",
        "system": "System Sound"
    ]
    
    @Published var notifiedJourneys: Set<String> = []
    @Published var selectedDate: Date = Date() {
        didSet {
            if !Calendar.current.isDate(selectedDate, inSameDayAs: oldValue) {
                // Clear waves when date changes
                nextWaves = []
                hasAttemptedLoad = false
            }
        }
    }
    @Published var hasAttemptedLoad: Bool = false
    @Published var nextWaves: [WaveEvent] = []
    
    private let userDefaults = UserDefaults.standard
    private let notifiedJourneysKey = "com.nextwave.notifiedJourneys"
    private let settingsKey = "app.settings"
    
    private var midnightTimer: Timer?
    
    init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
        loadNotifications()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMidnightUpdate),
            name: NSNotification.Name("MidnightUpdate"),
            object: nil
        )
    }
    
    deinit {
        midnightTimer?.invalidate()
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }
    
    func updateLeadTime(_ newValue: Int) {
        settings = Settings(leadTime: newValue, selectedSound: settings.selectedSound, shipName: settings.shipName)
    }
    
    func updateSound(_ newValue: String) {
        settings = Settings(leadTime: settings.leadTime, selectedSound: newValue, shipName: settings.shipName)
    }
    
    func updateWaves(from departures: [Journey]) {
        let waves = departures.map { journey -> WaveEvent in
            let routeNumber = (journey.name ?? "Unknown")
                .replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
            
            let departureTime = AppDateFormatter.parseFullTime(journey.stop.departure ?? "") ?? Date()
            let nextStation = journey.passList?.dropFirst().first?.station
            
            // Nur ZSG Stationen (85036 prefix)
            let isZurichsee = journey.stop.station.id.hasPrefix("85036")
            
            return WaveEvent(
                time: departureTime,
                isArrival: journey.stop.arrival != nil,
                routeNumber: routeNumber,
                routeName: journey.stop.station.name ?? "Unknown",
                neighborStop: journey.to ?? journey.stop.station.id,
                neighborStopName: nextStation?.name ?? "Unknown",
                period: "regular",
                lake: isZurichsee ? "Zürichsee" : "Unknown",
                shipName: nil,
                hasNotification: false
            )
        }
        
        nextWaves = waves
        hasAttemptedLoad = true
        
        // Load ship names asynchronously only for Lake Zurich
        Task {
            for index in waves.indices where waves[index].isZurichsee {
                if let shipName = await VesselAPI.shared.findShipName(
                    for: waves[index].routeNumber,
                    date: selectedDate
                ) {
                    await MainActor.run {
                        nextWaves[index].updateShipName(shipName)
                    }
                }
            }
        }
    }
    
    private func loadNotifications() {
        notifiedJourneys.removeAll()
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                let currentDate = Date()
                let calendar = Calendar.current
                
                let validRequests = requests.filter { request in
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                       let triggerDate = trigger.nextTriggerDate() {
                        return calendar.isDate(triggerDate, inSameDayAs: currentDate)
                    }
                    return false
                }
                
                self.notifiedJourneys = Set(validRequests.map { $0.identifier })
                self.saveNotifications()
                
                let expiredIds = requests
                    .filter { !validRequests.contains($0) }
                    .map { $0.identifier }
                
                if !expiredIds.isEmpty {
                    print("Removing \(expiredIds.count) expired notifications")
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: expiredIds)
                }
            }
        }
    }
    
    func hasNotification(for wave: WaveEvent) -> Bool {
        return notifiedJourneys.contains(wave.id)
    }
    
    func scheduleNotification(for wave: WaveEvent) {
        if wave.time < Date() { return }
        
        let content = UNMutableNotificationContent()
        let notificationMessages = [
            "Wave is coming, get ready!",
            "Wave is coming, don't mess up the start!",
            "Surf's up! Time to catch that wave!",
            "Ready, set, wave!",
            "Your wave taxi is arriving soon!",
            "Time to ride that wave!",
            "Wave alert! Don't be late!",
            "Your wave chariot awaits!",
            "Catch the wave or catch regrets!",
            "Wave o'clock - Time to roll!",
            "Your ticket to ride is approaching!",
            "The wave waits for no one!",
            "Surf's calling - Will you answer?",
            "Wave spotted on the horizon!",
            "All aboard the wave train!",
            "Time to make waves!",
            "Your wave adventure begins soon!"
        ]
        
        content.title = "Next Wave"
        content.body = notificationMessages.randomElement() ?? "Get ready to surf!"
        content.sound = getNotificationSound()
        
        let triggerDate = Calendar.current.date(byAdding: .minute, value: -settings.leadTime, to: wave.time)!
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: wave.id,
                                          content: content,
                                          trigger: trigger)
        
        print("Scheduling notification for: \(triggerDate)")
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self?.notifiedJourneys.insert(wave.id)
                    self?.saveNotifications()
                    self?.objectWillChange.send()
                    print("Notification scheduled successfully")
                }
            }
        }
    }
    
    func removeNotification(for wave: WaveEvent) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [wave.id])
        notifiedJourneys.remove(wave.id)
        saveNotifications()
        objectWillChange.send()
    }
    
    private func saveNotifications() {
        userDefaults.set(Array(notifiedJourneys), forKey: notifiedJourneysKey)
    }
    
    func appWillEnterForeground() {
        loadNotifications()
    }
    
    func reset() {
        nextWaves = []
        hasAttemptedLoad = false
    }
    
    private func getNotificationSound() -> UNNotificationSound {
        if settings.selectedSound == "system" {
            return .default
        }
        
        if let soundURL = Bundle.main.url(forResource: settings.selectedSound, withExtension: "wav") {
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: soundURL.lastPathComponent))
        }
        
        return .default
    }
    
    @objc private func handleMidnightUpdate() {
        DispatchQueue.main.async {
            self.selectedDate = Date()
            self.loadNotifications()
        }
    }
}