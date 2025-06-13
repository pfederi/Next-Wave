import SwiftUI
import WidgetKit
import Foundation

struct WidgetSettingsView: View {
    @State private var useNearestStation: Bool = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Widget Display Mode")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // First Favorite Option
                        HStack {
                            Button(action: {
                                useNearestStation = false
                                saveSettings()
                            }) {
                                HStack {
                                    Image(systemName: useNearestStation ? "circle" : "checkmark.circle.fill")
                                        .foregroundColor(useNearestStation ? .gray : .blue)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("First Favorite")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Shows your first favorite from the list")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        // Nearest Station Option
                        HStack {
                            Button(action: {
                                useNearestStation = true
                                saveSettings()
                            }) {
                                HStack {
                                    Image(systemName: useNearestStation ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(useNearestStation ? .blue : .gray)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Nearest Station")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Shows the nearest station based on your location")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "location.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(footer: Text("This setting determines which station is displayed in your widgets. Changes will be applied on the next widget update.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Widget Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        let settings = SharedDataManager.shared.loadWidgetSettings()
        useNearestStation = settings.useNearestStation
    }
    
    private func saveSettings() {
        SharedDataManager.shared.saveWidgetSettings(useNearestStation: useNearestStation)
        
        // Send to Watch via WatchConnectivity
        WatchConnectivityManager.shared.updateWidgetSettings(useNearestStation)
        
        // Load departure data for the new widget configuration
        Task {
            await loadDepartureDataForNewWidgetSettings()
            
                    // Small delay to ensure data is fully saved before widget reload
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Force widget reload with new data
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
                print("📱 WidgetSettingsView: Final widget reload triggered")
            }
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func loadDepartureDataForNewWidgetSettings() async {
        print("📱 Loading departure data for new widget settings...")
        
        let favorites = FavoriteStationsManager.shared.favorites
        var stationsToLoad: [FavoriteStation] = []
        
        if useNearestStation {
            // If switching to nearest station, make sure we have nearest station data
            if let nearestStation = SharedDataManager.shared.loadNearestStation() {
                stationsToLoad.append(nearestStation)
                print("📱 Loading data for nearest station: \(nearestStation.name)")
            } else {
                print("📱 No nearest station available, falling back to first favorite")
                if let firstFavorite = favorites.first {
                    stationsToLoad.append(firstFavorite)
                }
            }
        } else {
            // If switching to favorites, use first favorite
            if let firstFavorite = favorites.first {
                stationsToLoad.append(firstFavorite)
                print("📱 Loading data for first favorite: \(firstFavorite.name)")
            }
        }
        
        // Load departure data for selected stations
        var departureInfos: [DepartureInfo] = []
        
        for station in stationsToLoad {
            do {
                guard let uicRef = station.uic_ref else { 
                    print("📱 No UIC reference for station: \(station.name)")
                    continue 
                }
                
                let today = Date()
                let now = today
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
                
                // Load today's departures first
                let todayJourneys = try await TransportAPI().getStationboard(stationId: uicRef, for: today)
                
                // Convert today's journeys to DepartureInfo
                var todayDepartures: [DepartureInfo] = []
                for journey in todayJourneys {
                    guard let departureStr = journey.stop.departure else { continue }
                    guard let departureTime = AppDateFormatter.parseFullTime(departureStr) else { continue }
                    guard departureTime > now else { continue } // Only future departures
                    
                    // Create fullName like in Watch app
                    let routeName: String
                    if let category = journey.category, let number = journey.number {
                        routeName = "\(category)\(number)"
                    } else {
                        routeName = journey.name ?? "Unknown"
                    }
                    
                    // Create bestDirection like in Watch app
                    let direction: String
                    if let passList = journey.passList,
                       passList.count > 1,
                       let nextStation = passList.dropFirst().first {
                        direction = nextStation.station.name ?? "Unknown"
                    } else if let to = journey.to, !to.isEmpty {
                        direction = to
                    } else {
                        direction = journey.name ?? "Departure"
                    }
                    
                    todayDepartures.append(DepartureInfo(
                        stationName: station.name,
                        nextDeparture: departureTime,
                        routeName: routeName,
                        direction: direction
                    ))
                }
                
                print("📱 Found \(todayDepartures.count) future departures today for \(station.name)")
                
                // If less than 3 future departures today, also load tomorrow
                if todayDepartures.count < 3 {
                    print("📱 Loading tomorrow's departures for \(station.name) (only \(todayDepartures.count) today)")
                    
                    do {
                        let tomorrowJourneys = try await TransportAPI().getStationboard(stationId: uicRef, for: tomorrow)
                        
                        for journey in tomorrowJourneys {
                            guard let departureStr = journey.stop.departure else { continue }
                            guard let departureTime = AppDateFormatter.parseFullTime(departureStr) else { continue }
                            
                            // Adjust date to tomorrow
                            let calendar = Calendar.current
                            let tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: departureTime)
                            
                            var fullComponents = DateComponents()
                            fullComponents.year = tomorrowComponents.year
                            fullComponents.month = tomorrowComponents.month
                            fullComponents.day = tomorrowComponents.day
                            fullComponents.hour = timeComponents.hour
                            fullComponents.minute = timeComponents.minute
                            
                            guard let tomorrowDepartureDate = calendar.date(from: fullComponents) else { continue }
                            
                            // Create fullName like in Watch app
                            let routeName: String
                            if let category = journey.category, let number = journey.number {
                                routeName = "\(category)\(number)"
                            } else {
                                routeName = journey.name ?? "Unknown"
                            }
                            
                            // Create bestDirection like in Watch app
                            let direction: String
                            if let passList = journey.passList,
                               passList.count > 1,
                               let nextStation = passList.dropFirst().first {
                                direction = nextStation.station.name ?? "Unknown"
                            } else if let to = journey.to, !to.isEmpty {
                                direction = to
                            } else {
                                direction = journey.name ?? "Departure"
                            }
                            
                            todayDepartures.append(DepartureInfo(
                                stationName: station.name,
                                nextDeparture: tomorrowDepartureDate,
                                routeName: routeName,
                                direction: direction
                            ))
                        }
                        
                        print("📱 Added \(tomorrowJourneys.count) departures from tomorrow for \(station.name)")
                    } catch {
                        print("📱 Error loading tomorrow's departures for \(station.name): \(error)")
                    }
                }
                
                departureInfos.append(contentsOf: todayDepartures)
                print("📱 Total loaded \(todayDepartures.count) departures for \(station.name)")
            } catch {
                print("📱 Error loading departures for \(station.name): \(error)")
            }
        }
        
        // Save to SharedDataManager for widgets
        SharedDataManager.shared.saveNextDepartures(departureInfos)
        print("📱 Saved \(departureInfos.count) total departures for widgets")
        
        // Force widget update with new data
        WidgetCenter.shared.reloadAllTimelines()
        print("📱 Triggered widget update with new departure data")
    }
}

struct WidgetSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetSettingsView()
    }
} 