import Foundation

// MARK: - Schedule Period Models
struct SchedulePeriodsData: Codable {
    let lakes: [LakeSchedule]
    let lastUpdated: String
    let notes: String
    
    enum CodingKeys: String, CodingKey {
        case lakes
        case lastUpdated = "last_updated"
        case notes
    }
}

struct LakeSchedule: Codable {
    let name: String
    let operatorName: String
    let schedulePeriods: [SchedulePeriod]
    
    enum CodingKeys: String, CodingKey {
        case name
        case operatorName = "operator"
        case schedulePeriods = "schedule_periods"
    }
}

struct SchedulePeriod: Codable {
    let name: String
    let type: ScheduleType
    let startDate: String
    let endDate: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case name, type, description
        case startDate = "start_date"
        case endDate = "end_date"
    }
    
    // Convert string dates to Date objects
    var startDateObj: Date? {
        return DateFormatter.scheduleDate.date(from: startDate)
    }
    
    var endDateObj: Date? {
        return DateFormatter.scheduleDate.date(from: endDate)
    }
    
    // Check if current date is within this period
    func isCurrentPeriod(for date: Date = Date()) -> Bool {
        guard let start = startDateObj, let end = endDateObj else { return false }
        return date >= start && date <= end
    }
    
    // Get days until this period starts
    func daysUntilStart(from date: Date = Date()) -> Int? {
        guard let start = startDateObj else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: start)
        return components.day
    }
}

enum ScheduleType: String, Codable, CaseIterable {
    case summer = "summer"
    case winter = "winter" 
    case spring = "spring"
    case autumn = "autumn"
    
    var displayName: String {
        switch self {
        case .summer: return "Sommer"
        case .winter: return "Winter"
        case .spring: return "Frühling"
        case .autumn: return "Herbst"
        }
    }
    
    var emoji: String {
        switch self {
        case .summer: return "☀️"
        case .winter: return "❄️"
        case .spring: return "🌸"
        case .autumn: return "🍂"
        }
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let scheduleDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        return formatter
    }()
}
