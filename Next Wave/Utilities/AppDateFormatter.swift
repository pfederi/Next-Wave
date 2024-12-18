import Foundation

enum AppDateFormatter {
    private static let zurichTimeZone = TimeZone(identifier: "Europe/Zurich")!
    private static let swissLocale = Locale(identifier: "de_CH")
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = zurichTimeZone
        formatter.locale = swissLocale
        return formatter
    }()
    
    private static let fullTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.timeZone = zurichTimeZone
        formatter.locale = swissLocale
        return formatter
    }()
    
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d. MMMM"
        formatter.timeZone = zurichTimeZone
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.timeZone = zurichTimeZone
        formatter.dateFormat = "d.M.yyyy"
        return formatter
    }()
    
    static func parseTime(_ timeString: String) -> Date? {
        guard let date = timeFormatter.date(from: timeString) else { return nil }
        
        // Setze die Zeit auf heute
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        return calendar.date(bySettingHour: components.hour ?? 0,
                           minute: components.minute ?? 0,
                           second: 0,
                           of: now)
    }
    
    static func parseFullTime(_ timeString: String) -> Date? {
        return fullTimeFormatter.date(from: timeString)
    }
    
    static func formatDisplayDate(_ date: Date) -> String {
        return displayDateFormatter.string(from: date)
    }
    
    static func formatTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    static func formatRemainingTime(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let timeDiff = calendar.dateComponents([.hour, .minute], from: now, to: date)
        let hours = timeDiff.hour ?? 0
        let minutes = timeDiff.minute ?? 0
        
        if date < now {
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
    
    static func parseDate(_ dateString: String, defaultYear: String? = nil) -> Date? {
        if dateString.contains(".20") {
            return dateFormatter.date(from: dateString)
        }
        
        if let year = defaultYear {
            return dateFormatter.date(from: dateString + "." + year)
        }
        
        return nil
    }
    
    static func calculateRemainingTime(for date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now, to: date)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        
        if minutes >= -5 && minutes <= 5 {
            return "now"
        }
        
        if minutes < -5 {
            return "missed"
        }
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        
        return "\(minutes)m"
    }
} 