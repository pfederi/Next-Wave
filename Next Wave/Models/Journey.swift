import Foundation

struct Journey: Codable, Identifiable {
    let stop: Stop
    let name: String?
    let category: String?
    let subcategory: String?
    let categoryCode: String?
    let number: String?
    let operatorName: String?
    let to: String?
    let passList: [Stop]?
    let capacity1st: String?
    let capacity2nd: String?
    
    var id: String { name ?? UUID().uuidString }
    
    enum CodingKeys: String, CodingKey {
        case stop, name, category, subcategory, categoryCode, number
        case operatorName = "operator"
        case to, passList, capacity1st, capacity2nd
    }
}

extension Journey {
    struct Stop: Codable, Identifiable {
        let departure: String?
        let departureTimestamp: Int?
        let platform: String?
        let prognosis: Prognosis
        let station: Station
        let arrival: String?
        
        var id: String { station.id }
        
        struct Prognosis: Codable {
            let platform: String?
            let departure: String?
            let capacity1st: String?
            let capacity2nd: String?
        }
        
        struct Station: Codable {
            let id: String
            let name: String?
            let coordinate: Coordinate?
            
            struct Coordinate: Codable {
                let type: String
                let x: Double?
                let y: Double?
            }
        }
    }
}