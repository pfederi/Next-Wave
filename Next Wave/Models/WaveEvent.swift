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
    let neighborStopName: String
    let period: String
    var hasNotification = false
    
    var timeString: String {
        return AppDateFormatter.formatTime(time)
    }
    
    var remainingTimeString: String {
        return AppDateFormatter.formatRemainingTime(from: time)
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
        lhs.neighborStopName == rhs.neighborStopName &&
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