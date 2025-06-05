import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    private let logger = iOSLogger.shared
    
    private override init() {
        super.init()
        logger.debug("WatchConnectivityManager initializing...")
        
        if WCSession.isSupported() {
            logger.debug("WatchConnectivity is supported")
            WCSession.default.delegate = self
            WCSession.default.activate()
            logger.debug("WatchConnectivity session activation requested")
            
            // Print initial state
            let session = WCSession.default
            logger.debug("Initial session state:")
            logger.debug("- Activation state: \(session.activationState.rawValue)")
            logger.debug("- isPaired: \(session.isPaired)")
            logger.debug("- isWatchAppInstalled: \(session.isWatchAppInstalled)")
            logger.debug("- isComplicationEnabled: \(session.isComplicationEnabled)")
            logger.debug("- Has content pending: \(session.hasContentPending)")
            logger.debug("- Application context: \(session.applicationContext)")
        } else {
            logger.error("WatchConnectivity is not supported!")
        }
    }
    
    func updateFavorites(_ favorites: [FavoriteStation]) {
        let session = WCSession.default
        guard session.activationState == .activated else {
            logger.error("Cannot update favorites - WatchConnectivity session not activated (state: \(session.activationState.rawValue))")
            return
        }
        
        guard session.isPaired else {
            logger.error("Cannot update favorites - Watch is not paired")
            return
        }
        
        guard session.isWatchAppInstalled else {
            logger.error("Cannot update favorites - Watch app is not installed")
            return
        }
        
        do {
            logger.debug("Attempting to send \(favorites.count) favorites to Watch")
            let data = try JSONEncoder().encode(favorites)
            try session.updateApplicationContext(["favoriteStations": data])
            logger.debug("Successfully sent favorites to Watch")
            
            // Print current application context
            if let currentContext = session.applicationContext["favoriteStations"] as? Data,
               let currentFavorites = try? JSONDecoder().decode([FavoriteStation].self, from: currentContext) {
                logger.debug("Current application context contains \(currentFavorites.count) favorites")
            }
            
            // Force widget update immediately
            triggerWidgetUpdate()
            
        } catch {
            logger.error("Failed to send favorites to Watch: \(error.localizedDescription)")
        }
    }
    
    func triggerWidgetUpdate() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            logger.error("Cannot trigger widget update - Watch not available")
            return
        }
        
        // Send immediate message to force widget update
        let message = ["action": "forceWidgetUpdate", "timestamp": Date().timeIntervalSince1970] as [String : Any]
        
        if session.isReachable {
            // Watch is reachable - send message immediately
            session.sendMessage(message, replyHandler: { response in
                self.logger.debug("Widget update message sent successfully: \(response)")
            }, errorHandler: { error in
                self.logger.error("Failed to send widget update message: \(error.localizedDescription)")
            })
        } else {
            // Watch not reachable - transfer user info for later processing
            session.transferUserInfo(message)
            logger.debug("Widget update message queued for transfer")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            logger.error("WatchConnectivity session activation failed: \(error.localizedDescription)")
        } else {
            logger.debug("WatchConnectivity session activated successfully")
            logger.debug("Session state after activation:")
            logger.debug("- Activation state: \(activationState.rawValue)")
            logger.debug("- isPaired: \(session.isPaired)")
            logger.debug("- isWatchAppInstalled: \(session.isWatchAppInstalled)")
            logger.debug("- isComplicationEnabled: \(session.isComplicationEnabled)")
            logger.debug("- Has content pending: \(session.hasContentPending)")
            logger.debug("- Application context: \(session.applicationContext)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.debug("WatchConnectivity session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        logger.debug("WatchConnectivity session deactivated - reactivating...")
        WCSession.default.activate()
    }
} 