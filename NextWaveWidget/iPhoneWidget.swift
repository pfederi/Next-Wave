//
//  iPhoneWidget.swift
//  NextWaveWidget
//
//  Created by Patrick Federi on 11.06.2025.
//

import WidgetKit
import SwiftUI
import os.log
import Foundation

#if os(iOS)

// Create a specific logger for the widget
private let widgetLogger = Logger(subsystem: "com.federi.Next-Wave.NextWaveWidget", category: "iPhoneWidget")

// Generate informative messages based on data age
private func getInformativeMessage(timeAgo: TimeInterval) -> (routeName: String, direction: String) {
    let _ = timeAgo / 3600
    let days = timeAgo / 86400
    
    if timeAgo < 1800 { // Less than 30 minutes
        return ("Refreshing...", "Tap to open app")
    } else if timeAgo < 3600 { // Less than 1 hour
        return ("Data Loading", "Open app to refresh")
    } else if timeAgo < 7200 { // Less than 2 hours
        return ("Open App", "to load fresh times")
    } else if timeAgo < 21600 { // Less than 6 hours
        return ("Open App", "for current schedules")
    } else if days < 1 {
        return ("Open App", "data from today")
    } else if days < 2 {
        return ("Open App", "data from yesterday")
    } else {
        return ("Open App", "to update schedules")
    }
}

// Smart update timing for widgets based on departure times and current time
private func calculateNextUpdate(from now: Date, nextDeparture: Date? = nil) -> Date {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: now)
    
    // If we have a next departure, calculate based on that
    if let nextDeparture = nextDeparture {
        let timeToDeparture = nextDeparture.timeIntervalSince(now)
        
        // If departure is in the past or within 1 minute, refresh immediately
        if timeToDeparture <= 60 {
            let immediateUpdate = now.addingTimeInterval(15) // 15 seconds for faster updates
            widgetLogger.info("🕰️ Departure time passed or very soon, refreshing in 15 seconds")
            return immediateUpdate
        }
        
        // If departure is within 30 minutes, refresh every 1 minute for real-time updates
        if timeToDeparture <= 30 * 60 {
            let nextUpdate = now.addingTimeInterval(1 * 60) // 1 minute
            widgetLogger.info("🕰️ Departure within 30 minutes, refreshing every 1 minute")
            return nextUpdate
        }
        
        // If departure is within 2 hours, refresh every 10 minutes
        if timeToDeparture <= 2 * 60 * 60 {
            let nextUpdate = now.addingTimeInterval(10 * 60) // 10 minutes
            widgetLogger.info("🕰️ Departure within 2 hours, refreshing every 10 minutes")
            return nextUpdate
        }
    }
    
    // If it's after 17:00, schedule an update for tomorrow at 7:00 to load next day's data
    if hour >= 17 {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrowMorning = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        widgetLogger.info("🕰️ Scheduling next update for tomorrow 7:00 to load fresh data")
        return tomorrowMorning
    }
    
    // During the day, update every 15 minutes to keep data fresh
    let nextUpdate = now.addingTimeInterval(15 * 60) // 15 minutes
    widgetLogger.info("🕰️ No specific departure time, refreshing every 15 minutes")
    return nextUpdate
}

// Check if we should trigger a data refresh request
private func shouldRequestDataRefresh(from now: Date, allDepartures: [DepartureInfo] = []) -> Bool {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: now)
    let minute = calendar.component(.minute, from: now)
    
    // Check if any departure times are stale (in the past)
    let staleDepartures = allDepartures.filter { $0.nextDeparture <= now }
    if !staleDepartures.isEmpty {
        widgetLogger.info("🔄 Found \(staleDepartures.count) stale departures, requesting refresh")
        return true
    }
    
    // Check if the next departure is very soon (within 5 minutes) and we need fresh data
    let soonDepartures = allDepartures.filter { 
        let timeToDeparture = $0.nextDeparture.timeIntervalSince(now)
        return timeToDeparture > 0 && timeToDeparture <= 5 * 60 // Increased to 5 minutes
    }
    if !soonDepartures.isEmpty {
        widgetLogger.info("🔄 Next departure within 5 minutes, requesting fresh data")
        return true
    }
    
    // Additional check: if no future departures exist for any station, refresh needed
    let futureDepartures = allDepartures.filter { $0.nextDeparture > now }
    if futureDepartures.isEmpty && !allDepartures.isEmpty {
        widgetLogger.info("🔄 No future departures found but have data, requesting refresh")
        return true
    }
    
    // More aggressive check: if we have very few future departures left (less than 3)
    // and the last departure is within the next 2 hours, request refresh to load more
    if futureDepartures.count < 3 && futureDepartures.count > 0 {
        if let lastDeparture = futureDepartures.last,
           lastDeparture.nextDeparture.timeIntervalSince(now) <= 2 * 60 * 60 { // Within 2 hours
            widgetLogger.info("🔄 Only \(futureDepartures.count) departures remaining and last one is within 2h, requesting refresh for more data")
            return true
        }
    }
    
    // Trigger refresh at 17:00 to load next day's data
    if hour == 17 && minute < 15 {
        widgetLogger.info("🔄 Should request data refresh for next day")
        return true
    }
    
    // Also trigger refresh in the morning to ensure fresh data
    if hour == 7 && minute < 15 {
        widgetLogger.info("🔄 Should request morning data refresh")
        return true
    }
    
    return false
}

// Trigger background data refresh by setting a flag for the main app
private func triggerBackgroundDataRefresh() {
    let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
    
    // Set a flag indicating that fresh data is needed
    userDefaults?.set(Date(), forKey: "widget_requested_refresh")
    userDefaults?.set(true, forKey: "widget_needs_fresh_data")
    
    widgetLogger.info("🔄 Triggered background data refresh request")
    
    // Additionally, we can try to wake up the main app if possible
    if URL(string: "nextwave://refresh-data") != nil {
        // This won't work from widget context, but the flag above will help
        widgetLogger.info("🔄 Set refresh URL request")
    }
}

// MARK: - Widget Background Modifier
extension View {
    func widgetBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 17.0, *) {
            return self.containerBackground(for: .widget, content: content)
        } else {
            return self.background(content())
        }
    }
}

// MARK: - iPhone Widget Provider
struct iPhoneProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(), 
            departure: DepartureInfo(
                stationName: "Brienz",
                nextDeparture: Date().addingTimeInterval(15 * 60),
                routeName: "BLS",
                direction: "Interlaken"
            ),
            displayMode: .firstFavorite,
            stationName: "Brienz"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let now = Date()
        var entries: [SimpleEntry] = []
        
        // Always ensure we have at least one entry to prevent timeline errors
        defer {
            if entries.isEmpty {
                // Fallback: create a single entry with no departure data
                let entry = SimpleEntry(
                    date: now, 
                    departure: nil,
                    displayMode: .firstFavorite,
                    stationName: nil
                )
                entries.append(entry)
                NSLog("🚨 CRITICAL: Creating fallback timeline with single empty entry")
                widgetLogger.error("🚨 CRITICAL: Creating fallback timeline with single empty entry")
            }
            
            NSLog("🔍 Creating timeline with %d entries", entries.count)
            widgetLogger.info("🔍 Creating timeline with \(entries.count) entries")
            
            // Use smart update timing based on the next departure
            let nextDeparture = entries.first?.departure?.nextDeparture
            let nextUpdate = calculateNextUpdate(from: now, nextDeparture: nextDeparture)
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
        
        // Comprehensive debugging with NSLog and os_log
        let timestamp = Date()
        NSLog("🔍 iPhone Widget getTimeline called at %@", timestamp.description)
        widgetLogger.info("🔍 iPhone Widget getTimeline called at \(timestamp)")
        
        // Check if we should trigger a background refresh to load new data
        let allDepartures = SharedDataManager.shared.loadNextDepartures()
        if shouldRequestDataRefresh(from: now, allDepartures: allDepartures) {
            triggerBackgroundDataRefresh()
        }
        
        // Test UserDefaults access
        let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
        NSLog("🔍 UserDefaults suite: group.com.federi.Next-Wave")
        NSLog("🔍 UserDefaults is nil: %@", userDefaults == nil ? "true" : "false")
        widgetLogger.info("🔍 UserDefaults is nil: \(userDefaults == nil)")
        
        // Check all keys
        if let dict = userDefaults?.dictionaryRepresentation() {
            let keys = Array(dict.keys).sorted()
            NSLog("🔍 All UserDefaults keys: %@", keys.joined(separator: ", "))
            widgetLogger.info("🔍 All UserDefaults keys: \(keys)")
            
            // Look for favorites data specifically
            if let favoritesData = userDefaults?.data(forKey: "favoriteStations") {
                NSLog("🔍 Found favoriteStations data: %d bytes", favoritesData.count)
                widgetLogger.info("🔍 Found favoriteStations data: \(favoritesData.count) bytes")
                
                if let favorites = try? JSONDecoder().decode([FavoriteStation].self, from: favoritesData) {
                    NSLog("🔍 Successfully decoded %d favorites", favorites.count)
                    widgetLogger.info("🔍 Successfully decoded \(favorites.count) favorites")
                    for favorite in favorites {
                        NSLog("🔍   - %@", favorite.name)
                        widgetLogger.info("🔍   - \(favorite.name)")
                    }
                } else {
                    NSLog("🔍 Failed to decode favorites data")
                    widgetLogger.error("🔍 Failed to decode favorites data")
                }
            } else {
                NSLog("🔍 No favoriteStations data found in UserDefaults")
                widgetLogger.warning("🔍 No favoriteStations data found in UserDefaults")
            }
        } else {
            NSLog("🔍 UserDefaults dictionary is nil")
            widgetLogger.error("🔍 UserDefaults dictionary is nil")
        }
        
        // FALLBACK: Also check standard UserDefaults
        NSLog("🔍 FALLBACK: Checking standard UserDefaults")
        widgetLogger.info("🔍 FALLBACK: Checking standard UserDefaults")
        let standardDefaults = UserDefaults.standard
        if let fallbackData = standardDefaults.data(forKey: "fallback_favoriteStations") {
            NSLog("🔍 FALLBACK: Found fallback data: %d bytes", fallbackData.count)
            widgetLogger.info("🔍 FALLBACK: Found fallback data: \(fallbackData.count) bytes")
            if let favorites = try? JSONDecoder().decode([FavoriteStation].self, from: fallbackData) {
                NSLog("🔍 FALLBACK: Successfully decoded %d favorites", favorites.count)
                widgetLogger.info("🔍 FALLBACK: Successfully decoded \(favorites.count) favorites")
                for favorite in favorites {
                    NSLog("🔍 FALLBACK:   - %@", favorite.name)
                    widgetLogger.info("🔍 FALLBACK:   - \(favorite.name)")
                }
            }
        } else {
            NSLog("🔍 FALLBACK: No fallback data found")
            widgetLogger.warning("🔍 FALLBACK: No fallback data found")
        }
        
        // Test SharedDataManager
        let favoriteStations = SharedDataManager.shared.loadFavoriteStations()
        NSLog("🔍 SharedDataManager.loadFavoriteStations() returned %d stations", favoriteStations.count)
        widgetLogger.info("🔍 SharedDataManager.loadFavoriteStations() returned \(favoriteStations.count) stations")
        
        if !favoriteStations.isEmpty {
            NSLog("🔍 First favorite from SharedDataManager: %@", favoriteStations[0].name)
            widgetLogger.info("🔍 First favorite from SharedDataManager: \(favoriteStations[0].name)")
        } else {
            NSLog("🔍 SharedDataManager returned NO favorites - this is the root cause!")
            widgetLogger.error("🔍 SharedDataManager returned NO favorites - this is the root cause!")
        }
        
        // Test widget logic
        let settings = SharedDataManager.shared.loadWidgetSettings()
        let displayMode: WidgetDisplayMode = settings.useNearestStation ? .nearestStation : .firstFavorite
        let nextDeparture = SharedDataManager.shared.getNextDepartureForWidget()
        let departureInfo = nextDeparture?.stationName ?? "nil"
        NSLog("🔍 Display mode: %@, getNextDepartureForWidget returned: %@", displayMode.displayName, departureInfo)
        widgetLogger.info("🔍 Display mode: \(displayMode.displayName), getNextDepartureForWidget returned: \(departureInfo)")

        // Check if we have any departure data at all (using the allDepartures from above)
        NSLog("🔍 Total departures in cache: %d", allDepartures.count)
        widgetLogger.info("🔍 Total departures in cache: \(allDepartures.count)")
        
        if allDepartures.isEmpty && !favoriteStations.isEmpty {
            NSLog("🔍 No departure data found but have favorites - showing hint to open app")
            widgetLogger.info("🔍 No departure data found but have favorites - showing hint to open app")
            
            // Create a helpful hint departure to show that we have favorites but need app to load data
            let lastRefresh = UserDefaults(suiteName: "group.com.federi.Next-Wave")?.object(forKey: "last_data_refresh") as? Date
            let timeAgo = lastRefresh?.timeIntervalSinceNow ?? -86400 // Default to 24h ago
            
            let (routeName, direction) = getInformativeMessage(timeAgo: abs(timeAgo))
            
            let hintDeparture = DepartureInfo(
                stationName: favoriteStations[0].name,
                nextDeparture: Date().addingTimeInterval(300), // 5 minutes from now (shorter)
                routeName: routeName,
                direction: direction
            )
            
            // Create entries with hint
            for i in 0..<30 {
                let entryDate = now.addingTimeInterval(TimeInterval(i * 60))
                let entry = SimpleEntry(
                    date: entryDate, 
                    departure: hintDeparture,
                    displayMode: displayMode,
                    stationName: favoriteStations[0].name
                )
                entries.append(entry)
            }
            
            NSLog("🔍 Created hint timeline for: %@", hintDeparture.stationName)
            widgetLogger.info("🔍 Created hint timeline for: \(hintDeparture.stationName)")
            
        } else if !allDepartures.isEmpty {
            NSLog("🔍 Creating dynamic single departure timeline")
            widgetLogger.info("🔍 Creating dynamic single departure timeline")
            
            // Get station name based on display mode
            let stationName: String?
            if settings.useNearestStation {
                stationName = SharedDataManager.shared.loadNearestStation()?.name
            } else {
                stationName = favoriteStations.first?.name
            }
            
            // Get target station name for filtering
            let targetStationName = stationName ?? ""
            
            // Filter departures for the target station and future times only
            let stationDepartures = allDepartures
                .filter { $0.stationName == targetStationName }
                .filter { $0.nextDeparture > now }
                .sorted { $0.nextDeparture < $1.nextDeparture }
            
            NSLog("🔍 Found %d future departures for station: %@", stationDepartures.count, targetStationName)
            widgetLogger.info("🔍 Found \(stationDepartures.count) future departures for station: \(targetStationName)")
            
            if !stationDepartures.isEmpty {
                // Create timeline entries that automatically show the CURRENT next departure at each time
                // Ensure frequent updates when departures are imminent
                let totalMinutes = 120 // 2 hours of timeline entries
                let intervalMinutes = 1 // 1-minute intervals for more responsive updates
                
                for i in 0..<totalMinutes {
                    let entryDate = now.addingTimeInterval(TimeInterval(i * intervalMinutes * 60))
                    
                    // Find the next departure that's still in the future at this timeline entry time
                    // This ensures the widget always shows the CURRENT next departure
                    let nextDepartureAtTime = stationDepartures.first { departure in
                        departure.nextDeparture > entryDate
                    }
                    
                    let entry = SimpleEntry(
                        date: entryDate, 
                        departure: nextDepartureAtTime, // This dynamically updates to show current next departure
                        displayMode: displayMode,
                        stationName: stationName
                    )
                    entries.append(entry)
                    
                    // Log first few for debugging
                    if i < 5 && nextDepartureAtTime != nil {
                        let departureTime = nextDepartureAtTime!.nextDeparture
                        let timeUntilDeparture = Int(departureTime.timeIntervalSince(entryDate) / 60)
                        NSLog("🔍 Entry %d at %@ shows departure in %d min (%@)", i, entryDate.description, timeUntilDeparture, nextDepartureAtTime!.routeName)
                    }
                }
                
                NSLog("🔍 Created dynamic timeline with %d entries (1-min intervals)", entries.count)
                widgetLogger.info("🔍 Created dynamic timeline with \(entries.count) entries (1-min intervals)")
            } else {
                // Fallback to static entry if no departures for this station
                NSLog("🔍 No departures for station %@, using fallback", targetStationName)
                widgetLogger.warning("🔍 No departures for station \(targetStationName), using fallback")
                
                for i in 0..<30 {
                    let entryDate = now.addingTimeInterval(TimeInterval(i * 60))
                    let entry = SimpleEntry(
                        date: entryDate, 
                        departure: nil,
                        displayMode: displayMode,
                        stationName: stationName
                    )
                    entries.append(entry)
                }
            }
            
        } else {
            NSLog("🔍 No departure found - creating empty timeline")
            widgetLogger.warning("🔍 No departure found - creating empty timeline")
            // Even without departures, create entries to keep widget responsive
            for i in 0..<30 {
                let entryDate = now.addingTimeInterval(TimeInterval(i * 60))
                let entry = SimpleEntry(
                    date: entryDate, 
                    departure: nil,
                    displayMode: displayMode,
                    stationName: nil
                )
                entries.append(entry)
            }
        }
    }

}

// MARK: - iPhone Multiple Departures Provider
struct iPhoneMultipleProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        let sampleDepartures = [
            DepartureInfo(stationName: "Brienz", nextDeparture: Date().addingTimeInterval(15 * 60), routeName: "BLS", direction: "Interlaken"),
            DepartureInfo(stationName: "Brienz", nextDeparture: Date().addingTimeInterval(35 * 60), routeName: "BLS", direction: "Interlaken"),
            DepartureInfo(stationName: "Brienz", nextDeparture: Date().addingTimeInterval(55 * 60), routeName: "BLS", direction: "Interlaken")
        ]
        return SimpleEntry(
            date: Date(), 
            departure: sampleDepartures.first,
            departures: sampleDepartures,
            displayMode: .firstFavorite,
            stationName: "Brienz"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let now = Date()
        var entries: [SimpleEntry] = []
        
        // Always ensure we have at least one entry to prevent timeline errors
        defer {
            if entries.isEmpty {
                // Fallback: create a single entry with no departure data
                let entry = SimpleEntry(
                    date: now, 
                    departure: nil,
                    displayMode: .firstFavorite,
                    stationName: nil
                )
                entries.append(entry)
                NSLog("🚨 CRITICAL: Creating fallback timeline with single empty entry (Multiple)")
                widgetLogger.error("🚨 CRITICAL: Creating fallback timeline with single empty entry (Multiple)")
            }
            
            NSLog("🔍 Creating multiple departures timeline with %d entries", entries.count)
            widgetLogger.info("🔍 Creating multiple departures timeline with \(entries.count) entries")
            
            // Use smart update timing based on the next departure
            let nextDeparture = entries.first?.departure?.nextDeparture
            let nextUpdate = calculateNextUpdate(from: now, nextDeparture: nextDeparture)
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
        
        NSLog("🔍 iPhone Multiple Widget getTimeline called at %@", now.description)
        widgetLogger.info("🔍 iPhone Multiple Widget getTimeline called at \(now)")
        
        // Check if we should trigger a background refresh to load new data
        let allDepartures = SharedDataManager.shared.loadNextDepartures()
        if shouldRequestDataRefresh(from: now, allDepartures: allDepartures) {
            triggerBackgroundDataRefresh()
        }
        
        // Get display mode and station info
        let settings = SharedDataManager.shared.loadWidgetSettings()
        let displayMode: WidgetDisplayMode = settings.useNearestStation ? .nearestStation : .firstFavorite
        
        // Get station name based on display mode
        let stationName: String?
        if settings.useNearestStation {
            stationName = SharedDataManager.shared.loadNearestStation()?.name
        } else {
            stationName = SharedDataManager.shared.loadFavoriteStations().first?.name
        }
        
        // Get target station name for dynamic filtering
        let targetStationName = stationName ?? ""
        
        NSLog("🔍 Display mode: %@, Total departures loaded: %d", displayMode.displayName, allDepartures.count)
        widgetLogger.info("🔍 Display mode: \(displayMode.displayName), Total departures loaded: \(allDepartures.count)")
        
        // Log all stations with departures for debugging
        let stationNames = Set(allDepartures.map { $0.stationName })
        NSLog("🔍 Stations with data: %@", Array(stationNames).sorted().joined(separator: ", "))
        widgetLogger.info("🔍 Stations with data: \(Array(stationNames).sorted())")
        
        // Filter departures for the target station
        let stationDepartures = allDepartures
            .filter { $0.stationName == targetStationName }
            .filter { $0.nextDeparture > now }
            .sorted { $0.nextDeparture < $1.nextDeparture }
        
        NSLog("🔍 Found %d future departures for station: %@", stationDepartures.count, targetStationName)
        widgetLogger.info("🔍 Found \(stationDepartures.count) future departures for station: \(targetStationName)")
        
        // Log first few departures from original data
        for (index, departure) in stationDepartures.prefix(3).enumerated() {
            let minutesFromNow = Int(departure.nextDeparture.timeIntervalSince(now) / 60)
            NSLog("🔍   Original %d: %@ → %@ in %d min", index + 1, departure.routeName, departure.direction, minutesFromNow)
        }
        
        if !stationDepartures.isEmpty {
            NSLog("🔍 Creating dynamic multiple departures timeline for: %@", targetStationName)
            widgetLogger.info("🔍 Creating dynamic multiple departures timeline for: \(targetStationName)")
            
            // Create timeline entries that automatically show the next 3-5 departures at each time
            // Use 1-minute intervals for responsive updates, especially when departures are imminent
            let totalMinutes = 120 // 2 hours of timeline entries
            let intervalMinutes = 1 // 1-minute intervals for responsive updates
            
            // Pre-load ALL available departures for seamless transitions
            // Get many departures to ensure seamless transitions throughout the day
            let seamlessDepartures = SharedDataManager.shared.getSeamlessDeparturesForMultipleWidget()
            
            // Combine with current station departures and remove duplicates
            let combinedDepartures = (stationDepartures + seamlessDepartures)
                .filter { $0.nextDeparture > now } // Only future departures
                .sorted { $0.nextDeparture < $1.nextDeparture }
            
            // Remove duplicates based on departure time and route
            var allAvailableDepartures: [DepartureInfo] = []
            var seenDepartures: Set<String> = []
            
            for departure in combinedDepartures {
                let key = "\(departure.nextDeparture.timeIntervalSince1970)-\(departure.routeName)-\(departure.direction)"
                if !seenDepartures.contains(key) {
                    seenDepartures.insert(key)
                    allAvailableDepartures.append(departure)
                }
            }
            
            NSLog("🔍 Total available departures for seamless transition: %d", allAvailableDepartures.count)
            widgetLogger.info("🔍 Seamless transition prepared with \(allAvailableDepartures.count) departures")
            
            // Log the extended departure range for debugging
            if let first = allAvailableDepartures.first, let last = allAvailableDepartures.last {
                let firstMinutes = Int(first.nextDeparture.timeIntervalSince(now) / 60)
                let lastMinutes = Int(last.nextDeparture.timeIntervalSince(now) / 60)
                let lastHours = lastMinutes / 60
                NSLog("🔍 Departure range: %d min to %d min (%d hours)", firstMinutes, lastMinutes, lastHours)
                widgetLogger.info("🔍 Departure range: \(firstMinutes) min to \(lastMinutes) min (\(lastHours) hours)")
            }
            
            for i in 0..<totalMinutes {
                let entryDate = now.addingTimeInterval(TimeInterval(i * intervalMinutes * 60))
                
                // SEAMLESS TRANSITION LOGIC:
                // Always show exactly 5 departures (or as many as available)
                // When a departure time passes, the next one immediately takes its place
                let futureDeparturesAtTime = allAvailableDepartures.filter { departure in
                    departure.nextDeparture > entryDate
                }
                
                // Always take exactly 5 departures (or all available if less than 5)
                let displayDepartures = Array(futureDeparturesAtTime.prefix(5))
                
                let entry = SimpleEntry(
                    date: entryDate, 
                    departure: displayDepartures.first, // First of the next departures
                    departures: displayDepartures, // Exactly 5 departures (or less if not available)
                    displayMode: displayMode,
                    stationName: stationName
                )
                entries.append(entry)
                
                // Log first few for debugging - show seamless transition
                if i < 5 {
                    NSLog("🔍 Seamless Entry %d at %@ shows %d departures", i, entryDate.description, displayDepartures.count)
                    if let firstDeparture = displayDepartures.first {
                        let timeUntilFirst = Int(firstDeparture.nextDeparture.timeIntervalSince(entryDate) / 60)
                        NSLog("🔍   First departure in %d min: %@", timeUntilFirst, firstDeparture.routeName)
                    }
                    if displayDepartures.count >= 3, let thirdDeparture = displayDepartures.dropFirst(2).first {
                        let timeUntilThird = Int(thirdDeparture.nextDeparture.timeIntervalSince(entryDate) / 60)
                        NSLog("🔍   Third departure in %d min: %@", timeUntilThird, thirdDeparture.routeName)
                    }
                    if displayDepartures.count >= 5, let fifthDeparture = displayDepartures.dropFirst(4).first {
                        let timeUntilFifth = Int(fifthDeparture.nextDeparture.timeIntervalSince(entryDate) / 60)
                        NSLog("🔍   Fifth departure in %d min: %@", timeUntilFifth, fifthDeparture.routeName)
                    }
                }
            }
            
            NSLog("🔍 Created dynamic multiple timeline with %d entries", entries.count)
            widgetLogger.info("🔍 Created dynamic multiple timeline with \(entries.count) entries")
        } else {
            NSLog("🔍 No departures found for multiple widget - creating empty timeline")
            widgetLogger.warning("🔍 No departures found for multiple widget - creating empty timeline")
            // Even without departures, create entries to keep widget responsive
            // Use 1-minute intervals for consistency with other timeline entries
            for i in 0..<60 { // 60 minutes of empty entries
                let entryDate = now.addingTimeInterval(TimeInterval(i * 60))
                let entry = SimpleEntry(
                    date: entryDate, 
                    departure: nil,
                    departures: [], // Empty departures array for multiple widgets
                    displayMode: displayMode,
                    stationName: stationName
                )
                entries.append(entry)
            }
        }
    }
}

// MARK: - iPhone Widget Views

struct SystemSmallView: View {
    let departure: DepartureInfo
    let isNearestStation: Bool
    let isFavoriteStation: Bool
    let departureTimeText: String
    
    var body: some View {
        VStack(spacing: 6) {
            // Header mit Icon
            HStack {
                if isNearestStation {
                    Image(systemName: "location.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                } else if isFavoriteStation {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Image(systemName: "ferry.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Invisible spacer for balance
                if isNearestStation || isFavoriteStation {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.clear)
                }
            }
            
            // Station Name
            Text(departure.stationName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Nächste Station
            Text("→ \(departure.direction)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // Abfahrtszeit
            VStack(spacing: 2) {
                 Text("Next Departure")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(departureTimeText)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .widgetBackground {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBlue).opacity(0.8),
                    Color(.systemBlue).opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct SystemMediumView: View {
    let departure: DepartureInfo
    let isNearestStation: Bool
    let isFavoriteStation: Bool
    let departureTimeText: String
    
    var body: some View {
        VStack(spacing: 4) {
            // Header mit Herz/Location in der rechten oberen Ecke
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "ferry.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("NextWave")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Herz/Location Icon in der rechten oberen Ecke
                if isNearestStation {
                    HStack(spacing: 4) {
                        Image(systemName: "location.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                } else if isFavoriteStation {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Station Name und nächste Station - kompakt zusammen
            VStack(alignment: .leading, spacing: 4) {
                Text(departure.stationName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Nächste Station - direkt unter Station Name
                HStack {
                    Text("→")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(departure.direction)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            Spacer()
            
            // Zeit - kompakt mit Next Departure oben
            VStack(alignment: .leading, spacing: 4) {
                Text(departureTimeText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical)
        .padding(.horizontal, 8)
        .widgetBackground {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBlue).opacity(0.8),
                    Color(.systemTeal).opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct SystemMediumMultipleView: View {
    let departures: [DepartureInfo]
    let isNearestStation: Bool
    let isFavoriteStation: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Header mit Station Name und Icon
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(departures.first?.stationName ?? "Station")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Herz/Location Icon in der rechten oberen Ecke
                if isNearestStation {
                    Image(systemName: "location.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                } else if isFavoriteStation {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            
            // Liste der nächsten 3 Abfahrten
            VStack(spacing: 6) {
                ForEach(Array(departures.enumerated()), id: \.offset) { index, departure in
                    HStack {
                        // Destination
                        HStack(spacing: 4) {
                            Text("→")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text(departure.direction)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        
                        Spacer()
                        
                        // Departure Time
                        Text(formatDepartureTime(departure.nextDeparture))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(index == 0 ? 0.2 : 0.1))
                    )
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .padding(.horizontal, 12)
        .widgetBackground {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBlue).opacity(0.8),
                    Color(.systemTeal).opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func formatDepartureTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SystemLargeMultipleView: View {
    let departures: [DepartureInfo]
    let isNearestStation: Bool
    let isFavoriteStation: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Header mit Station Name und Icon
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(departures.first?.stationName ?? "Station")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Next 5 Departures")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Herz/Location Icon in der rechten oberen Ecke
                if isNearestStation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "location.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                } else if isFavoriteStation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            
            Divider()
                .background(.white.opacity(0.3))
            
            // Liste der nächsten 5 Abfahrten - größer und schöner
            VStack(spacing: 2) {
                ForEach(Array(departures.enumerated()), id: \.offset) { index, departure in
                    HStack(spacing: 8) {
                        // Destination mit größerer Schrift
                        HStack(spacing: 4) {
                            Text("→")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text(departure.direction)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        
                        Spacer()
                        
                        // Departure Time - größer und prominenter
                        Text(formatDepartureTime(departure.nextDeparture))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(index == 0 ? 0.25 : 0.15))
                    )
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
        .widgetBackground {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBlue).opacity(0.9),
                    Color(.systemTeal).opacity(0.7),
                    Color(.systemBlue).opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func formatDepartureTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SystemLargeView: View {
    let departure: DepartureInfo
    let isNearestStation: Bool
    let isFavoriteStation: Bool
    let departureTimeText: String
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "ferry.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    VStack(alignment: .leading) {
                        Text("NextWave")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                if isNearestStation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "location.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                        Text("Nearest Station")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                } else if isFavoriteStation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            
            Divider()
                .background(.white.opacity(0.3))
            
            VStack(spacing: 12) {
                Text(departure.stationName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("→ \(departure.direction)")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("Next Departure")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                Text(departureTimeText)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .widgetBackground {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBlue).opacity(0.9),
                    Color(.systemTeal).opacity(0.7),
                    Color(.systemBlue).opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Empty State Views for iPhone Widgets

struct SystemSmallEmptyView: View {
    let message: String
    let subtitle: String
    
    init() {
        _ = SharedDataManager.shared.loadWidgetSettings()
        let favoriteStations = SharedDataManager.shared.loadFavoriteStations()
        
        if favoriteStations.isEmpty {
            self.message = "Add Favorites"
            self.subtitle = "in the app"
        } else {
            // Check when data was last refreshed
            let lastRefresh = UserDefaults(suiteName: "group.com.federi.Next-Wave")?.object(forKey: "last_data_refresh") as? Date
            let timeAgo = abs(lastRefresh?.timeIntervalSinceNow ?? 86400)
            
            if timeAgo < 3600 { // Less than 1 hour
                self.message = "Loading..."
                self.subtitle = "Tap to refresh"
            } else {
                self.message = "Open App"
                self.subtitle = "for schedules"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "ferry.fill")
                .font(.title)
                .foregroundColor(.white)
            
            Text("NextWave")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .widgetBackground {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBlue).opacity(0.7),
                    Color(.systemBlue).opacity(0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct SystemMediumEmptyView: View {
    let title: String
    let subtitle: String
    let iconName: String
    
    init() {
        let favoriteStations = SharedDataManager.shared.loadFavoriteStations()
        
        if favoriteStations.isEmpty {
            self.title = "No Favorites Set"
            self.subtitle = "Add favorite stations in the app to see departure times"
            self.iconName = "heart.slash"
        } else {
            // Check data freshness
            let lastRefresh = UserDefaults(suiteName: "group.com.federi.Next-Wave")?.object(forKey: "last_data_refresh") as? Date
            let timeAgo = abs(lastRefresh?.timeIntervalSinceNow ?? 86400)
            let hours = timeAgo / 3600
            
            if timeAgo < 1800 { // Less than 30 minutes
                self.title = "Loading Schedules..."
                self.subtitle = "Fetching departure times from your favorites"
                self.iconName = "clock.arrow.circlepath"
            } else if hours < 6 {
                self.title = "Open App to Refresh"
                self.subtitle = "Departure data is \(Int(hours))h old - tap to update"
                self.iconName = "arrow.clockwise.circle"
            } else {
                self.title = "Data Needs Update"
                self.subtitle = "Open NextWave app to load fresh departure times"
                self.iconName = "exclamationmark.circle"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "ferry.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("NextWave")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: iconName)
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .widgetBackground {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBlue).opacity(0.7),
                    Color(.systemIndigo).opacity(0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct SystemLargeEmptyView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let actionText: String
    
    init() {
        let favoriteStations = SharedDataManager.shared.loadFavoriteStations()
        
        if favoriteStations.isEmpty {
            self.title = "No Favorites Set"
            self.subtitle = "Add favorite ferry stations to see departure times and schedules"
            self.iconName = "heart.slash.circle"
            self.actionText = "Open NextWave app and tap the heart icon on stations you use frequently"
        } else {
            // Check data freshness for multiple departures widget
            let allDepartures = SharedDataManager.shared.loadNextDepartures()
            let lastRefresh = UserDefaults(suiteName: "group.com.federi.Next-Wave")?.object(forKey: "last_data_refresh") as? Date
            let timeAgo = abs(lastRefresh?.timeIntervalSinceNow ?? 86400)
            let hours = timeAgo / 3600
            let days = timeAgo / 86400
            
            if allDepartures.isEmpty {
                if timeAgo < 1800 { // Less than 30 minutes
                    self.title = "Loading Departure Times"
                    self.subtitle = "Fetching schedules for your \(favoriteStations.count) favorite stations"
                    self.iconName = "clock.arrow.circlepath"
                    self.actionText = "This may take a moment - departure data is being loaded in the background"
                } else if hours < 2 {
                    self.title = "Refresh Needed"
                    self.subtitle = "Departure data is about \(Int(hours)) hour\(hours >= 2 ? "s" : "") old"
                    self.iconName = "arrow.clockwise.circle"
                    self.actionText = "Open NextWave app to load fresh schedules and departure times"
                } else if days < 1 {
                    self.title = "Data from Today"
                    self.subtitle = "Schedules are \(Int(hours)) hours old and may be outdated"
                    self.iconName = "exclamationmark.circle"
                    self.actionText = "Open app to refresh and see current departure times"
                } else {
                    self.title = "Update Required"
                    self.subtitle = "Departure data is \(Int(days)) day\(days >= 2 ? "s" : "") old"
                    self.iconName = "wifi.exclamationmark"
                    self.actionText = "Open NextWave app to download fresh ferry schedules"
                }
            } else {
                self.title = "Schedules Available"
                self.subtitle = "Multiple departures view ready"
                self.iconName = "checkmark.circle"
                self.actionText = "Your favorite stations have current departure information"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "ferry.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    VStack(alignment: .leading) {
                        Text("NextWave")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Ferry Schedule")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                Spacer()
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text(actionText)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .widgetBackground {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBlue).opacity(0.7),
                    Color(.systemPurple).opacity(0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - iPhone Widget Entry View

struct iPhoneWidgetEntryView: View {
    var entry: iPhoneProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    private var isNearestStation: Bool {
        return entry.displayMode == .nearestStation
    }
    
    private var isFavoriteStation: Bool {
        return entry.displayMode == .firstFavorite
    }
    
    private var departureTimeText: String {
        guard let departure = entry.departure else { return "--:--" }
        
        let now = Date()
        
        // Check if departure is in the next few minutes (show "now" for immediate departures)
        let minutesUntil = Int(departure.nextDeparture.timeIntervalSince(now) / 60)
        if minutesUntil <= 0 {
            return "now"
        }
        
        // Always show "at HH:MM" regardless of day - simpler and clearer
        // This avoids issues with TMRW not updating after midnight
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "at \(formatter.string(from: departure.nextDeparture))"
    }

    var body: some View {
        if let departure = entry.departure {
            switch widgetFamily {
            case .systemSmall:
                SystemSmallView(departure: departure, isNearestStation: isNearestStation, isFavoriteStation: isFavoriteStation, departureTimeText: departureTimeText)
            case .systemMedium:
                SystemMediumView(departure: departure, isNearestStation: isNearestStation, isFavoriteStation: isFavoriteStation, departureTimeText: departureTimeText)
            case .systemLarge:
                SystemLargeView(departure: departure, isNearestStation: isNearestStation, isFavoriteStation: isFavoriteStation, departureTimeText: departureTimeText)
            case .systemExtraLarge:
                SystemLargeView(departure: departure, isNearestStation: isNearestStation, isFavoriteStation: isFavoriteStation, departureTimeText: departureTimeText)
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                // Not supported on iOS widgets - these are Watch-only
                Text("Watch Only")
                    .font(.caption)
                    .foregroundColor(.secondary)
            @unknown default:
                Text("Unsupported widget size")
                    .foregroundColor(.white)
            }
        } else {
            switch widgetFamily {
            case .systemSmall:
                SystemSmallEmptyView()
            case .systemMedium:
                SystemMediumEmptyView()
            case .systemLarge:
                SystemLargeEmptyView()
            case .systemExtraLarge:
                SystemLargeEmptyView()
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                // Not supported on iOS widgets - these are Watch-only
                Text("Watch Only")
                    .font(.caption)
                    .foregroundColor(.secondary)
            @unknown default:
                Text("No departure data")
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - iPhone Multiple Widget Entry View

struct iPhoneMultipleWidgetEntryView: View {
    var entry: iPhoneMultipleProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    private var isNearestStation: Bool {
        return entry.displayMode == .nearestStation
    }
    
    private var isFavoriteStation: Bool {
        return entry.displayMode == .firstFavorite
    }

    var body: some View {
        if !entry.departures.isEmpty {
            switch widgetFamily {
            case .systemMedium:
                // Show first 3 departures for medium widget
                let mediumDepartures = Array(entry.departures.prefix(3))
                SystemMediumMultipleView(departures: mediumDepartures, isNearestStation: isNearestStation, isFavoriteStation: isFavoriteStation)
            case .systemLarge:
                // Show all 5 departures for large widget
                SystemLargeMultipleView(departures: entry.departures, isNearestStation: isNearestStation, isFavoriteStation: isFavoriteStation)
            default:
                // Fallback to single departure view for other sizes
                if let departure = entry.departure {
                    let departureTimeText = formatDepartureTime(departure.nextDeparture)
                    switch widgetFamily {
                    case .systemSmall:
                        SystemSmallView(departure: departure, isNearestStation: isNearestStation, isFavoriteStation: isFavoriteStation, departureTimeText: departureTimeText)
                    default:
                        SystemMediumView(departure: departure, isNearestStation: isNearestStation, isFavoriteStation: isFavoriteStation, departureTimeText: departureTimeText)
                    }
                } else {
                    switch widgetFamily {
                    case .systemLarge:
                        SystemLargeEmptyView()
                    default:
                        SystemMediumEmptyView()
                    }
                }
            }
        } else {
            switch widgetFamily {
            case .systemLarge:
                SystemLargeEmptyView()
            default:
                SystemMediumEmptyView()
            }
        }
    }
    
    private func formatDepartureTime(_ date: Date) -> String {
        let now = Date()
        let minutesUntil = Int(date.timeIntervalSince(now) / 60)
        
        // Check if departure is in the next few minutes (show "now" for immediate departures)
        if minutesUntil <= 0 {
            return "now"
        }
        
        // Always show just the time - the smart logic already handles multi-day scenarios
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "at \(formatter.string(from: date))"
    }
}

// MARK: - iPhone Widget Bundle
// Note: Widgets are registered in NextWaveWidgetBundle.swift

// MARK: - iPhone Widget Definition

struct NextWaveiPhoneWidget: Widget {
    let kind: String = "NextWaveiPhoneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: iPhoneProvider()) { entry in
            iPhoneWidgetEntryView(entry: entry)
                .widgetURL(createDeepLink(for: entry.departure))
        }
        .configurationDisplayName("NextWave")
        .description("Shows your next boat departure on iPhone")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
        ])
    }
    
    private func createDeepLink(for departure: DepartureInfo?) -> URL? {
        guard let departure = departure else {
            return URL(string: "nextwave://")
        }
        
        // Create deep link with station name and date
        let stationName = departure.stationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Format date as YYYY-MM-DD for deep link
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: departure.nextDeparture)
        
        return URL(string: "nextwave://station?name=\(stationName)&date=\(dateString)")
    }
}

struct NextWaveiPhoneMultipleWidget: Widget {
    let kind: String = "NextWaveiPhoneMultipleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: iPhoneMultipleProvider()) { entry in
            iPhoneMultipleWidgetEntryView(entry: entry)
                .widgetURL(createDeepLink(for: entry.departure))
        }
        .configurationDisplayName("NextWave - Next 3")
        .description("Shows your next 3 boat departures")
        .supportedFamilies([
            .systemMedium,
            .systemLarge
        ])
    }
    
    private func createDeepLink(for departure: DepartureInfo?) -> URL? {
        guard let departure = departure else {
            return URL(string: "nextwave://")
        }
        
        // Create deep link with station name and date
        let stationName = departure.stationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Format date as YYYY-MM-DD for deep link
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: departure.nextDeparture)
        
        return URL(string: "nextwave://station?name=\(stationName)&date=\(dateString)")
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    NextWaveiPhoneWidget()
} timeline: {
    SimpleEntry(date: Date(), departure: DepartureInfo(
        stationName: "Brienz",
        nextDeparture: Date().addingTimeInterval(15 * 60),
        routeName: "BLS",
        direction: "Interlaken"
    ))
    SimpleEntry(date: Date(), departure: nil)
}

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    NextWaveiPhoneWidget()
} timeline: {
    SimpleEntry(date: Date(), departure: DepartureInfo(
        stationName: "Spiez",
        nextDeparture: Date().addingTimeInterval(5 * 60),
        routeName: "BLS",
        direction: "Thun"
    ))
}

@available(iOS 17.0, *)
#Preview(as: .systemLarge) {
    NextWaveiPhoneWidget()
} timeline: {
    SimpleEntry(date: Date(), departure: DepartureInfo(
        stationName: "Interlaken West",
        nextDeparture: Date().addingTimeInterval(25 * 60),
        routeName: "BLS",
        direction: "Bern"
    ))
}

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    NextWaveiPhoneMultipleWidget()
} timeline: {
    SimpleEntry(
        date: Date(), 
        departure: nil,
        departures: [
            DepartureInfo(stationName: "Küsnacht ZH (See)", nextDeparture: Date().addingTimeInterval(15 * 60), routeName: "S7", direction: "Küsnacht ZH Heslibach"),
            DepartureInfo(stationName: "Küsnacht ZH (See)", nextDeparture: Date().addingTimeInterval(35 * 60), routeName: "S7", direction: "Zürich Bürkliplatz (See)"),
            DepartureInfo(stationName: "Küsnacht ZH (See)", nextDeparture: Date().addingTimeInterval(55 * 60), routeName: "S7", direction: "Küsnacht ZH Heslibach")
        ],
        displayMode: .firstFavorite,
        stationName: "Küsnacht ZH (See)"
    )
}

@available(iOS 17.0, *)
#Preview(as: .systemLarge) {
    NextWaveiPhoneMultipleWidget()
} timeline: {
    SimpleEntry(
        date: Date(), 
        departure: nil,
        departures: [
            DepartureInfo(stationName: "Küsnacht ZH (See)", nextDeparture: Date().addingTimeInterval(8 * 60), routeName: "S7", direction: "Küsnacht ZH Heslibach"),
            DepartureInfo(stationName: "Küsnacht ZH (See)", nextDeparture: Date().addingTimeInterval(28 * 60), routeName: "S7", direction: "Zürich Bürkliplatz (See)"),
            DepartureInfo(stationName: "Küsnacht ZH (See)", nextDeparture: Date().addingTimeInterval(48 * 60), routeName: "S7", direction: "Küsnacht ZH Heslibach"),
            DepartureInfo(stationName: "Küsnacht ZH (See)", nextDeparture: Date().addingTimeInterval(68 * 60), routeName: "S7", direction: "Zürich Bürkliplatz (See)"),
            DepartureInfo(stationName: "Küsnacht ZH (See)", nextDeparture: Date().addingTimeInterval(88 * 60), routeName: "S7", direction: "Küsnacht ZH Heslibach")
        ],
        displayMode: .firstFavorite,
        stationName: "Küsnacht ZH (See)"
    )
}

#endif 