import Foundation
import UserNotifications
import SwiftUI
import BackgroundTasks
import CoreLocation

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
            DispatchQueue.main.async {
                self.saveSettings()
            }
        }
    }
    
    @ObservedObject var appSettings: AppSettings
    
    var selectedStation: Lake.Station?
    
    struct Settings: Codable {
        var leadTime: Int
        var selectedSound: String
        
        static let `default` = Settings(
            leadTime: 15,
            selectedSound: "boat-horn"
        )
    }
    
    var availableSounds: [String: String] = [
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
    @Published var albisClassFilterActive = false
    @Published var sunTimes: SunTimes?
    
    private let userDefaults = UserDefaults.standard
    private let notifiedJourneysKey = "com.nextwave.notifiedJourneys"
    private let settingsKey = "NotificationSettings"
    
    private var midnightTimer: Timer?
    private var currentLoadingTask: Task<Void, Never>?
    
    private var shipNamesCache: [String: String] = [:] // Cache für Schiffsnamen (Key: "YYYY-MM-DD_routeNumber")
    
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
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
        currentLoadingTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }
    
    func updateLeadTime(_ newValue: Int) {
        DispatchQueue.main.async {
            self.settings = Settings(leadTime: newValue, selectedSound: self.settings.selectedSound)
        }
    }
    
    func updateSound(_ newValue: String) {
        DispatchQueue.main.async {
            self.settings = Settings(leadTime: self.settings.leadTime, selectedSound: newValue)
        }
    }
    
    // Albis-Klasse Schiffe: MS Albis, EMS Uetliberg, EMS Pfannenstiel
    private let albisClassShips = ["MS Albis", "EMS Uetliberg", "EMS Pfannenstiel"]
    
    func toggleAlbisClassFilter() {
        albisClassFilterActive.toggle()
        
        // Different haptic feedback for activate vs deactivate
        if albisClassFilterActive {
            // Aktiviert: Stärkeres Feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            // Deaktiviert: Leichteres Feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    func getFilteredWaves() -> [WaveEvent] {
        guard albisClassFilterActive else {
            return nextWaves
        }
        
        // Nur Wellen von Albis-Klasse Schiffen zeigen
        return nextWaves.filter { wave in
            guard let shipName = wave.shipName else { return false }
            return albisClassShips.contains(shipName)
        }
    }
    
    func updateWaves(from departures: [Journey], station: Lake.Station) {
        // Set the selected station
        self.selectedStation = station
        
        // Cancel any existing loading task to prevent race conditions
        currentLoadingTask?.cancel()
        currentLoadingTask = nil
        
        // Leere die Liste sofort, damit die ScrollView resettet wird
        nextWaves = []
        
        // Starte Task für das Erstellen der Wellen
        currentLoadingTask = Task { @MainActor in
            // Erstelle Wellen OHNE sie sofort anzuzeigen
            let waves = await departures.asyncMap { journey -> WaveEvent in
            let routeNumber = (journey.name ?? "Unknown")
                .replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
            
            let departureTime = AppDateFormatter.parseFullTime(journey.stop.departure ?? "") ?? Date()
            let nextStation = journey.passList?.dropFirst().first?.station
            
            // Nur ZSG Stationen (85036 prefix)
            let isZurichsee = journey.stop.station.id.hasPrefix("85036")
            
            // Versuche Schiffsnamen synchron aus dem Cache zu holen
            var shipName: String? = nil
            if isZurichsee {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: selectedDate)
                let cacheKey = "\(dateString)_\(routeNumber)"
                
                // Prüfe zuerst den lokalen Cache
                if let cachedName = shipNamesCache[cacheKey] {
                    shipName = cachedName
                } else {
                    // Prüfe dann den VesselAPI Cache (synchron!)
                    shipName = await VesselAPI.shared.getCachedShipName(for: routeNumber, date: selectedDate)
                    if let name = shipName {
                        shipNamesCache[cacheKey] = name
                    }
                }
            }
            
            return WaveEvent(
                time: departureTime,
                isArrival: journey.stop.arrival != nil,
                routeNumber: routeNumber,
                routeName: journey.stop.station.name ?? "Unknown",
                neighborStop: journey.to ?? journey.stop.station.id,
                neighborStopName: nextStation?.name ?? "Unknown",
                period: "regular",
                lake: isZurichsee ? "Zürichsee" : "Unknown",
                shipName: shipName,
                hasNotification: false
            )
            }
            
            // ✅ SOFORT anzeigen - User sieht Abfahrten ohne Wartezeit
            hasAttemptedLoad = true
            nextWaves = waves
            print("✅ [ScheduleViewModel] Showing \(waves.count) departures immediately (without weather)")
            
            // Keine Koordinaten? Dann sind wir fertig
            guard let coordinates = station.coordinates else { 
                print("ℹ️ [ScheduleViewModel] No coordinates - skipping weather/ship names")
                return 
            }
            
            let location = CLLocationCoordinate2D(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude
            )
            
            // Erstelle eine Kopie der Wellen für die Hintergrund-Verarbeitung
            var updatedWaves = waves
            
            // 1. Lade Sun Times im Hintergrund (blockiert nicht)
            Task {
                do {
                    let times = try await SunTimeService.shared.getSunTimes(date: selectedDate)
                    if !Task.isCancelled {
                        sunTimes = times
                    }
                } catch {
                    // Fehler beim Laden der Sun Times - ignorieren
                    #if DEBUG
                    print("Failed to load sun times: \(error)")
                    #endif
                }
            }
            
            // 2. Lade fehlende Schiffsnamen im Hintergrund (sollten meist gecached sein)
            let shipNames = await updatedWaves.asyncMap { wave -> String? in
                guard !Task.isCancelled else { return nil }
                guard wave.isZurichsee else { return nil }
                
                // Wenn bereits vorhanden, überspringe
                if wave.shipName != nil {
                    return wave.shipName
                }
                
                // Cache-Key mit Datum und Kursnummer erstellen
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: selectedDate)
                let cacheKey = "\(dateString)_\(wave.routeNumber)"
                
                // Prüfe zuerst den Cache
                if let cachedName = shipNamesCache[cacheKey] {
                    return cachedName
                }
                
                // Wenn nicht im Cache, lade von der API (sollte selten vorkommen)
                let shipName = await VesselAPI.shared.findShipName(
                    for: wave.routeNumber,
                    date: selectedDate
                )
                
                // Speichere im Cache mit Datum
                if let shipName = shipName {
                    shipNamesCache[cacheKey] = shipName
                }
                
                return shipName
            }
            
            // Aktualisiere Wellen mit Schiffsnamen
            var hasShipNameUpdates = false
            for i in updatedWaves.indices {
                if updatedWaves[i].shipName == nil {
                    if let shipName = shipNames[i] {
                        updatedWaves[i].updateShipName(shipName)
                        hasShipNameUpdates = true
                    } else if updatedWaves[i].isZurichsee {
                        // Wenn kein Schiffsname gefunden wurde, setze "Unknown"
                        updatedWaves[i].updateShipName("Unknown")
                        hasShipNameUpdates = true
                    }
                }
            }
            
            // Update UI mit Schiffsnamen (falls welche geladen wurden)
            if hasShipNameUpdates && !Task.isCancelled {
                nextWaves = updatedWaves
                print("✅ [ScheduleViewModel] Updated UI with ship names")
            }
            
            // 3. Lade Wetterdaten im Hintergrund (nur wenn aktiviert)
            guard appSettings.showWeatherInfo else {
                print("ℹ️ [ScheduleViewModel] Weather info disabled - skipping")
                return
            }
            
            print("🌤️ [ScheduleViewModel] Loading weather data in background...")
            let weatherData = await updatedWaves.asyncMap { wave -> WeatherAPI.WeatherInfo? in
                guard !Task.isCancelled else { return nil }
                // Nur für zukünftige Wellen Wetter laden
                guard wave.time > Date() else { return nil }
                do {
                    let weather = try await WeatherAPI.shared.getWeatherForTime(
                        location: location,
                        time: wave.time
                    )
                    return weather
                } catch {
                    return nil
                }
            }
            
            // Aktualisiere Wellen mit Wetterdaten
            var hasWeatherUpdates = false
            for i in updatedWaves.indices {
                if let weather = weatherData[i] {
                    updatedWaves[i].updateWeather(weather)
                    hasWeatherUpdates = true
                }
            }
            
            // Update UI mit Wetterdaten (falls welche geladen wurden)
            if hasWeatherUpdates && !Task.isCancelled {
                nextWaves = updatedWaves
                print("✅ [ScheduleViewModel] Updated UI with weather data")
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
        
        content.title = "NextWave"
        content.body = notificationMessages.randomElement() ?? "Get ready to surf!"
        content.sound = getNotificationSound()
        
        let triggerDate = Calendar.current.date(byAdding: .minute, value: -settings.leadTime, to: wave.time)!
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: wave.id,
                                          content: content,
                                          trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { [weak self] _ in
            DispatchQueue.main.async {
                self?.notifiedJourneys.insert(wave.id)
                self?.saveNotifications()
                self?.objectWillChange.send()
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
    
    func cancelCurrentTask() {
        currentLoadingTask?.cancel()
        currentLoadingTask = nil
    }
    
    func preloadShipNames(for departures: [Journey]) {
        // Capture what we need from self at the start
        let selectedDate = self.selectedDate
        
        Task { @MainActor in
            // Date formatter für Cache-Key
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: selectedDate)
            
            for journey in departures {
                let routeNumber = (journey.name ?? "Unknown")
                    .replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
                
                // Cache-Key mit Datum erstellen
                let cacheKey = "\(dateString)_\(routeNumber)"
                
                // Check if name is already in cache
                if self.shipNamesCache[cacheKey] == nil {
                    if let shipName = await VesselAPI.shared.findShipName(for: routeNumber, date: selectedDate) {
                        // Update cache directly on main actor
                        self.shipNamesCache[cacheKey] = shipName
                    }
                }
            }
        }
    }

    func getShipName(for routeNumber: String) -> String? {
        // Erstelle Cache-Key mit aktuellem Datum
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: selectedDate)
        let cacheKey = "\(dateString)_\(routeNumber)"
        
        return shipNamesCache[cacheKey]
    }
    
    // Clear ship names cache
    func clearShipNamesCache() {
        shipNamesCache.removeAll()
        print("🗑️ Ship names cache cleared")
    }
}

