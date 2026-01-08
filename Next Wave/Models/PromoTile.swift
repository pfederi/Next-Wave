import Foundation

struct PromoTile: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let text: String
    let imageUrl: String?
    let linkUrl: String?
    let isActive: Bool
    let priority: Int
    let validFrom: Date?
    let validUntil: Date?
    let targetOS: String?
    
    // Custom CodingKeys für API-Mapping
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case text
        case imageUrl = "image"  // API sendet "image"
        case linkUrl = "link"    // API sendet "link"
        case isActive
        case priority
        case validFrom
        case validUntil
        case targetOS
    }
    
    // Standard Initializer für Tests/Previews
    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        text: String,
        imageUrl: String? = nil,
        linkUrl: String? = nil,
        isActive: Bool = true,
        priority: Int = 1,
        validFrom: Date? = nil,
        validUntil: Date? = nil,
        targetOS: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.text = text
        self.imageUrl = imageUrl
        self.linkUrl = linkUrl
        self.isActive = isActive
        self.priority = priority
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.targetOS = targetOS
    }
    
    // Custom Decoder für fehlende Felder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        text = try container.decode(String.self, forKey: .text)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        linkUrl = try container.decodeIfPresent(String.self, forKey: .linkUrl)
        
        // Defaults für fehlende Felder
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 1
        validFrom = try container.decodeIfPresent(Date.self, forKey: .validFrom)
        validUntil = try container.decodeIfPresent(Date.self, forKey: .validUntil)
        targetOS = try container.decodeIfPresent(String.self, forKey: .targetOS)
    }
    
    var isValid: Bool {
        // Prüfe targetOS (nur iOS Tiles anzeigen)
        if let targetOS = targetOS {
            let lowercasedOS = targetOS.lowercased()
            // Akzeptiere "ios", "android,ios", "ios,android", "both" etc.
            if !lowercasedOS.contains("ios") && lowercasedOS != "both" {
                return false
            }
        }
        
        guard isActive else { return false }
        
        let now = Date()
        
        if let validFrom = validFrom, now < validFrom {
            return false
        }
        
        if let validUntil = validUntil, now > validUntil {
            return false
        }
        
        return true
    }
}

struct PromoTilesResponse: Codable {
    let tiles: [PromoTile]
    let version: Int?
    
    // Custom Decoder für fehlendes version Feld
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tiles = try container.decode([PromoTile].self, forKey: .tiles)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    }
    
    enum CodingKeys: String, CodingKey {
        case tiles
        case version
    }
}
