import Foundation
import WatchConnectivity
import WidgetKit

extension Notification.Name {
    static let favoritesUpdated = Notification.Name("favoritesUpdated")
    static let forceWidgetUpdate = Notification.Name("forceWidgetUpdate")
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
        
        if let action = message["action"] as? String, action == "forceWidgetUpdate" {
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
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        logger.info("📱 Received user info: \(userInfo)")
        
        if let action = userInfo["action"] as? String, action == "forceWidgetUpdate" {
            logger.info("📱 Received force widget update via user info")
            
            DispatchQueue.main.async {
                // Force immediate widget update
                WidgetCenter.shared.reloadAllTimelines()
                self.logger.info("📱 Forced widget update from iOS user info")
                
                // Notify components about forced update
                NotificationCenter.default.post(name: .forceWidgetUpdate, object: nil)
            }
        }
    }
    
    private func processApplicationContext(_ context: [String: Any]) {
        guard let favoritesData = context["favoriteStations"] as? Data else {
            logger.debug("📱 No favorites data in application context")
            return
        }
        
        do {
            let favorites = try JSONDecoder().decode([FavoriteStation].self, from: favoritesData)
            logger.info("📱 Received \(favorites.count) favorites from iOS")
                
            // Save to SharedDataManager
            DispatchQueue.main.async {
                SharedDataManager.shared.saveFavoriteStations(favorites)
                self.logger.info("📱 Successfully saved favorites to Watch SharedDataManager")
                
                // Notify that favorites have been updated
                NotificationCenter.default.post(name: .favoritesUpdated, object: nil)
                
                // Immediately update all widgets
                WidgetCenter.shared.reloadAllTimelines()
                self.logger.info("📱 Triggered widget updates for new favorites")
            }
            } catch {
            logger.error("📱 Failed to decode favorites: \(error.localizedDescription)")
        }
    }
} 