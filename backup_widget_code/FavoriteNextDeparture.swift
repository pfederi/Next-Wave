import Foundation

struct FavoriteNextDeparture: Codable {
    let stationName: String
    let destination: String
    let minutesUntilDeparture: Int
    
    static func from(_ departureInfo: DepartureInfo) -> FavoriteNextDeparture? {
        let now = Date()
        let minutes = Int(departureInfo.nextDeparture.timeIntervalSince(now) / 60)
        
        // Only return if departure is in the future
        guard minutes > 0 else { return nil }
        
        return FavoriteNextDeparture(
            stationName: departureInfo.stationName,
            destination: departureInfo.direction,
            minutesUntilDeparture: minutes
        )
    }
} 