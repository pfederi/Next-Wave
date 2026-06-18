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

#if DEBUG
#Preview {
    NavigationStack {
        MyStationsView(
            counts: [
                StationWaveCount(stationId: "Thalwil_8503001", waves: 12),
                StationWaveCount(stationId: "Küsnacht ZH (See)_8503657", waves: 7),
                StationWaveCount(stationId: "Zürich Bürkliplatz_8503591", waves: 3)
            ],
            nameFor: { id in String(id.split(separator: "_").first ?? Substring(id)) }
        )
    }
}
#endif
