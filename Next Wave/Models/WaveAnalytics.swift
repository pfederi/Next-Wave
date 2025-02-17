import Foundation

struct WaveTimeSlot: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let waveCount: Int
    let waves: [WaveEvent]
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var wavesPerHour: Double {
        let hours = duration / 3600
        return Double(waveCount) / hours
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