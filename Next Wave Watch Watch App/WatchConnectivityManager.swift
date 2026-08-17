import Foundation
import WatchConnectivity
import WidgetKit

extension Notification.Name {
    static let favoritesUpdated = Notification.Name("favoritesUpdated")
    static let forceWidgetUpdate = Notification.Name("forceWidgetUpdate")
    static let widgetSettingsUpdated = Notification.Name("widgetSettingsUpdated")
    static let languageUpdated = Notification.Name("languageUpdated")
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    private let logger = WatchLogger.shared
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            logger.error("WatchConnectivity is not supported")
            return
        }
        
        logger.info("📱 WatchConnectivityManager initializing...")
        WCSession.default.delegate = self
        WCSession.default.activate()
        logger.info("📱 WatchConnectivity session activation requested")
    }
    }
    
    // MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        logger.info("📱 WatchConnectivity session activated with state: \(activationState.rawValue)")
        
        if let error = error {
            logger.error("📱 WatchConnectivity activation error: \(error.localizedDescription)")
        } else {
            logger.info("📱 WatchConnectivity session activated successfully")
            
            // Process any existing application context
            processApplicationContext(session.applicationContext)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        logger.info("📱 Received application context with \(applicationContext.keys.count) keys")
        processApplicationContext(applicationContext)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        logger.info("📱 Received immediate message: \(message)")
        
        if let action = message["action"] as? String {
            switch action {
            case "forceWidgetUpdate":
                logger.info("📱 Received force widget update message")
                
                DispatchQueue.main.async {
                    // Force immediate widget update
                    WidgetCenter.shared.reloadAllTimelines()
                    self.logger.info("📱 Forced widget update from iOS message")
                    
                    // Notify components about forced update
                    NotificationCenter.default.post(name: .forceWidgetUpdate, object: nil)
                    
                    // Reply to acknowledge receipt
                    replyHandler(["status": "updated", "timestamp": Date().timeIntervalSince1970])
                }
                
            case "updateWidgetSettings":
                if let useNearestStation = message["useNearestStation"] as? Bool {
                    logger.info("📱 Received widget settings update - useNearestStation: \(useNearestStation)")
                    
                    DispatchQueue.main.async {
                        SharedDataManager.shared.saveWidgetSettings(useNearestStation: useNearestStation)
                        
                        // Notify that widget settings have been updated
                        NotificationCenter.default.post(name: .widgetSettingsUpdated, object: nil)
                        
                        // Update widgets
                        WidgetCenter.shared.reloadAllTimelines()
                        
                        // Reply to acknowledge receipt
                        replyHandler(["status": "settings_updated", "useNearestStation": useNearestStation, "timestamp": Date().timeIntervalSince1970])
                    }
                }

            case "updateLanguage":
                if let language = message["appLanguage"] as? String {
                    logger.info("📱 Received language update - appLanguage: \(language)")

                    DispatchQueue.main.async {
                        SharedDataManager.shared.saveAppLanguage(language)
                        NotificationCenter.default.post(name: .languageUpdated, object: nil)
                        replyHandler(["status": "language_updated", "appLanguage": language, "timestamp": Date().timeIntervalSince1970])
                    }
                }

            default:
                logger.warning("📱 Unknown action in message: \(action)")
                replyHandler(["status": "unknown_action", "timestamp": Date().timeIntervalSince1970])
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        logger.info("📱 Received user info: \(userInfo)")
        
        if let action = userInfo["action"] as? String {
            switch action {
            case "forceWidgetUpdate":
                logger.info("📱 Received force widget update via user info")
                
                DispatchQueue.main.async {
                    // Force immediate widget update
                    WidgetCenter.shared.reloadAllTimelines()
                    self.logger.info("📱 Forced widget update from iOS user info")
                    
                    // Notify components about forced update
                    NotificationCenter.default.post(name: .forceWidgetUpdate, object: nil)
                }
                
            case "updateWidgetSettings":
                if let useNearestStation = userInfo["useNearestStation"] as? Bool {
                    logger.info("📱 Received widget settings update via user info - useNearestStation: \(useNearestStation)")
                    
                    DispatchQueue.main.async {
                        SharedDataManager.shared.saveWidgetSettings(useNearestStation: useNearestStation)
                        
                        // Notify that widget settings have been updated
                        NotificationCenter.default.post(name: .widgetSettingsUpdated, object: nil)
                        
                        // Update widgets
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }

            case "updateLanguage":
                if let language = userInfo["appLanguage"] as? String {
                    logger.info("📱 Received language update via user info - appLanguage: \(language)")

                    DispatchQueue.main.async {
                        SharedDataManager.shared.saveAppLanguage(language)
                        NotificationCenter.default.post(name: .languageUpdated, object: nil)
                    }
                }

            default:
                logger.warning("📱 Unknown action in user info: \(action)")
            }
        }
    }
    
    private func processApplicationContext(_ context: [String: Any]) {
        var hasUpdates = false
        
        // Process favorites
        if let favoritesData = context["favoriteStations"] as? Data {
            do {
                let favorites = try JSONDecoder().decode([FavoriteStation].self, from: favoritesData)
                logger.info("📱 Received \(favorites.count) favorites from iOS")
                    
                DispatchQueue.main.async {
                    SharedDataManager.shared.saveFavoriteStations(favorites)
                    self.logger.info("📱 Successfully saved favorites to Watch SharedDataManager")
                    
                    // Notify that favorites have been updated
                    NotificationCenter.default.post(name: .favoritesUpdated, object: nil)
                }
                hasUpdates = true
            } catch {
                logger.error("📱 Failed to decode favorites: \(error.localizedDescription)")
            }
        } else {
            logger.debug("📱 No favorites data in application context")
        }
        
        // Process widget settings
        if let widgetSettingsData = context["widgetSettings"] as? Data {
            do {
                let widgetSettings = try JSONDecoder().decode(SharedDataManager.WidgetSettings.self, from: widgetSettingsData)
                logger.info("📱 Received widget settings from iOS - useNearestStation: \(widgetSettings.useNearestStation)")
                
                DispatchQueue.main.async {
                    SharedDataManager.shared.saveWidgetSettings(useNearestStation: widgetSettings.useNearestStation)
                    self.logger.info("📱 Successfully saved widget settings to Watch SharedDataManager")
                    
                    // Notify that widget settings have been updated
                    NotificationCenter.default.post(name: .widgetSettingsUpdated, object: nil)
                }
                hasUpdates = true
            } catch {
                logger.error("📱 Failed to decode widget settings: \(error.localizedDescription)")
            }
        } else {
            logger.debug("📱 No widget settings data in application context")
        }

        // Process language setting
        if let language = context["appLanguage"] as? String {
            logger.info("📱 Received language setting from iOS: \(language)")
            DispatchQueue.main.async {
                SharedDataManager.shared.saveAppLanguage(language)
                NotificationCenter.default.post(name: .languageUpdated, object: nil)
            }
            hasUpdates = true
        }

        // Update widgets if we had any updates
        if hasUpdates {
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
                self.logger.info("📱 Triggered widget updates for new data")
                
                // Notify view model about updates
                NotificationCenter.default.post(name: NSNotification.Name("ApplicationContextUpdated"), object: nil)
            }
        }
    }
} 