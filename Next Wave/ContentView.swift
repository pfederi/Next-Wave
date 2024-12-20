//
//  ContentView.swift
//  Next Wave
//
//  Created by Patrick Federi started at 12.12.2024.

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: LakeStationsViewModel
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
                                        .padding(.bottom, 32)
                                }
                            }
                            
                            HStack {
                                if canGoBack {
                                    Button(action: {
                                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                                        if Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
                                            canGoBack = false
                                        }
                                    }) {
                                        Image(systemName: "chevron.left")
                                            .foregroundColor(Color("text-color"))
                                    }
                                }
                                
                                HStack {
                                    Spacer()
                                    Text(formattedDate)
                                        .font(.title3)
                                        .foregroundColor(Color("text-color"))
                                    Spacer()
                                }
                                .frame(maxWidth: 200)
                                
                                Button(action: {
                                    if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate),
                                       let maxDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()),
                                       newDate <= maxDate {
                                        selectedDate = newDate
                                        canGoBack = true
                                    }
                                }) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color("text-color"))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            
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
                            }
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    if viewModel.selectedStation == nil {
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.bottom, 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("background-color"))
                .sheet(isPresented: $showingLocationPicker) {
                    LocationPickerView(viewModel: viewModel)
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Next Wave")
                            .font(.headline)
                            .foregroundColor(Color("text-color"))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                                .foregroundColor(Color("text-color"))
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
