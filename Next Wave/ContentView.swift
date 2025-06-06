//  ContentView.swift
//  NextWave
//
//  Created by Patrick Federi started at 12.12.2024.

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: LakeStationsViewModel
    @EnvironmentObject private var appSettings: AppSettings
    @ObservedObject private var favoritesManager = FavoriteStationsManager.shared
    @State private var showingLocationPicker = false
    @State private var showingInfoView = false

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
    
    init() {
        self._viewModel = StateObject(wrappedValue: LakeStationsViewModel())
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
        }
        .onReceive(viewModel.$selectedDate) { newDate in
            if selectedDate != newDate {
                selectedDate = newDate
            }
        }
        .onAppear {
            viewModel.setScheduleViewModel(scheduleViewModel)
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
