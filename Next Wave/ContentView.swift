//  ContentView.swift
//  Next Wave
//
//  Created by Patrick Federi started at 12.12.2024.

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: LakeStationsViewModel
    @StateObject private var favoritesManager = FavoriteStationsManager.shared
    @EnvironmentObject private var appSettings: AppSettings
    @State private var showingLocationPicker = false
    @State private var showingInfoView = false
    @State private var showingPirate = false
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
    
    init() {
        let scheduleVM = ScheduleViewModel()
        self._viewModel = StateObject(wrappedValue: LakeStationsViewModel(scheduleViewModel: scheduleVM))
    }
    
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
                                        .overlay {
                                            EasterEggView(isShowing: $showingPirate)
                                        }
                                    Text("Select a station to catch some waves!")
                                        .font(.body)
                                        .foregroundColor(Color("text-color"))
                                        .padding(.bottom, 16)
                                }
                            }
                            
                            DateSelectionView(
                                selectedDate: $selectedDate,
                                viewModel: viewModel
                            )
                            
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
                                                        viewModel.selectStation(nearest.station)
                                                    },
                                                    viewModel: viewModel
                                                )
                                                .padding(.horizontal)
                                            }
                                        }
                                        
                                        // Favorite stations
                                        if !favoritesManager.favorites.isEmpty {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Favorite Spots")
                                                    .font(.headline)
                                                    .foregroundColor(Color("text-color"))
                                                    .padding(.horizontal)
                                                    .padding(.top, 32)
                                                
                                                VStack(spacing: 8) {
                                                    ForEach(favoritesManager.favorites) { favorite in
                                                        FavoriteStationTileView(
                                                            station: favorite,
                                                            onTap: {
                                                                viewModel.selectStation(withId: favorite.id)
                                                            },
                                                            viewModel: viewModel
                                                        )
                                                        .padding(.horizontal)
                                                    }
                                                }
                                            }
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
                        Text("Next Wave")
                            .font(.headline)
                            .foregroundColor(Color("text-color"))
                    }
                    if viewModel.selectedStation == nil {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: SettingsView()) {
                                Image(systemName: "gearshape")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                .toolbarBackground(Color("nav-background"), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
            }
            
            EasterEggView(isShowing: $showingPirate, isOverlay: true)
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
}

#Preview {
    ContentView()
}
