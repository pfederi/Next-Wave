//  ContentView.swift
//  NextWave
//
//  Created by Patrick Federi started at 12.12.2024.

import SwiftUI
import WidgetKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: LakeStationsViewModel
    @EnvironmentObject private var appSettings: AppSettings
    @ObservedObject private var favoritesManager = FavoriteStationsManager.shared
    @State private var showingLocationPicker = false
    @State private var showingInfoView = false
    @State private var showingWidgetSettings = false
    @State private var showingNavigationRules = false

    @State private var selectedDate = Date() {
        didSet {
            viewModel.selectedDate = selectedDate
            Task {
                await viewModel.refreshDepartures()
            }
        }
    }
    @State private var canGoBack = false
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    if !viewModel.lakes.isEmpty {
                        VStack(spacing: 0) {
                            if viewModel.selectedStation == nil {
                                VStack {
                                    Text("Ahoy Wakethief! 🏴‍☠️")
                                        .font(.title2)
                                        .foregroundColor(Color("text-color"))
                                        .padding(.top, 32)
                                    Text("Select a station to catch some waves!")
                                        .font(.body)
                                        .foregroundColor(Color("text-color"))
                                        .padding(.bottom, 16)
                                }
                            }
                            
                            if viewModel.selectedStation != nil {
                                DateSelectionView(
                                    selectedDate: $selectedDate,
                                    viewModel: viewModel
                                )
                            }
                            
                            StationButton(
                                stationName: viewModel.selectedStation?.name,
                                showPicker: $showingLocationPicker
                            )
                            
                            if viewModel.selectedStation != nil {
                                if viewModel.isLoading {
                                    LoaderView()
                                        .padding(.top, 32)
                                    Spacer()
                                } else {
                                    DeparturesListView(
                                        departures: viewModel.departures,
                                        selectedStation: viewModel.selectedStation,
                                        viewModel: viewModel,
                                        scheduleViewModel: scheduleViewModel
                                    )
                                    .padding(.top, 16)
                                }
                            } else {
                                ScrollView {
                                    VStack(spacing: 0) {
                                        // Nearest station
                                        if appSettings.showNearestStation,
                                           let nearest = viewModel.nearestStation {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Nearest Station")
                                                    .font(.headline)
                                                    .foregroundColor(Color("text-color"))
                                                    .padding(.horizontal)
                                                    .padding(.top, 32)
                                                
                                                NearestStationTileView(
                                                    station: nearest.station,
                                                    distance: nearest.distance,
                                                    onTap: {
                                                        viewModel.selectStation(withId: nearest.station.id)
                                                    },
                                                    viewModel: viewModel
                                                )
                                                .padding(.horizontal)
                                            }
                                        }
                                        
                                        // Favorite stations
                                        if !favoritesManager.favorites.isEmpty {
                                            FavoritesListView(viewModel: viewModel)
                                        }
                                        
                                        Spacer(minLength: 32)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("background-color"))
                .sheet(isPresented: $showingLocationPicker) {
                    LocationPickerView(viewModel: viewModel)
                }
                .sheet(isPresented: $showingNavigationRules) {
                    NavigationRulesModal(
                        isPresented: $showingNavigationRules,
                        isFirstLaunch: !UserDefaults.standard.bool(forKey: "hasShownNavigationRules")
                    )
                }
                .toolbar {
                    if viewModel.selectedStation != nil {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                viewModel.selectedStation = nil
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("NextWave")
                            .font(.headline)
                            .foregroundColor(Color("text-color"))
                    }
                    if viewModel.selectedStation == nil {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HStack(spacing: 16) {
                                Button(action: {
                                    showingNavigationRules = true
                                }) {
                                    Image(systemName: "exclamationmark.shield.fill")
                                        .foregroundColor(.orange)
                                        .padding(.leading, 8)
                                }
                                
                                NavigationLink(destination: SettingsView()) {
                                    Image(systemName: "gearshape")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }

                }
                .toolbarBackground(Color("nav-background"), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onReceive(viewModel.$selectedDate) { newDate in
            if selectedDate != newDate {
                selectedDate = newDate
            }
        }
        .onAppear {
            viewModel.setScheduleViewModel(scheduleViewModel)
            
            // Check if this is the first launch and show navigation rules
            let hasShownNavigationRules = UserDefaults.standard.bool(forKey: "hasShownNavigationRules")
            if !hasShownNavigationRules {
                // Small delay to ensure the view is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingNavigationRules = true
                }
            }
            
            // Load departure data for widgets when app starts
            Task {
                await loadDepartureDataForWidgets()
            }
            
            // Check if widget requested a refresh and handle it
            checkForWidgetRefreshRequests()
            
            // Load favorite stations in background when on home screen
            if viewModel.selectedStation == nil {
                viewModel.loadFavoriteStationsInBackground()
            }
        }
        .onChange(of: viewModel.selectedStation) { oldValue, newValue in
            // Cancel background loading if user selects a station
            if newValue != nil {
                viewModel.cancelBackgroundLoading()
            } else {
                // Resume background loading when returning to home screen
                viewModel.loadFavoriteStationsInBackground()
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EE"
        weekdayFormatter.locale = Locale(identifier: "en_US")
        let weekday = weekdayFormatter.string(from: selectedDate)
        
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        let date = formatter.string(from: selectedDate)
        
        return "\(weekday), \(date)"
    }
    
    // Check if widgets have requested a data refresh
    private func checkForWidgetRefreshRequests() {
        let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
        let widgetNeedsRefresh = userDefaults?.bool(forKey: "widget_needs_fresh_data") ?? false
        let lastWidgetRequest = userDefaults?.object(forKey: "widget_requested_refresh") as? Date
        
        if widgetNeedsRefresh {
            print("📱 Widget requested data refresh - loading fresh departure data")
            
            // Clear the flags first
            userDefaults?.set(false, forKey: "widget_needs_fresh_data")
            userDefaults?.removeObject(forKey: "widget_requested_refresh")
            
            // Load fresh data
            Task {
                await loadDepartureDataForWidgets()
            }
        } else if let requestTime = lastWidgetRequest {
            let timeSinceRequest = Date().timeIntervalSince(requestTime)
            
            // If request was made within the last 30 minutes, honor it
            if timeSinceRequest <= 30 * 60 {
                print("📱 Recent widget refresh request (\(Int(timeSinceRequest/60)) min ago) - loading fresh data")
                
                // Clear the flag
                userDefaults?.removeObject(forKey: "widget_requested_refresh")
                
                // Load fresh data
                Task {
                    await loadDepartureDataForWidgets()
                }
            }
        }
    }
    
    // Load real departure data for widgets (up to 25 departures per station for full day coverage)
    private func loadDepartureDataForWidgets() async {
        print("📱 Loading departure data for widgets (up to 25 departures per station for full day coverage)...")
        
        let favorites = favoritesManager.favorites
        var stationsToLoad = favorites
        
        // Add nearest station if widget is configured to use it and it's not already in favorites
        let widgetSettings = SharedDataManager.shared.loadWidgetSettings()
        if widgetSettings.useNearestStation,
           let nearestStation = SharedDataManager.shared.loadNearestStation(),
           !favorites.contains(where: { $0.name == nearestStation.name }) {
            
            let nearestFavorite = FavoriteStation(
                id: nearestStation.id,
                name: nearestStation.name,
                latitude: nearestStation.latitude,
                longitude: nearestStation.longitude,
                uic_ref: nearestStation.uic_ref
            )
            stationsToLoad.append(nearestFavorite)
            print("📱 Added nearest station '\(nearestStation.name)' to widget data loading")
        }
        
        var departureInfos: [DepartureInfo] = []
        
        for favorite in stationsToLoad {
            guard let uicRef = favorite.uic_ref else { continue }
            
            do {
                let today = Date()
                let now = today
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
                
                // Load today's journeys first (use higher limit for widgets to ensure enough data)
                let todayJourneys = try await TransportAPI().getStationboard(stationId: uicRef, for: today, limit: 50)
                print("📱 Total journeys from API for \(favorite.name) today: \(todayJourneys.count)")
                
                // Find today's future departures
                let todayFutureJourneys = todayJourneys.compactMap { journey -> (Journey, Date)? in
                    guard let departureStr = journey.stop.departure else { return nil }
                    guard let departureTime = AppDateFormatter.parseFullTime(departureStr) else { return nil }
                    guard departureTime > now else { return nil }
                    return (journey, departureTime)
                }
                .sorted { $0.1 < $1.1 } // Sort by departure time
                
                print("📱 Future departures today for \(favorite.name): \(todayFutureJourneys.count)")
                
                var allJourneys = Array(todayFutureJourneys)
                
                // Define constants at the top
                let maxDeparturesPerStation = 25 // Increased from 5 to support widget transitions
                let minDeparturesBeforeLoadingNextDay = 15 // Load tomorrow if less than 15 today
                
                // If less than desired departures today, also load tomorrow and possibly day after
                if todayFutureJourneys.count < minDeparturesBeforeLoadingNextDay {
                    print("📱 Loading tomorrow's departures for \(favorite.name) (only \(todayFutureJourneys.count) today, want \(minDeparturesBeforeLoadingNextDay)+)")
                    
                    do {
                        let tomorrowJourneys = try await TransportAPI().getStationboard(stationId: uicRef, for: tomorrow, limit: 50)
                        
                        let tomorrowFutureJourneys = tomorrowJourneys.compactMap { journey -> (Journey, Date)? in
                            guard let departureStr = journey.stop.departure else { return nil }
                            guard let departureTime = AppDateFormatter.parseFullTime(departureStr) else { return nil }
                            
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
                            
                            guard let tomorrowDepartureDate = calendar.date(from: fullComponents) else { return nil }
                            return (journey, tomorrowDepartureDate)
                        }
                        .sorted { $0.1 < $1.1 } // Sort by departure time
                        
                        allJourneys.append(contentsOf: tomorrowFutureJourneys)
                        print("📱 Added \(tomorrowFutureJourneys.count) departures from tomorrow for \(favorite.name)")
                        
                        // If we still don't have enough departures, load day after tomorrow
                        if allJourneys.count < maxDeparturesPerStation {
                            print("📱 Still need more departures for \(favorite.name) (\(allJourneys.count)/\(maxDeparturesPerStation)), loading day after tomorrow")
                            
                            do {
                                let dayAfterTomorrow = Calendar.current.date(byAdding: .day, value: 2, to: today) ?? tomorrow
                                let dayAfterJourneys = try await TransportAPI().getStationboard(stationId: uicRef, for: dayAfterTomorrow, limit: 50)
                                
                                let dayAfterFutureJourneys = dayAfterJourneys.compactMap { journey -> (Journey, Date)? in
                                    guard let departureStr = journey.stop.departure else { return nil }
                                    guard let departureTime = AppDateFormatter.parseFullTime(departureStr) else { return nil }
                                    
                                    // Adjust date to day after tomorrow
                                    let calendar = Calendar.current
                                    let dayAfterComponents = calendar.dateComponents([.year, .month, .day], from: dayAfterTomorrow)
                                    let timeComponents = calendar.dateComponents([.hour, .minute], from: departureTime)
                                    
                                    var fullComponents = DateComponents()
                                    fullComponents.year = dayAfterComponents.year
                                    fullComponents.month = dayAfterComponents.month
                                    fullComponents.day = dayAfterComponents.day
                                    fullComponents.hour = timeComponents.hour
                                    fullComponents.minute = timeComponents.minute
                                    
                                    guard let dayAfterDepartureDate = calendar.date(from: fullComponents) else { return nil }
                                    return (journey, dayAfterDepartureDate)
                                }
                                .sorted { $0.1 < $1.1 } // Sort by departure time
                                
                                allJourneys.append(contentsOf: dayAfterFutureJourneys)
                                print("📱 Added \(dayAfterFutureJourneys.count) departures from day after tomorrow for \(favorite.name)")
                            } catch {
                                print("📱 Error loading day after tomorrow's departures for \(favorite.name): \(error)")
                            }
                        }
                    } catch {
                        print("📱 Error loading tomorrow's departures for \(favorite.name): \(error)")
                    }
                }
                
                // Take many more departures for robust widget support (up to 25 per station for full day coverage)
                // This ensures widgets have enough data for seamless transitions throughout the day
                let nextJourneys = Array(allJourneys.prefix(maxDeparturesPerStation))
                print("📱 Total future departures for \(favorite.name): \(nextJourneys.count) (max: \(maxDeparturesPerStation))")
                
                for (journey, departureTime) in nextJourneys {
                    // Get next station from passList (like in the app)
                    let nextStation: String
                    if let passList = journey.passList,
                       passList.count > 1,
                       let nextStop = passList.dropFirst().first {
                        nextStation = nextStop.station.name ?? journey.to ?? "Unknown"
                    } else {
                        nextStation = journey.to ?? "Unknown"
                    }
                    
                    let departureInfo = DepartureInfo(
                        stationName: favorite.name,
                        nextDeparture: departureTime,
                        routeName: journey.name ?? "NextWave",
                        direction: nextStation
                    )
                    departureInfos.append(departureInfo)
                    print("📱 Loaded departure for \(favorite.name) → \(nextStation): \(departureTime)")
                }
                
                print("📱 Final: Loaded \(nextJourneys.count) departures for \(favorite.name) (from \(allJourneys.count) available across multiple days)")
            } catch {
                print("📱 Error loading journey details for \(favorite.name): \(error)")
            }
        }
        
        // Save departure data for widgets
        SharedDataManager.shared.saveNextDepartures(departureInfos)
        print("📱 Saved \(departureInfos.count) total departures for widgets")
        
        // Trigger widget reload
        WidgetCenter.shared.reloadAllTimelines()
    }

}

#Preview {
    ContentView()
}
