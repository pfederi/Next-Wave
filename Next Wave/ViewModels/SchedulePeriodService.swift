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
    
    /// Get days until the next schedule change for a given lake (max 31 days)
    func getDaysUntilNextScheduleChange(for lakeName: String) -> (days: Int, nextPeriod: SchedulePeriod)? {
        guard scheduleData?.lakes.first(where: { $0.name == lakeName }) != nil else {
            return nil
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // First check if current period is ending soon
        if let currentPeriod = getCurrentSchedulePeriod(for: lakeName),
           let endDate = currentPeriod.endDateObj {
            let daysUntilEnd = calendar.dateComponents([.day], from: now, to: endDate).day ?? 0
            if daysUntilEnd <= 30 && daysUntilEnd >= 0 {
                // Find what comes after current period
                if let nextPeriod = getNextSchedulePeriod(for: lakeName) {
                    logger.debug("Current period (\(currentPeriod.name)) ends in \(daysUntilEnd) days, next: \(nextPeriod.name)")
                    return (days: daysUntilEnd, nextPeriod: nextPeriod)
                }
            }
        }
        
        // Otherwise check next period start
        guard let nextPeriod = getNextSchedulePeriod(for: lakeName),
              let days = nextPeriod.daysUntilStart() else {
            return nil
        }
        
        logger.debug("Days until next period (\(nextPeriod.name)): \(days)")
        
        // Only show if within 31 days and in the future
        guard days <= 31 && days >= 0 else {
            return nil
        }
        
        return (days: days, nextPeriod: nextPeriod)
    }
    
    /// Get a formatted message for the schedule countdown
    func getScheduleCountdownMessage(for lakeName: String) -> String? {
        logger.debug("Getting schedule countdown for lake: \(lakeName)")
        
        guard let lake = scheduleData?.lakes.first(where: { $0.name == lakeName }) else {
            logger.debug("Lake \(lakeName) not found in schedule data")
            return nil
        }
        
        logger.debug("Found lake \(lakeName) with \(lake.schedulePeriods.count) periods")
        
        guard let (days, nextPeriod) = getDaysUntilNextScheduleChange(for: lakeName) else {
            logger.debug("No upcoming schedule change found for \(lakeName)")
            return nil
        }
        
        logger.debug("Found schedule change in \(days) days: \(nextPeriod.name)")
        
        // Check if we're showing end of current period or start of next
        let isCurrentPeriodEnding = getCurrentSchedulePeriod(for: lakeName) != nil
        
        return getWittyMessage(days: days, scheduleType: nextPeriod.type, isEnding: isCurrentPeriodEnding)
    }
    
    /// Get witty messages based on schedule transitions
    private func getWittyMessage(days: Int, scheduleType: ScheduleType, isEnding: Bool = false) -> String {
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
        // Match station names to lakes using comprehensive string matching
        
        // Zürichsee
        if stationName.contains("Zürich") || stationName.contains("Bürkliplatz") || 
           stationName.contains("Thalwil") || stationName.contains("Rapperswil") ||
           stationName.contains("Wollishofen") || stationName.contains("Kilchberg") ||
           stationName.contains("Rüschlikon") || stationName.contains("Horgen") ||
           stationName.contains("Wädenswil") || stationName.contains("Richterswil") ||
           stationName.contains("Pfäffikon SZ") || stationName.contains("Stäfa") ||
           stationName.contains("Männedorf") || stationName.contains("Meilen") ||
           stationName.contains("Herrliberg") || stationName.contains("Erlenbach") ||
           stationName.contains("Küsnacht") || stationName.contains("Zollikon") ||
           stationName.contains("Tiefenbrunnen") || stationName.contains("Zürichhorn") {
            return "Zürichsee"
        }
        
        // Vierwaldstättersee
        else if stationName.contains("Luzern") || stationName.contains("Vitznau") || 
                stationName.contains("Weggis") || stationName.contains("Brunnen") ||
                stationName.contains("Verkehrshaus") || stationName.contains("Bürgenstock") ||
                stationName.contains("Hertenstein") || stationName.contains("Ennetbürgen") ||
                stationName.contains("Buochs") || stationName.contains("Beckenried") ||
                stationName.contains("Gersau") || stationName.contains("Treib") ||
                stationName.contains("Rütli") || stationName.contains("Sisikon") ||
                stationName.contains("Tellsplatte") || stationName.contains("Bauen") ||
                stationName.contains("Isleten") || stationName.contains("Flüelen") ||
                stationName.contains("Kastanienbaum") || stationName.contains("Hergiswil") ||
                stationName.contains("Stansstad") || stationName.contains("Alpnachstad") ||
                stationName.contains("Meggenhorn") || stationName.contains("Hermitage") ||
                stationName.contains("Tribschen") || stationName.contains("Merlischachen") ||
                stationName.contains("Greppen") || stationName.contains("Küssnacht am Rigi") ||
                stationName.contains("Seedorf UR") {
            return "Vierwaldstättersee"
        }
        
        // Bodensee
        else if stationName.contains("Konstanz") || stationName.contains("Romanshorn") || 
                stationName.contains("Friedrichshafen") || stationName.contains("Lindau") ||
                stationName.contains("Altenrhein") || stationName.contains("Staad") ||
                stationName.contains("Rorschach") || stationName.contains("Horn") ||
                stationName.contains("Arbon") || stationName.contains("Uttwil") ||
                stationName.contains("Güttingen") || stationName.contains("Altnau") ||
                stationName.contains("Bottighofen") || stationName.contains("Kreuzlingen") ||
                stationName.contains("Gottlieben") || stationName.contains("Ermatingen") ||
                stationName.contains("Mannenbach") || stationName.contains("Berlingen") ||
                stationName.contains("Steckborn") || stationName.contains("Mammern") ||
                stationName.contains("Oehningen") || stationName.contains("Stein am Rhein") ||
                stationName.contains("Wangen (Bodensee)") || stationName.contains("Hemmenhofen") ||
                stationName.contains("Gaienhofen") {
            return "Bodensee"
        }
        
        // Lac Léman
        else if stationName.contains("Genève") || stationName.contains("Geneva") ||
                stationName.contains("Lausanne") || stationName.contains("Montreux") ||
                stationName.contains("Vevey") || stationName.contains("Evian") ||
                stationName.contains("Thonon") || stationName.contains("Nyon") ||
                stationName.contains("Morges") || stationName.contains("Ouchy") ||
                stationName.contains("Pully") || stationName.contains("Lutry") ||
                stationName.contains("Cully") || stationName.contains("Rivaz") ||
                stationName.contains("Clarens") || stationName.contains("Territet") ||
                stationName.contains("Chillon") || stationName.contains("Villeneuve") ||
                stationName.contains("Bouveret") || stationName.contains("Saint-Gingolph") ||
                stationName.contains("Rolle") || stationName.contains("Saint-Prex") ||
                stationName.contains("Versoix") || stationName.contains("Céligny") ||
                stationName.contains("Bellevue GE") || stationName.contains("Hermance") ||
                stationName.contains("Anières") || stationName.contains("Corsier") {
            return "Lac Léman"
        }
        
        // Thunersee
        else if stationName.contains("Thun") || stationName.contains("Spiez") ||
                stationName.contains("Interlaken") || stationName.contains("Hilterfingen") ||
                stationName.contains("Oberhofen") || stationName.contains("Gunten") ||
                stationName.contains("Gwatt") || stationName.contains("Einigen") ||
                stationName.contains("Hünibach") || stationName.contains("Faulensee") ||
                stationName.contains("Merligen") || stationName.contains("Beatenbucht") ||
                stationName.contains("Neuhaus") || stationName.contains("Beatushöhlen") ||
                stationName.contains("Leissigen") || stationName.contains("Därligen") {
            return "Thunersee"
        }
        
        // Brienzersee
        else if stationName.contains("Brienz") || stationName.contains("Bönigen") ||
                stationName.contains("Iseltwald") || stationName.contains("Giessbach") ||
                stationName.contains("Oberried am Brienzersee") || stationName.contains("Niederried") ||
                stationName.contains("Ringgenberg") {
            return "Brienzersee"
        }
        
        // Lago Maggiore
        else if stationName.contains("Ascona") || stationName.contains("Locarno") ||
                stationName.contains("Tenero") || stationName.contains("Magadino") ||
                stationName.contains("Vira") || stationName.contains("Nazzaro") ||
                stationName.contains("Gerra") || stationName.contains("Ranzo") ||
                stationName.contains("Brissago") || stationName.contains("Porto Ronco") ||
                stationName.contains("Isole di Brissago") {
            return "Lago Maggiore"
        }
        
        // Lago di Lugano
        else if stationName.contains("Lugano") || stationName.contains("Paradiso") ||
                stationName.contains("Bissone") || stationName.contains("Cassarate") ||
                stationName.contains("Castagnola") || stationName.contains("Gandria") ||
                stationName.contains("Ponte Tresa") || stationName.contains("Brusino") ||
                stationName.contains("Melide") || stationName.contains("Morcote") ||
                stationName.contains("Maroggio") || stationName.contains("Melano") {
            return "Lago di Lugano"
        }
        
        // Bielersee
        else if stationName.contains("Biel") || stationName.contains("Bienne") ||
                stationName.contains("Tüscherz") || stationName.contains("Nidau") ||
                stationName.contains("Twann") || stationName.contains("Ligerz") ||
                stationName.contains("La Neuveville") || stationName.contains("Erlach") ||
                stationName.contains("Engelberg-Wingreis") {
            return "Bielersee"
        }
        
        // Neuenburgersee
        else if stationName.contains("Neuchâtel") || stationName.contains("Neuenburg") ||
                stationName.contains("Yverdon") || stationName.contains("Estavayer") ||
                stationName.contains("Portalban") || stationName.contains("Chevroux") ||
                stationName.contains("Chez-le-Bart") || stationName.contains("Grandson") ||
                stationName.contains("Concise") || stationName.contains("Gorgier") ||
                stationName.contains("Saint-Aubin") || stationName.contains("Sauges") ||
                stationName.contains("Cudrefin") || stationName.contains("Font") {
            return "Neuenburgersee"
        }
        
        // Murtensee
        else if stationName.contains("Murten") || stationName.contains("Morat") ||
                stationName.contains("Praz") || stationName.contains("Sugiez") ||
                stationName.contains("Motier") || stationName.contains("Vully") {
            return "Murtensee"
        }
        
        // Zugersee
        else if stationName.contains("Zug") || stationName.contains("Zugersee") ||
                stationName.contains("Cham") || stationName.contains("Walchwil") ||
                stationName.contains("Arth-Goldau") || stationName.contains("Immensee") {
            return "Zugersee"
        }
        
        // Walensee
        else if stationName.contains("Walensee") || stationName.contains("Walenstadt") ||
                stationName.contains("Murg") || stationName.contains("Unterterzen") ||
                stationName.contains("Quinten") || stationName.contains("Betlis") ||
                stationName.contains("Weesen") {
            return "Walensee"
        }
        
        // Hallwilersee
        else if stationName.contains("Hallwilersee") || stationName.contains("Hallwil") ||
                stationName.contains("Meisterschwanden") || stationName.contains("Beinwil am See") ||
                stationName.contains("Birrwil") || stationName.contains("Aesch LU") ||
                stationName.contains("Tennwil") {
            return "Hallwilersee"
        }
        
        // Ägerisee
        else if stationName.contains("Ägerisee") || stationName.contains("Agerisee") ||
                stationName.contains("Unterägeri") || stationName.contains("Oberägeri") ||
                stationName.contains("Morgarten") || stationName.contains("Alosen") {
            return "Ägerisee"
        }
        
        // Default fallback - Zürichsee since it's the most commonly used
        return "Zürichsee"
    }
}

// MARK: - Extension for easier access
extension SchedulePeriodService {
    /// Get countdown message for a station
    func getCountdownMessageForStation(_ stationName: String) -> String? {
        logger.debug("Getting countdown message for station: \(stationName)")
        
        guard let lakeName = getLakeForStation(stationName) else { 
            logger.debug("No lake found for station: \(stationName)")
            return nil 
        }
        
        logger.debug("Found lake: \(lakeName) for station: \(stationName)")
        
        let message = getScheduleCountdownMessage(for: lakeName)
        logger.debug("Schedule countdown message: \(message ?? "nil")")
        
        return message
    }
}
