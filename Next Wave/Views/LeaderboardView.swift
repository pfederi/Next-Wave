import SwiftUI

struct LeaderboardView: View {
    let stationId: String?      // nil == global
    let title: String

    @StateObject private var store = StatsStore()

    var body: some View {
        List {
            if store.leaderboard.isEmpty && !store.loadFailed {
                Text("No rides recorded yet — be the first! 🌊")
                    .foregroundColor(.secondary)
            } else if store.loadFailed {
                Text("Couldn't load the leaderboard. Pull to retry.")
                    .foregroundColor(.red)
            }
            ForEach(store.leaderboard.sorted { $0.rank < $1.rank }) { entry in
                HStack {
                    Text("#\(entry.rank)")
                        .font(.headline.monospacedDigit())
                        .frame(width: 48, alignment: .leading)
                        .foregroundColor(.secondary)
                    Text(entry.displayName)
                        .fontWeight(entry.isMe ? .bold : .regular)
                    Spacer()
                    Label("\(entry.totalWaves)", systemImage: "water.waves")
                        .labelStyle(.titleAndIcon)
                }
                .listRowBackground(entry.isMe ? Color.accentColor.opacity(0.12) : nil)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.loadLeaderboard(stationId: stationId) }
        .task { await store.loadLeaderboard(stationId: stationId) }
    }
}
