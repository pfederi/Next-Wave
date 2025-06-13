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
            
            // Use .after policy to ensure regular updates, but allow manual reloads
            let nextUpdate = Date().addingTimeInterval(300) // 5 minutes
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
        
        // Comprehensive debugging with NSLog and os_log
        let timestamp = Date()
        NSLog("🔍 iPhone Widget getTimeline called at %@", timestamp.description)
        widgetLogger.info("🔍 iPhone Widget getTimeline called at \(timestamp)")
        
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

        // Check if we have any departure data at all
        let allDepartures = SharedDataManager.shared.loadNextDepartures()
        NSLog("🔍 Total departures in cache: %d", allDepartures.count)
        widgetLogger.info("🔍 Total departures in cache: \(allDepartures.count)")
        
        if allDepartures.isEmpty && !favoriteStations.isEmpty {
            NSLog("🔍 No departure data found but have favorites - showing hint to open app")
            widgetLogger.info("🔍 No departure data found but have favorites - showing hint to open app")
            
            // Create a helpful hint departure to show that we have favorites but need app to load data
            let hintDeparture = DepartureInfo(
                stationName: favoriteStations[0].name,
                nextDeparture: Date().addingTimeInterval(900), // 15 minutes from now
                routeName: "Open App",
                direction: "to load departure times"
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
            
        } else if let nextDeparture = nextDeparture {
            NSLog("🔍 Creating timeline with departure for: %@", nextDeparture.stationName)
            widgetLogger.info("🔍 Creating timeline with departure for: \(nextDeparture.stationName)")
            
            // Get station name based on display mode
            let stationName: String?
            if settings.useNearestStation {
                stationName = SharedDataManager.shared.loadNearestStation()?.name
            } else {
                stationName = favoriteStations.first?.name
            }
            
            // Create entries every minute for the next hour
            for i in 0..<61 { // 61 entries = next 60 minutes
                let entryDate = now.addingTimeInterval(TimeInterval(i * 60))
                let entry = SimpleEntry(
                    date: entryDate, 
                    departure: nextDeparture,
                    displayMode: displayMode,
                    stationName: stationName
                )
                entries.append(entry)
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
            
            // Use .after policy to ensure regular updates, but allow manual reloads
            let nextUpdate = Date().addingTimeInterval(300) // 5 minutes
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
        
        NSLog("🔍 iPhone Multiple Widget getTimeline called at %@", now.description)
        widgetLogger.info("🔍 iPhone Multiple Widget getTimeline called at \(now)")
        
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
        
        // Get next departures (3 for medium, 5 for large)
        let nextDepartures = SharedDataManager.shared.getNext5DeparturesForWidget()
        NSLog("🔍 Display mode: %@, Found %d departures for multiple widget", displayMode.displayName, nextDepartures.count)
        widgetLogger.info("🔍 Display mode: \(displayMode.displayName), Found \(nextDepartures.count) departures for multiple widget")
        
        if !nextDepartures.isEmpty {
            NSLog("🔍 Creating timeline with %d departures for: %@", nextDepartures.count, nextDepartures[0].stationName)
            widgetLogger.info("🔍 Creating timeline with \(nextDepartures.count) departures for: \(nextDepartures[0].stationName)")
            
            // Create entries every 5 minutes for the next hour
            for i in 0..<13 { // 13 entries = next 60 minutes (every 5 minutes)
                let entryDate = now.addingTimeInterval(TimeInterval(i * 5 * 60))
                let entry = SimpleEntry(
                    date: entryDate, 
                    departure: nextDepartures.first,
                    departures: nextDepartures,
                    displayMode: displayMode,
                    stationName: stationName
                )
                entries.append(entry)
            }
        } else {
            NSLog("🔍 No departures found for multiple widget - creating empty timeline")
            widgetLogger.warning("🔍 No departures found for multiple widget - creating empty timeline")
            // Even without departures, create entries to keep widget responsive
            for i in 0..<13 {
                let entryDate = now.addingTimeInterval(TimeInterval(i * 5 * 60))
                let entry = SimpleEntry(
                    date: entryDate, 
                    departure: nil,
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
                Text("No Departures")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text("Add favorites")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .widgetBackground {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemGray).opacity(0.8),
                    Color(.systemGray2).opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct SystemMediumEmptyView: View {
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
                
                Text("No Favorites Set")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Add favorite stations in the app")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            Image(systemName: "heart.slash")
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .widgetBackground {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemGray).opacity(0.8),
                    Color(.systemGray2).opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct SystemLargeEmptyView: View {
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
                Image(systemName: "heart.slash.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("No Favorites Set")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Add favorite stations in the NextWave app to see departure times here")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .widgetBackground {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemGray).opacity(0.8),
                    Color(.systemGray2).opacity(0.6)
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
        let calendar = Calendar.current
        
        // Check if departure is in the next few minutes (show "now" for immediate departures)
        let minutesUntil = Int(departure.nextDeparture.timeIntervalSince(now) / 60)
        if minutesUntil <= 0 {
            return "now"
        }
        
        // Check if departure is tomorrow
        if !calendar.isDate(departure.nextDeparture, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "tmrw \(formatter.string(from: departure.nextDeparture))"
        }
        
        // Same day - show "at HH:MM"
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
        let calendar = Calendar.current
        
        // Check if departure is in the next few minutes (show "now" for immediate departures)
        let minutesUntil = Int(date.timeIntervalSince(now) / 60)
        if minutesUntil <= 0 {
            return "now"
        }
        
        // Check if departure is tomorrow
        if !calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "tmrw \(formatter.string(from: date))"
        }
        
        // Same day - show "at HH:MM"
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
        
        // Create deep link with station name
        let stationName = departure.stationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "nextwave://station?name=\(stationName)")
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
        
        // Create deep link with station name
        let stationName = departure.stationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "nextwave://station?name=\(stationName)")
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