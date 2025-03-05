import SwiftUI

extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
}

class AppSettings: ObservableObject {
    enum Theme: String, Codable {
        case light, dark, system
    }
    
    @Published var theme: Theme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "theme")
        }
    }
    
    @Published var lastLocationPickerMode: LocationPickerMode {
        didSet {
            UserDefaults.standard.set(lastLocationPickerMode.rawValue, forKey: "lastLocationPickerMode")
        }
    }
    
    @Published var lastMapRegion: MapRegion {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(lastMapRegion), forKey: "lastMapRegion")
        }
    }
    
    @Published var showNearestStation: Bool {
        didSet {
            UserDefaults.standard.set(showNearestStation, forKey: "showNearestStation")
        }
    }
    
    @Published var showWeatherInfo: Bool {
        didSet {
            UserDefaults.standard.set(showWeatherInfo, forKey: "showWeatherInfo")
        }
    }
    
    var isDarkMode: Bool {
        switch theme {
        case .light:
            return false
        case .dark:
            return true
        case .system:
            return UITraitCollection.current.userInterfaceStyle == .dark
        }
    }
    
    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "theme") ?? Theme.system.rawValue
        self.theme = Theme(rawValue: savedTheme) ?? .system
        
        let savedMode = UserDefaults.standard.string(forKey: "lastLocationPickerMode") ?? LocationPickerMode.list.rawValue
        self.lastLocationPickerMode = LocationPickerMode(rawValue: savedMode) ?? .list
        
        if let savedRegionData = UserDefaults.standard.data(forKey: "lastMapRegion"),
           let savedRegion = try? JSONDecoder().decode(MapRegion.self, from: savedRegionData) {
            self.lastMapRegion = savedRegion
        } else {
            self.lastMapRegion = MapRegion(
                latitude: 47.3769,
                longitude: 8.5417,
                latitudeDelta: 3,
                longitudeDelta: 3
            )
        }
        
        // Initialize showNearestStation with default value true
        self.showNearestStation = UserDefaults.standard.bool(forKey: "showNearestStation", defaultValue: true)
        
        // Initialize showWeatherInfo with default value true
        self.showWeatherInfo = UserDefaults.standard.bool(forKey: "showWeatherInfo", defaultValue: true)
    }
}

enum LocationPickerMode: String {
    case list
    case map
}

struct MapRegion: Codable {
    let latitude: Double
    let longitude: Double
    let latitudeDelta: Double
    let longitudeDelta: Double
} 