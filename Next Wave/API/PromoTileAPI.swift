import Foundation

actor PromoTileAPI {
    static let shared = PromoTileAPI()
    
    private var cachedTiles: [PromoTile] = []
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 3600 // 1 Stunde
    
    private init() {}
    
    func getPromoTiles() async throws -> [PromoTile] {
        // Cache-Check
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheDuration,
           !cachedTiles.isEmpty {
            return cachedTiles.filter { $0.isValid }
        }
        
        guard let url = URL(string: "https://www.nextwaveapp.ch/api/promo-tiles.json") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData // Immer frische Daten holen
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Wenn 404, dann gibt es keine Promo-Tiles (das ist ok)
        if httpResponse.statusCode == 404 {
            cachedTiles = []
            lastFetchTime = Date()
            return []
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let tilesResponse = try decoder.decode(PromoTilesResponse.self, from: data)
        
        cachedTiles = tilesResponse.tiles
        lastFetchTime = Date()
        
        let validTiles = cachedTiles.filter { $0.isValid }
        return validTiles
    }
    
    func clearCache() {
        cachedTiles = []
        lastFetchTime = nil
    }
}
