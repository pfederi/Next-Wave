import SwiftUI

/// Per-user overview: at which stations the user has surfed how many waves.
struct MyStationsView: View {
    let counts: [StationWaveCount]
    /// Resolves a station_id to a human-readable station name.
    let nameFor: (String) -> String

    var body: some View {
        List {
            if counts.isEmpty {
                Text("No rides recorded yet — catch a wave! 🌊")
                    .foregroundColor(.secondary)
            }
            ForEach(counts) { item in
                HStack {
                    Text(nameFor(item.stationId))
                    Spacer()
                    Label("\(item.waves)", systemImage: "water.waves")
                        .labelStyle(.titleAndIcon)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("My Stations")
        .navigationBarTitleDisplayMode(.inline)
    }
}
