import SwiftUI
import CoreLocation

struct NearestStationTileView: View {
    let station: Lake.Station
    let distance: Double
    let onTap: () -> Void
    @ObservedObject var viewModel: LakeStationsViewModel
    @State private var nextDeparture: Date?
    @State private var timer: Timer?
    @State private var noWavesMessage: String = NoWavesMessageService.shared.getMessage()
    @State private var noServiceMessage: String = NoWavesMessageService.shared.getNoServiceMessage()
    @State private var hasTomorrowDepartures: Bool = true
    @State private var isLoading: Bool = true
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let distanceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        Text(station.name)
                            .font(.headline)
                            .foregroundColor(Color("text-color"))
                        Text("(\(distanceFormatter.string(from: NSNumber(value: distance)) ?? "0.0") km)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if isLoading {
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(Color("text-color"))
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
        nextDeparture = await viewModel.getNextDeparture(for: station.id)
        
        // If the next departure is in the past or nil, check if there are departures tomorrow
        if nextDeparture == nil || nextDeparture! <= Date() {
            hasTomorrowDepartures = await viewModel.hasDeparturesTomorrow(for: station.id)
            
            // If the next departure is in the past, refresh to get the new next departure
            if let departure = nextDeparture, departure <= Date() {
                nextDeparture = await viewModel.getNextDeparture(for: station.id)
            }
        }
        isLoading = false
    }
} 