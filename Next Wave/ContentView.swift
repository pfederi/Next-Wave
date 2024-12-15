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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(formattedDate)
                    .font(.title3)
                    .foregroundColor(.black)
                    .padding(.vertical, 8)
                
                if !viewModel.lakes.isEmpty {
                    StationButton(
                        stationName: viewModel.selectedStation?.name,
                        showPicker: $showingLocationPicker
                    )
                    
                    DeparturesListView(
                        departures: viewModel.departures,
                        selectedStation: viewModel.selectedStation,
                        viewModel: viewModel
                    )
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(viewModel: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Next Wave")
                        .font(.headline)
                }
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: Date())
    }
}

#Preview {
    ContentView()
}
