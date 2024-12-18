import SwiftUI

struct DateTimeUtils {
    static func parseTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        
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
    
    static func calculateRemainingTime(for date: Date) -> String {
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
        if minutes > 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMinutes)min"
        }
        return "\(minutes)min"
    }
    
    static func getTimeColor(_ remainingTime: String) -> Color {
        switch remainingTime {
        case "now":
            return .green
        case "missed":
            return .red
        default:
            return .gray
        }
    }
} 