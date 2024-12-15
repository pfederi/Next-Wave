import Foundation

struct StationboardResponse: Codable {
    let stationboard: [Journey]
    let station: Station?
    
    struct Station: Codable {
        let name: String
        let id: String?
    }
}

struct ConnectionResponse: Codable {
    let connections: [Connection]
    
    struct Connection: Codable {
        let sections: [Section]
        
        struct Section: Codable {
            let journey: Journey?
        }
    }
} 