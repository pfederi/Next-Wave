import Foundation
import UserNotifications
import SwiftUI

class ScheduleViewModel: ObservableObject {
    @AppStorage("notificationLeadTime") private var leadTime: Int = 5
    @AppStorage("hidePastWaves") var hidePastWaves: Bool = false
    @AppStorage("notificationSound") var selectedSound: String = "boat-horn"
    
    let availableSounds = [
        "boat-horn": "Boat Horn",
        "happy": "Happy Tune",
        "let-the-fun-begin": "Fun Time",
        "short-beep": "Short Beep",
        "ukulele": "Ukulele",
        "system": "System Sound"
    ]
    
    @Published var notifiedJourneys: Set<String> = []
    @Published var selectedDate: Date = Date()
    @Published var hasAttemptedLoad: Bool = false
    @Published var nextWaves: [WaveEvent] = []
    
    private let userDefaults = UserDefaults.standard
    private let notifiedJourneysKey = "com.nextwave.notifiedJourneys"
    
    init() {
        loadNotifications()
    }
    
    func updateWaves(from departures: [Journey]) {
        let waves = departures.map { journey in
            WaveEvent(
                time: AppDateFormatter.parseFullTime(journey.stop.departure ?? "") ?? Date(),
                isArrival: false,
                routeNumber: journey.name ?? "Unknown",
                routeName: journey.stop.station.name ?? "Unknown",
                neighborStop: journey.to ?? journey.stop.station.id,
                neighborStopName: journey.passList?.dropFirst().first?.station.name ?? "Unknown",
                period: "regular"
            )
        }
        
        nextWaves = hidePastWaves ? waves.filter { !($0.time < Date()) } : waves
        hasAttemptedLoad = true
    }
    
    private func loadNotifications() {
        if let savedNotifications = userDefaults.stringArray(forKey: notifiedJourneysKey) {
            notifiedJourneys = Set(savedNotifications)
        }
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                let systemNotificationIds = Set(requests.map { $0.identifier })
                self.notifiedJourneys = systemNotificationIds
                self.saveNotifications()
            }
        }
    }
    
    func hasNotification(for wave: WaveEvent) -> Bool {
        return notifiedJourneys.contains(wave.id)
    }
    
    func scheduleNotification(for wave: WaveEvent) {
        if wave.time < Date() { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Wave is coming!"
        
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
        content.body = notificationMessages.randomElement() ?? "Get ready to surf!"
        content.sound = getNotificationSound()
        
        let triggerDate = Calendar.current.date(byAdding: .minute, value: -leadTime, to: wave.time)!
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
        if selectedSound == "system" {
            return .default
        }
        
        if let soundURL = Bundle.main.url(forResource: selectedSound, withExtension: "wav") {
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: soundURL.lastPathComponent))
        }
        
        return .default
    }
    
}