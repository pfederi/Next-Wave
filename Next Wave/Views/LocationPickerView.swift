import SwiftUI

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LakeStationsViewModel
    
    var body: some View {
        NavigationView {
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