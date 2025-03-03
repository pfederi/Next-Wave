import SwiftUI

struct FavoriteStationTileView: View {
    let station: FavoriteStation
    let onTap: () -> Void
    @ObservedObject var viewModel: LakeStationsViewModel
    @State private var nextDeparture: Date?
    @State private var timer: Timer?
    @State private var errorMessage: String?
    @State private var noWavesMessage: String = NoWavesMessageService.shared.getMessage()
    @State private var noServiceMessage: String = NoWavesMessageService.shared.getNoServiceMessage()
    @State private var hasTomorrowDepartures: Bool = true
    @State private var isLoading: Bool = true
    
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
                    
                    if isLoading {
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(Color("text-color"))
                    } else if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    } else if let departure = nextDeparture {
                        if departure > Date() {
                            HStack(spacing: 4) {
                                Image(systemName: "water.waves")
                                    .foregroundColor(.blue)
                                Text("Next wave: \(timeFormatter.string(from: departure))")
                                    .foregroundColor(Color("text-color"))
                            }
                            .font(.subheadline)
                        } else {
                            Text(noWavesMessage)
                                .font(.subheadline)
                                .foregroundColor(Color("text-color"))
                        }
                    } else {
                        if hasTomorrowDepartures {
                            Text(noWavesMessage)
                                .font(.subheadline)
                                .foregroundColor(Color("text-color"))
                        } else {
                            Text(noServiceMessage)
                                .font(.subheadline)
                                .foregroundColor(Color("text-color"))
                        }
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
    
    @MainActor
    private func refreshDeparture() async {
        isLoading = true
        let departure = await viewModel.getNextDeparture(for: station.id)
        // Only update the nextDeparture if it's a future departure or nil
        if departure == nil || departure! > Date() {
            nextDeparture = departure
            
            // If no departures today, check if there are departures tomorrow
            if departure == nil {
                hasTomorrowDepartures = await viewModel.hasDeparturesTomorrow(for: station.id)
            }
        } else {
            // If the departure is in the past, mark as no more departures
            nextDeparture = nil
            // Check if there are departures tomorrow
            hasTomorrowDepartures = await viewModel.hasDeparturesTomorrow(for: station.id)
        }
        errorMessage = nil
        isLoading = false
    }
} 