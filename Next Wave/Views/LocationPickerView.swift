import SwiftUI

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LakeStationsViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var showMap = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("View Mode", selection: $showMap) {
                    Text("List").tag(false)
                    Text("Map").tag(true)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if showMap {
                    MapView(viewModel: viewModel)
                        .ignoresSafeArea(edges: .bottom)
                        .onChange(of: viewModel.selectedStation) { oldValue, newValue in
                            if let station = newValue {
                                if let lake = viewModel.lakes.first(where: { lake in
                                    lake.stations.contains(where: { $0.id == station.id })
                                }) {
                                    viewModel.expandedLakeId = lake.id
                                }
                                dismiss()
                            }
                        }
                        .onAppear {
                            if let station = viewModel.selectedStation,
                               let lake = viewModel.lakes.first(where: { lake in
                                   lake.stations.contains(where: { $0.id == station.id })
                               }) {
                                viewModel.expandedLakeId = lake.id
                            }
                        }
                } else {
                    List {
                        ForEach(viewModel.lakes) { lake in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { viewModel.expandedLakeId == lake.id },
                                    set: { isExpanded in
                                        viewModel.expandedLakeId = isExpanded ? lake.id : nil
                                    }
                                )
                            ) {
                                ForEach(lake.stations) { station in
                                    Button(action: {
                                        viewModel.selectStation(station)
                                        if let coordinates = station.coordinates {
                                            settings.lastMapRegion = MapRegion(
                                                latitude: coordinates.latitude,
                                                longitude: coordinates.longitude,
                                                latitudeDelta: 0.1,
                                                longitudeDelta: 0.1
                                            )
                                        }
                                        dismiss()
                                    }) {
                                        HStack {
                                            Text(station.name)
                                            Spacer()
                                            if viewModel.selectedStation?.id == station.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    .foregroundColor(.primary)
                                }
                            } label: {
                                Text(lake.name)
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            showMap = settings.lastLocationPickerMode == .map
            
            if viewModel.selectedStation == nil {
                settings.lastMapRegion = MapRegion(
                    latitude: 46.8182,
                    longitude: 8.2275,
                    latitudeDelta: 3.0,
                    longitudeDelta: 3.0
                )
            }
            else if let station = viewModel.selectedStation,
                    let lake = viewModel.lakes.first(where: { lake in
                        lake.stations.contains(where: { $0.id == station.id })
                    }) {
                viewModel.expandedLakeId = lake.id
            }
        }
        .onChange(of: showMap) { oldValue, newValue in
            settings.lastLocationPickerMode = newValue ? .map : .list
        }
    }
} 