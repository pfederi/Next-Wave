import Foundation

struct WaveEvent: Identifiable, Equatable {
    var id: String {
        "\(time.timeIntervalSince1970)_\(routeNumber)_\(isArrival)"
    }
    let time: Date
    let isArrival: Bool
    let routeNumber: String
    let routeName: String
    let neighborStop: String
    let period: String
    var hasNotification = false
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
    
    var remainingTimeString: String {
        let calendar = Calendar.current
        let now = Date()
        
        let timeDiff = calendar.dateComponents([.hour, .minute], from: now, to: time)
        let hours = timeDiff.hour ?? 0
        let minutes = timeDiff.minute ?? 0
        
        if time < now {
            return "missed"
        }
        
        if hours == 0 && minutes >= -5 && minutes <= 5 {
            return "now"
        }
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        
        return "\(minutes)m"
    }
    
    var direction: Direction {
        isArrival ? .arrival : .departure
    }
    
    static func == (lhs: WaveEvent, rhs: WaveEvent) -> Bool {
        lhs.id == rhs.id &&
        lhs.time == rhs.time &&
        lhs.isArrival == rhs.isArrival &&
        lhs.routeNumber == rhs.routeNumber &&
        lhs.routeName == rhs.routeName &&
        lhs.neighborStop == rhs.neighborStop &&
        lhs.period == rhs.period &&
        lhs.hasNotification == rhs.hasNotification
    }
}

enum Direction {
    case arrival
    case departure
    
    var description: String {
        switch self {
        case .arrival:
            return "from"
        case .departure:
            return "to"
        }
    }
} 