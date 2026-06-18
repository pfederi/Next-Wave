import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var store = StatsStore()

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Newly earned celebration
                if !store.newlyEarned.isEmpty {
                    VStack(spacing: 6) {
                        Text("🎉 New badge\(store.newlyEarned.count > 1 ? "s" : "")!")
                            .font(.headline)
                        Text(store.newlyEarned.map { $0.title }.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(12)
                }

                // MARK: Stats section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Stats")

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(store.stats?.totalWaves ?? 0)")
                            .font(.system(size: 44, weight: .bold))
                        Text("waves ridden")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }

                    NavigationLink(destination: LeaderboardView(stationId: nil, title: "Leaderboard")) {
                        HStack {
                            Label("Leaderboard", systemImage: "trophy")
                            Spacer()
                            if let me = store.leaderboard.first(where: { $0.isMe }) {
                                Text("You — #\(me.rank)").foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                // MARK: Badges section
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Badges")

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(badges) { item in
                            VStack(spacing: 20) {
                                BadgeMedalView(badge: item.badge, isEarned: item.isEarned, size: 120)
                                VStack(spacing: 3) {
                                    Text(item.badge.title)
                                        .font(.headline)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(item.isEarned ? .primary : .secondary)
                                    Text(item.badge.detail)
                                        .font(.subheadline)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("My Badges")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refresh(seenIds: appSettings.seenBadgeIds) { updated in
                appSettings.seenBadgeIds = updated
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var badges: [EvaluatedBadge] {
        BadgeEvaluator.evaluate(store.stats ?? .empty)
    }
}
