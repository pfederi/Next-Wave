import Foundation

struct FavoriteStation: Codable, Identifiable {
    let id: String // station id
    let name: String
    let latitude: Double?
    let longitude: Double?
    let uic_ref: String?
    
    static let maxFavorites = 5
}

class FavoriteStationsManager: ObservableObject {
    static let shared = FavoriteStationsManager()
    @Published private(set) var favorites: [FavoriteStation] = []
    
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "favoriteStations"
    
    private init() {
        loadFavorites()
    }
    
    private func loadFavorites() {
        if let data = userDefaults.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([FavoriteStation].self, from: data) {
            favorites = decoded
        }
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            userDefaults.set(encoded, forKey: favoritesKey)
        }
    }
    
    func addFavorite(_ station: Lake.Station) {
        guard !isFavorite(station) && favorites.count < FavoriteStation.maxFavorites else { return }
        let favorite = FavoriteStation(
            id: station.id, 
            name: station.name,
            latitude: station.coordinates?.latitude,
            longitude: station.coordinates?.longitude,
            uic_ref: station.uic_ref
        )
        favorites.append(favorite)
        saveFavorites()
    }
    
    func removeFavorite(_ station: Lake.Station) {
        favorites.removeAll { $0.id == station.id }
        saveFavorites()
    }
    
    func isFavorite(_ station: Lake.Station) -> Bool {
        favorites.contains { $0.id == station.id }
    }
    
    func reorderFavorites(fromOffsets source: IndexSet, toOffset destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }
} 