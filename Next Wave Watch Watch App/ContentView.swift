//
//  ContentView.swift
//  Next Wave Watch Watch App
//
//  Created by Patrick Federi on 03.06.2025.
//

import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @EnvironmentObject var viewModel: WatchViewModel
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.black, Color(red: 0.05, green: 0.05, blue: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            List {
                if viewModel.isLoading && viewModel.departures.isEmpty {
                    ProgressView("Departures are loaded...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.cyan)
                }
                
                // Check if there are any favorite stations or nearest station
                let hasAnyFavorites = !viewModel.departuresByStation.isEmpty
                let hasNearestStation = viewModel.nearestStation != nil && viewModel.useNearestStationForWidget
                
                // Show nearest station section if enabled and available
                if hasNearestStation, let nearestStation = viewModel.nearestStation {
                    let nearestDepartures = viewModel.departuresByStation[nearestStation.name] ?? []
                    let now = Date()
                    let nextNearestDepartures = nearestDepartures
                        .filter { $0.nextDeparture > now }
                        .sorted(by: { $0.nextDeparture < $1.nextDeparture })
                        .prefix(3)
                    
                    if !nextNearestDepartures.isEmpty {
                        Section(header: 
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.green, .mint],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .font(.caption)
                                    
                                    Text("Nearest Station")
                                        .font(.caption)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.green, .mint],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                }
                                
                                Text(nearestStation.name)
                                    .font(.headline)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green, .mint],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                            .padding(.bottom, 4)
                        ) {
                            ForEach(Array(nextNearestDepartures.enumerated()), id: \.element.nextDeparture) { index, departure in
                                DepartureRow(departure: departure, isNext: index == 0)
                                    .listRowBackground(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.1, green: 0.2, blue: 0.1).opacity(0.6))
                                    )
                            }
                        }
                    } else if !viewModel.isLoading {
                        Section(header: 
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.green, .mint],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .font(.caption)
                                    
                                    Text("Nearest Station")
                                        .font(.caption)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.green, .mint],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                }
                                
                                Text(nearestStation.name)
                                    .font(.headline)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green, .mint],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                            .padding(.bottom, 4)
                        ) {
                            Text("No departures found for nearest station")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.1, green: 0.2, blue: 0.1).opacity(0.6))
                                )
                        }
                    }
                }
                
                if !hasAnyFavorites && !viewModel.isLoading && !hasNearestStation {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.largeTitle)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("No Favorites Set")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 8) {
                            Text("Add favorite stations in the iOS app")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("OR")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.bold)
                            
                            Text("Enable 'Use nearest station' in iOS app settings")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                
                ForEach(viewModel.stationOrder, id: \.self) { station in
                    if let stationDepartures = viewModel.departuresByStation[station] {
                        // Use refreshTrigger to ensure live filtering
                        let _ = viewModel.refreshTrigger
                        let now = Date()
                        let nextDepartures = stationDepartures
                            .filter { $0.nextDeparture > now } // Nur zukünftige Abfahrten
                            .sorted(by: { $0.nextDeparture < $1.nextDeparture })
                            .prefix(3) // Die nächsten 3
                        
                        if !nextDepartures.isEmpty {
                            Section(header: 
                                HStack {
                                    Image(systemName: "ferry.fill")
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.cyan, .blue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .font(.caption)
                                    
                                    Text(station)
                                        .font(.headline)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.white, .gray],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                }
                                .padding(.bottom, 4)
                            ) {
                                ForEach(Array(nextDepartures.enumerated()), id: \.element.nextDeparture) { index, departure in
                                    DepartureRow(departure: departure, isNext: index == 0)
                                        .listRowBackground(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(red: 0.1, green: 0.1, blue: 0.2).opacity(0.6))
                                        )
                                }
                            }
                        }
                    }
                }
                
                if viewModel.departures.isEmpty && !viewModel.isLoading && hasAnyFavorites && !hasNearestStation {
                    Text("No departures found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("NextWave")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.15), .black],
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .navigationBar
        )
        .refreshable {
            await viewModel.updateDepartures()
        }
        .onAppear {
            // Initialize WatchConnectivity Manager
            _ = WatchConnectivityManager.shared
            
            // Run App Group test
            SharedDataManager.shared.testAppGroupAccess()
        }
    }
}

struct DepartureRow: View {
    let departure: DepartureInfo
    let isNext: Bool
    @EnvironmentObject var viewModel: WatchViewModel
    
    private var minutesUntilDeparture: Int {
        // Use viewModel.refreshTrigger to force recalculation every 30 seconds
        let _ = viewModel.refreshTrigger
        let now = Date()
        let timeInterval = departure.nextDeparture.timeIntervalSince(now)
        return max(0, Int(timeInterval / 60))
    }
    
    private var isTomorrow: Bool {
        let calendar = Calendar.current
        let now = Date()
        return !calendar.isDate(departure.nextDeparture, inSameDayAs: now)
    }
    
    private var departureTimeText: String {
        if isTomorrow {
            return "tmrw " + AppDateFormatter.formatTime(departure.nextDeparture)
        } else {
            return AppDateFormatter.formatTime(departure.nextDeparture)
        }
    }
    
    private var minutesText: String {
        if isTomorrow {
            return "" // Keine Zeitanzeige für morgen
        } else if minutesUntilDeparture == 0 {
            return "now"
        } else if minutesUntilDeparture > 60 {
            let hours = minutesUntilDeparture / 60
            let remainingMinutes = minutesUntilDeparture % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)min"
            }
        } else {
            return "\(minutesUntilDeparture)min"
        }
    }
    
    private var timeColor: Color {
        if isNext {
            return .green
        } else if minutesUntilDeparture <= 5 {
            return .red
        } else if minutesUntilDeparture <= 15 {
            return .orange
        } else if isTomorrow {
            return .purple
        } else {
            return .cyan
        }
    }
    
    private var minutesColor: Color {
        if minutesUntilDeparture == 0 {
            return .green
        } else if minutesUntilDeparture <= 5 {
            return .red
        } else if minutesUntilDeparture <= 15 {
            return .orange
        } else if isTomorrow {
            return .purple
        } else {
            return .secondary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(departureTimeText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(timeColor)
                    .fontWeight(.bold)
                
                Spacer()
                
                if !minutesText.isEmpty {
                    Text(minutesText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(minutesColor)
                        .fontWeight(.bold)
                }
            }
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(departure.direction)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .background(
            isNext ? 
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.1))
                .animation(.easeInOut(duration: 0.3), value: isNext)
            : nil
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchViewModel())
}
