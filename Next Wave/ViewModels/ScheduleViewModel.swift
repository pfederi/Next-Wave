import Foundation
import UserNotifications

class ScheduleViewModel: ObservableObject {
    @Published var schedule: Schedule?
    @Published var errorMessage: String?
    @Published var selectedStop: String?
    @Published var nextWaves: [WaveEvent] = []
    @Published var shouldShowSwipeHint = false
    @Published var hasShownSwipeHint = false
    @Published var noWavesMessage: String? = nil
    
    private let userDefaults = UserDefaults.standard
    private let notificationsKey = "scheduledNotifications"
    private var timer: Timer?
    
    var availableStops: [String] {
        var stops = Set<String>()
        
        guard let url = Bundle.main.url(forResource: "schedule", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let jsonArray = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return []
        }
        
        for entry in jsonArray.first ?? [:] {
            let key = entry.key
            if key.hasSuffix("__Abfahrten") {
                let stopName = key.replacingOccurrences(of: "__Abfahrten", with: "")
                stops.insert(stopName)
            }
        }
        
        return Array(stops).sorted()
    }
    
    @Published var currentPeriod: String?
    
    init() {
        userDefaults.removeObject(forKey: notificationsKey)
        
        loadSchedule()
        updateNextWaves()
        loadNotifications()
        
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func appWillEnterForeground() {
        updateNextWaves()
    }
    
    func loadSchedule() {
        guard let url = Bundle.main.url(forResource: "schedule", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let jsonArray = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return
        }
        
        schedule = convertToSchedule(from: jsonArray)
    }
    
    private func convertToSchedule(from jsonArray: [[String: String]]) -> Schedule {
        var periodDict: [String: PeriodSchedule] = [:]
        let groupedByDate = Dictionary(grouping: jsonArray) { $0["dates"] ?? "" }
        
        for (dateRange, entries) in groupedByDate {
            var routeDict: [String: RouteSchedule] = [:]
            let groupedByRoute = Dictionary(grouping: entries) { $0["routes"] ?? "" }
            
            for (routeName, routeEntries) in groupedByRoute {
                var stopDict: [String: StopSchedule] = [:]
                
                for entry in routeEntries {
                    for stopName in availableStops {
                        let departureKey = "\(stopName)__Abfahrten"
                        let arrivalKey = "\(stopName)__Ankünfte"
                        
                        if let departureTime = entry[departureKey], !departureTime.isEmpty {
                            if stopDict[stopName] == nil {
                                stopDict[stopName] = StopSchedule(departures: [], arrivals: [])
                            }
                            stopDict[stopName]?.departures.append(departureTime)
                        }
                        
                        if let arrivalTime = entry[arrivalKey], !arrivalTime.isEmpty {
                            if stopDict[stopName] == nil {
                                stopDict[stopName] = StopSchedule(departures: [], arrivals: [])
                            }
                            stopDict[stopName]?.arrivals.append(arrivalTime)
                        }
                    }
                }
                
                for (stopName, schedule) in stopDict {
                    stopDict[stopName] = StopSchedule(
                        departures: Array(Set(schedule.departures)).sorted(),
                        arrivals: Array(Set(schedule.arrivals)).sorted()
                    )
                }
                
                let routeInfo = RouteInfo(
                    routeNumber: routeEntries.first?["routeNumber"] ?? "",
                    baseTime: routeEntries.first?["baseTime"] ?? "",
                    frequency: routeEntries.first?["frequency"] ?? ""
                )
                
                routeDict[routeName] = RouteSchedule(stops: stopDict, routeInfo: routeInfo)
            }
            
            periodDict[dateRange] = PeriodSchedule(routes: routeDict)
        }
        
        return Schedule(periods: periodDict)
    }
    
    func updateNextWaves() {
        guard let selectedStop = selectedStop,
              let currentPeriod = getCurrentPeriod() else {
            nextWaves = []
            return
        }
        
        let savedNotifications = userDefaults.stringArray(forKey: notificationsKey) ?? []
        var events: [WaveEvent] = []
        
        if let periodSchedule = schedule?.periods[currentPeriod] {
            for (routeName, route) in periodSchedule.routes {
                if let stopSchedule = route.stops[selectedStop] {
                    let allStops = Array(route.stops.keys)
                    guard let currentStopIndex = allStops.firstIndex(of: selectedStop) else { continue }
                    
                    for departureTimeStr in stopSchedule.departures {
                        if let departureTime = parseTime(departureTimeStr) {
                            let nextStopIndex = currentStopIndex + 1
                            let nextStop = nextStopIndex < allStops.count ? allStops[nextStopIndex] : allStops.last ?? selectedStop
                            
                            let event = WaveEvent(
                                time: departureTime,
                                isArrival: false,
                                routeNumber: route.routeInfo.routeNumber,
                                routeName: "\(routeName) (\(route.routeInfo.routeNumber))",
                                neighborStop: "nach \(nextStop)",
                                period: currentPeriod
                            )
                            events.append(event)
                        }
                    }
                    
                    for arrivalTimeStr in stopSchedule.arrivals {
                        if let arrivalTime = parseTime(arrivalTimeStr) {
                            let prevStopIndex = currentStopIndex - 1
                            let prevStop = prevStopIndex >= 0 ? allStops[prevStopIndex] : allStops.first ?? selectedStop
                            
                            let event = WaveEvent(
                                time: arrivalTime,
                                isArrival: true,
                                routeNumber: route.routeInfo.routeNumber,
                                routeName: "\(routeName) (\(route.routeInfo.routeNumber))",
                                neighborStop: "von \(prevStop)",
                                period: currentPeriod
                            )
                            events.append(event)
                        }
                    }
                }
            }
        }
        
        events.sort { $0.time < $1.time }
        
        for i in 0..<events.count {
            if savedNotifications.contains(events[i].id) {
                events[i].hasNotification = true
                scheduleSystemNotification(for: events[i])
            }
        }
        
        nextWaves = events
    }
    
    private func scheduleSystemNotification(for wave: WaveEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Wave is coming"
        
        let location = wave.neighborStop.replacingOccurrences(of: "nach ", with: "")
                                  .replacingOccurrences(of: "von ", with: "")
        let cleanedRouteName = wave.routeName.replacingOccurrences(
            of: "\\((0+)",
            with: "(",
            options: .regularExpression
        ).replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        
        let directionText = wave.isArrival ? "from" : "to"
        content.body = "\(cleanedRouteName) \(directionText) \(location) at \(wave.timeString)"
        
        if let soundURL = Bundle.main.url(forResource: "boat-horn", withExtension: "wav") {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundURL.lastPathComponent))
        } else {
            content.sound = .default
        }
        
        let triggerDate = Calendar.current.date(byAdding: .minute, value: -5, to: wave.time)!
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: wave.id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    public func isDateInRange(_ dateRange: String) -> Bool {
        let currentDate = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentDate)
        let ranges = dateRange.components(separatedBy: " UND ")
        
        for year in currentYear...(currentYear + 1) {
            for range in ranges {
                let dates = range.components(separatedBy: "–").map { $0.trimmingCharacters(in: .whitespaces) }
                if dates.count == 2 {
                    let startDateStr = dates[0]
                    let endDateStr = dates[1]
                    
                    let startYear = startDateStr.contains(".20") ? nil : String(year)
                    let endYear = endDateStr.contains(".20") ? nil : String(year)
                    
                    if let start = parseDate(startDateStr, defaultYear: startYear),
                       let end = parseDate(endDateStr, defaultYear: endYear),
                       currentDate >= start && currentDate <= end {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    func getCurrentPeriod() -> String? {
        let currentDate = Date()
        let calendar = Calendar.current
        
        for (dateRange, _) in schedule?.periods ?? [:] {
            let ranges = dateRange.split(separator: "UND").map { $0.trimmingCharacters(in: .whitespaces) }
            
            for range in ranges {
                let dates = range.split(separator: "–").map { $0.trimmingCharacters(in: .whitespaces) }
                if dates.count == 2,
                   let startDate = parseDate(dates[0]),
                   let endDate = parseDate(dates[1]) {
                    
                    let startOfDay = calendar.startOfDay(for: currentDate)
                    let startOfStartDate = calendar.startOfDay(for: startDate)
                    let startOfEndDate = calendar.startOfDay(for: endDate)
                    
                    if startOfDay >= startOfStartDate && startOfDay <= startOfEndDate {
                        return dateRange
                    }
                }
            }
        }
        
        return schedule?.periods.keys.first
    }
    
    private func parseDate(_ dateString: String, defaultYear: String? = nil) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        
        if dateString.contains(".20") {
            formatter.dateFormat = "d.M.yyyy"
            return formatter.date(from: dateString)
        }
        
        if let year = defaultYear {
            formatter.dateFormat = "d.M.yyyy"
            return formatter.date(from: dateString + "." + year)
        }
        
        return nil
    }
    
    func scheduleNotification(for wave: WaveEvent) {
        scheduleSystemNotification(for: wave)
        
        if let index = nextWaves.firstIndex(where: { $0.id == wave.id }) {
            nextWaves[index].hasNotification = true
            saveNotification(wave.id)
        }
    }
    
    func removeNotification(for wave: WaveEvent) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [wave.id])
        
        if let index = nextWaves.firstIndex(where: { $0.id == wave.id }) {
            nextWaves[index].hasNotification = false
            removeNotification(wave.id)
        }
    }
    
    private func saveNotification(_ id: String) {
        var notifications = userDefaults.stringArray(forKey: notificationsKey) ?? []
        notifications.append(id)
        userDefaults.set(notifications, forKey: notificationsKey)
    }
    
    private func removeNotification(_ id: String) {
        var notifications = userDefaults.stringArray(forKey: notificationsKey) ?? []
        notifications.removeAll { $0 == id }
        userDefaults.set(notifications, forKey: notificationsKey)
    }
    
    private func loadNotifications() {
        let notifications = userDefaults.stringArray(forKey: notificationsKey) ?? []
        
        for notificationId in notifications {
            if let wave = nextWaves.first(where: { $0.id == notificationId }) {
                if wave.remainingTimeString == "missed" {
                    removeNotification(for: wave)
                    continue
                }
                
                scheduleSystemNotification(for: wave)
                if let index = nextWaves.firstIndex(where: { $0.id == wave.id }) {
                    nextWaves[index].hasNotification = true
                }
            }
        }
    }
    
    private func parseTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        formatter.locale = Locale(identifier: "de_CH")
        
        if let date = formatter.date(from: timeString) {
            let calendar = Calendar.current
            let now = Date()
            
            let components = calendar.dateComponents([.hour, .minute], from: date)
            
            return calendar.date(bySettingHour: components.hour ?? 0,
                               minute: components.minute ?? 0,
                               second: 0,
                               of: now)
        }
        return nil
    }
    
    func calculateRemainingTime(for date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute], from: now, to: date)
        let minutes = components.minute ?? 0
        
        if minutes >= -5 && minutes <= 5 {
            return "now"
        }
        
        if minutes < -5 {
            return "missed"
        }
        
        return "\(minutes) min"
    }
    
    func getDepartures(for station: Lake.Station, on date: Date) async -> [Journey]? {
        guard let uicRef = station.uic_ref else { return nil }
        
        do {
            let transportAPI = TransportAPI()
            let journeys = try await transportAPI.getStationboard(stationId: uicRef)
            
            // Filter journeys for the selected date
            let calendar = Calendar.current
            return journeys.filter { journey in
                guard let departureTimeStr = journey.stop.departure,
                      let departureDate = parseFullTime(departureTimeStr) else {
                    return false
                }
                
                return calendar.isDate(departureDate, inSameDayAs: date)
            }
        } catch {
            print("Error fetching departures: \(error)")
            return nil
        }
    }
    
    private func parseFullTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        return formatter.date(from: timeString)
    }
}