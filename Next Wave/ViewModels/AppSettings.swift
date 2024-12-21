import SwiftUI

class AppSettings: ObservableObject {
    enum Theme: String, Codable {
        case light, dark, system
    }
    
    @Published var theme: Theme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "theme")
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
        if let savedTheme = UserDefaults.standard.string(forKey: "theme"),
           let theme = Theme(rawValue: savedTheme) {
            self.theme = theme
        } else {
            self.theme = .system
        }
    }
} 