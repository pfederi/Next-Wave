import SwiftUI

struct FavoriteStationTileView: View {
    let station: FavoriteStation
    let onTap: () -> Void
    @ObservedObject var viewModel: LakeStationsViewModel
    @State private var nextDeparture: Date?
    @State private var timer: Timer?
    @State private var errorMessage: String?
    @State private var noWavesMessage: String = Self.randomNoWavesMessage()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private static let noWavesMessages = [
        "No more waves today – back in the lineup tomorrow!",
        "Flat for now, but fresh sets rolling in tomorrow!",
        "Wave machine's off – catch the next swell tomorrow!",
        "Boat's are taking a break – tomorrow's a new ride!",
        "No wake waves left today – time to chill 'til sunrise!",
        "That's it for today – fresh waves incoming tomorrow!",
        "No waves, no worries – time to dry your wetsuit for tomorrow!",
        "The wave train's done for today – ride continues mañana!"
    ]
    
    private static func randomNoWavesMessage() -> String {
        noWavesMessages.randomElement() ?? noWavesMessages[0]
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.headline)
                        .foregroundColor(Color("text-color"))
                    
                    if let error = errorMessage {
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
                        Text(noWavesMessage)
                            .font(.subheadline)
                            .foregroundColor(Color("text-color"))
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
        let departure = await viewModel.getNextDeparture(for: station.id)
        // Only update the nextDeparture if it's a future departure or nil
        if departure == nil || departure! > Date() {
            nextDeparture = departure
        } else {
            // If the departure is in the past, mark as no more departures
            nextDeparture = nil
        }
        errorMessage = nil
    }
} 