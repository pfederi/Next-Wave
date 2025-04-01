import Foundation

struct WaveTimeSlot: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let waveCount: Int
    let waves: [WaveEvent]
    
    private static let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return calendar
    }()
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var wavesPerHour: Double {
        let hours = duration / 3600
        return Double(waveCount) / hours
    }
    
    var startTimeString: String {
        AppDateFormatter.formatTime(startTime)
    }
    
    var endTimeString: String {
        AppDateFormatter.formatTime(endTime)
    }
}

struct SpotAnalytics {
    let spotId: String
    let spotName: String
    let timeSlots: [WaveTimeSlot]
    
    var bestTimeSlot: WaveTimeSlot? {
        timeSlots.first
    }
    
    var totalWaves: Int {
        timeSlots.reduce(0) { $0 + $1.waveCount }
    }
} 