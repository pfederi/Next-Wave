import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var store = StatsStore()

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero: total waves
                VStack(spacing: 4) {
                    Text("\(store.stats?.totalWaves ?? 0)")
                        .font(.system(size: 56, weight: .bold))
                    Text("waves ridden")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

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
                    .padding(.horizontal)
                }

                // Own rank + link to full leaderboard
                NavigationLink(destination: LeaderboardView(stationId: nil, title: "Leaderboard")) {
                    HStack {
                        Label("Leaderboard", systemImage: "trophy")
                        Spacer()
                        if let me = store.leaderboard.first(where: { $0.isMe }) {
                            Text("You — #\(me.rank)").foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right").foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)

                // Badge gallery — medallion with title + subtitle
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(badges) { item in
                        VStack(spacing: 14) {
                            BadgeMedalView(badge: item.badge, isEarned: item.isEarned, size: 120)
                            VStack(spacing: 2) {
                                Text(item.badge.title)
                                    .font(.caption.weight(.semibold))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(item.isEarned ? .primary : .secondary)
                                Text(item.badge.detail)
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("My Badges")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refresh(seenIds: appSettings.seenBadgeIds) { updated in
                appSettings.seenBadgeIds = updated
            }
        }
    }

    private var badges: [EvaluatedBadge] {
        BadgeEvaluator.evaluate(store.stats ?? .empty)
    }
}
