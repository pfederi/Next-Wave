//
//  ContentView.swift
//  Next Wave
//
//  Created by Patrick Federi on 12.12.2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LakeStationsViewModel()
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    
                    // Center content with fixed width
                    HStack {
                        Spacer()
                        Text(formattedDate)
                            .font(.title3)
                            .foregroundColor(Color("text-color"))
                        Spacer()
                    }
                    .frame(maxWidth: 200)  // Kleinerer Wert für kompakteres Layout
                    
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
                
                if !viewModel.lakes.isEmpty {
                    StationButton(
                        stationName: viewModel.selectedStation?.name,
                        showPicker: $showingLocationPicker
                    )
                    
                    if viewModel.selectedStation == nil {
                        Text("Ahoy Wakethief! 🏴‍☠️")
                            .font(.title2)
                            .foregroundColor(Color("text-color"))
                            .padding(.top, 32)
                        Text("Select a spot to catch some waves!")
                            .font(.body)
                            .foregroundColor(Color("text-color"))
                            .padding(.top, 8)
                        Text("Keep your distance and don't foil\ndirectly behind the boat.")
                            .font(.body)
                            .foregroundColor(Color("text-color"))
                            .padding(.top, 8)
                            .multilineTextAlignment(.center)
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
                    NavigationLink(destination: InfoView()) {
                        Image(systemName: "info.circle")
                            .foregroundColor(Color("text-color"))
                    }
                }
            }
            .toolbarBackground(Color("nav-background"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .background(Color("background-color"))
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        
        // First get weekday abbreviation
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EE"
        weekdayFormatter.locale = Locale(identifier: "en_US")
        let weekday = weekdayFormatter.string(from: selectedDate)
        
        // Then get the date
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        let date = formatter.string(from: selectedDate)
        
        return "\(weekday), \(date)"
    }
}

#Preview {
    ContentView()
}
