import SwiftUI

struct FavoriteStationTileView: View {
    let station: FavoriteStation
    let onTap: () -> Void
    @ObservedObject var viewModel: LakeStationsViewModel
    @State private var nextDeparture: Date?
    @State private var timer: Timer?
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.headline)
                        .foregroundColor(Color("text-color"))
                    
                    if let departure = nextDeparture {
                        if departure > Date() {
                            HStack(spacing: 4) {
                                Image(systemName: "water.waves")
                                    .foregroundColor(.blue)
                                Text("Next wave: \(timeFormatter.string(from: departure))")
                                    .foregroundColor(Color("text-color"))
                            }
                            .font(.subheadline)
                        } else {
                            Text("No more waves today")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await refreshDeparture()
            // Start timer for periodic updates
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                Task {
                    await refreshDeparture()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func refreshDeparture() async {
        nextDeparture = await viewModel.getNextDeparture(for: station.id)
        
        // If the next departure is in the past, refresh to get the new next departure
        if let departure = nextDeparture, departure <= Date() {
            nextDeparture = await viewModel.getNextDeparture(for: station.id)
        }
    }
} 