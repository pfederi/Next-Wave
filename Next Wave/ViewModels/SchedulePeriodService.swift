import Foundation

class SchedulePeriodService: ObservableObject {
    @Published var scheduleData: SchedulePeriodsData?
    
    private let logger = iOSLogger.shared
    
    init() {
        loadScheduleData()
    }
    
    private func loadScheduleData() {
        guard let url = Bundle.main.url(forResource: "schedule_periods", withExtension: "json") else {
            logger.error("Failed to find schedule_periods.json in bundle")
            return
        }
        
        guard let data = try? Data(contentsOf: url) else {
            logger.error("Failed to load data from schedule_periods.json")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            self.scheduleData = try decoder.decode(SchedulePeriodsData.self, from: data)
            logger.debug("Successfully loaded schedule periods data with \(scheduleData?.lakes.count ?? 0) lakes")
        } catch {
            logger.error("Failed to decode schedule periods: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Get the current schedule period for a given lake
    func getCurrentSchedulePeriod(for lakeName: String) -> SchedulePeriod? {
        guard let lake = scheduleData?.lakes.first(where: { $0.name == lakeName }) else {
            return nil
        }
        
        let now = Date()
        return lake.schedulePeriods.first { period in
            period.isCurrentPeriod(for: now)
        }
    }
    
    /// Get the next schedule period for a given lake
    func getNextSchedulePeriod(for lakeName: String) -> SchedulePeriod? {
        guard let lake = scheduleData?.lakes.first(where: { $0.name == lakeName }) else {
            return nil
        }
        
        let now = Date()
        
        // Find the next period that starts after today
        let futurePeriods = lake.schedulePeriods.compactMap { period -> (SchedulePeriod, Date)? in
            guard let startDate = period.startDateObj, startDate > now else { return nil }
            return (period, startDate)
        }
        
        // Sort by start date and return the earliest
        return futurePeriods.sorted { $0.1 < $1.1 }.first?.0
    }
    
    /// Get days until the next schedule change for a given lake (max 30 days)
    func getDaysUntilNextScheduleChange(for lakeName: String) -> (days: Int, nextPeriod: SchedulePeriod)? {
        guard let nextPeriod = getNextSchedulePeriod(for: lakeName),
              let days = nextPeriod.daysUntilStart() else {
            return nil
        }
        
        // Only show if within 30 days
        guard days <= 31 else {
            return nil
        }
        
        return (days: days, nextPeriod: nextPeriod)
    }
    
    /// Get a formatted message for the schedule countdown
    func getScheduleCountdownMessage(for lakeName: String) -> String? {
        guard let (days, nextPeriod) = getDaysUntilNextScheduleChange(for: lakeName) else {
            return nil
        }
        
        return getWittyMessage(days: days, scheduleType: nextPeriod.type)
    }
    
    /// Get witty messages based on schedule transitions
    private func getWittyMessage(days: Int, scheduleType: ScheduleType) -> String {
        let timeText: String
        if days == 0 {
            timeText = "Today"
        } else if days == 1 {
            timeText = "Tomorrow"
        } else {
            timeText = "\(days) days"
        }
        
        switch scheduleType {
        case .summer:
            if days == 0 || days == 1 {
                let messages = [
                    "\(timeText): More boats, more waves! \(scheduleType.emoji)",
                    "\(timeText): Summer boat festival begins! \(scheduleType.emoji)",
                    "\(timeText): Maximum boat chaos incoming! \(scheduleType.emoji)",
                    "\(timeText): All aboard the summer madness! \(scheduleType.emoji)"
                ]
                return messages.randomElement() ?? "\(timeText): Summer schedule begins! \(scheduleType.emoji)"
            } else {
                let messages = [
                    "\(timeText) until more boats, more waves! \(scheduleType.emoji)",
                    "\(timeText) until summer boat festival! \(scheduleType.emoji)",
                    "\(timeText) until wave-hopping paradise! \(scheduleType.emoji)",
                    "\(timeText) until maximum boat chaos! \(scheduleType.emoji)"
                ]
                return messages.randomElement() ?? "\(timeText) until summer schedule! \(scheduleType.emoji)"
            }
            
        case .winter:
            if days == 0 || days == 1 {
                let messages = [
                    "\(timeText): Boats entering hibernation \(scheduleType.emoji)",
                    "\(timeText): Winter chill mode activated \(scheduleType.emoji)", 
                    "\(timeText): Quality over quantity season \(scheduleType.emoji)",
                    "\(timeText): Boats need their winter sleep \(scheduleType.emoji)"
                ]
                return messages.randomElement() ?? "\(timeText): Winter schedule begins! \(scheduleType.emoji)"
            } else {
                let messages = [
                    "\(timeText) until boats hibernate \(scheduleType.emoji)",
                    "\(timeText) until winter chill mode \(scheduleType.emoji)",
                    "\(timeText) until fewer boats, more peace \(scheduleType.emoji)",
                    "\(timeText) until quality over quantity \(scheduleType.emoji)"
                ]
                return messages.randomElement() ?? "\(timeText) until winter schedule! \(scheduleType.emoji)"
            }
            
        case .autumn:
            if days == 0 || days == 1 {
                let messages = [
                    "\(timeText): Boats getting sleepy \(scheduleType.emoji)",
                    "\(timeText): Farewell summer crowds! \(scheduleType.emoji)",
                    "\(timeText): Cozy boat season begins \(scheduleType.emoji)",
                    "\(timeText): Golden hour boat rides \(scheduleType.emoji)"
                ]
                return messages.randomElement() ?? "\(timeText): Autumn schedule begins! \(scheduleType.emoji)"
            } else {
                let messages = [
                    "\(timeText) until boats get sleepy \(scheduleType.emoji)",
                    "\(timeText) until farewell summer crowds \(scheduleType.emoji)",
                    "\(timeText) until cozy boat season \(scheduleType.emoji)",
                    "\(timeText) until golden hour rides \(scheduleType.emoji)"
                ]
                return messages.randomElement() ?? "\(timeText) until autumn schedule! \(scheduleType.emoji)"
            }
            
        case .spring:
            if days == 0 || days == 1 {
                let messages = [
                    "\(timeText): Boats wake up from winter naps! \(scheduleType.emoji)",
                    "\(timeText): More waves returning! \(scheduleType.emoji)",
                    "\(timeText): Spring awakening on the lake \(scheduleType.emoji)",
                    "\(timeText): Boats bloom like flowers \(scheduleType.emoji)"
                ]
                return messages.randomElement() ?? "\(timeText): Spring schedule begins! \(scheduleType.emoji)"
            } else {
                let messages = [
                    "\(timeText) until boats wake up! \(scheduleType.emoji)",
                    "\(timeText) until more waves return \(scheduleType.emoji)",
                    "\(timeText) until spring awakening \(scheduleType.emoji)",
                    "\(timeText) until boats bloom again \(scheduleType.emoji)"
                ]
                return messages.randomElement() ?? "\(timeText) until spring schedule! \(scheduleType.emoji)"
            }
        }
    }
    
    /// Get the lake name for a given station
    func getLakeForStation(_ stationName: String) -> String? {
        // This could be improved by matching station names to lakes
        // For now, use simple string matching
        if stationName.contains("Zürich") || stationName.contains("Bürkliplatz") || 
           stationName.contains("Thalwil") || stationName.contains("Rapperswil") {
            return "Zürichsee"
        } else if stationName.contains("Luzern") || stationName.contains("Vitznau") || 
                  stationName.contains("Weggis") || stationName.contains("Brunnen") {
            return "Vierwaldstättersee"
        } else if stationName.contains("Konstanz") || stationName.contains("Romanshorn") || 
                  stationName.contains("Friedrichshafen") {
            return "Bodensee"
        }
        
        // Default fallback - could be improved with a proper mapping
        return "Zürichsee"
    }
}

// MARK: - Extension for easier access
extension SchedulePeriodService {
    /// Get countdown message for a station
    func getCountdownMessageForStation(_ stationName: String) -> String? {
        guard let lakeName = getLakeForStation(stationName) else { return nil }
        return getScheduleCountdownMessage(for: lakeName)
    }
}
