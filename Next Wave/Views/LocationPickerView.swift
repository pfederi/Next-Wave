import SwiftUI

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LakeStationsViewModel
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
                            if newValue != nil {
                                dismiss()
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
    }
} 