import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var lakeVM: LakeStationsViewModel
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

                    NavigationLink(destination: MyStationsView(counts: store.stationCounts, nameFor: stationName)) {
                        HStack {
                            Label("My Stations", systemImage: "mappin.and.ellipse")
                            Spacer()
                            if !store.stationCounts.isEmpty {
                                Text("\(store.stationCounts.count)").foregroundColor(.secondary)
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

                // MARK: Earned badges
                if !earnedBadges.isEmpty {
                    badgeSection("Earned (\(earnedBadges.count))", earnedBadges)
                }

                // MARK: Locked badges
                if !lockedBadges.isEmpty {
                    badgeSection("Locked (\(lockedBadges.count))", lockedBadges)
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

    private func badgeSection(_ title: String, _ items: [EvaluatedBadge]) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            sectionHeader(title)
            LazyVGrid(columns: columns, spacing: 32) {
                ForEach(items) { item in
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

    private var badges: [EvaluatedBadge] {
        BadgeEvaluator.evaluate(store.stats ?? .empty)
    }

    private var earnedBadges: [EvaluatedBadge] { badges.filter { $0.isEarned } }
    private var lockedBadges: [EvaluatedBadge] { badges.filter { !$0.isEarned } }

    /// station_id (= "name_uicref" or "name") → human-readable station name.
    private func stationName(_ stationId: String) -> String {
        for lake in lakeVM.lakes {
            if let s = lake.stations.first(where: { $0.id == stationId }) { return s.name }
        }
        // Fallback: strip a trailing "_<uicref>" if present.
        if let r = stationId.range(of: "_", options: .backwards) {
            let suffix = stationId[r.upperBound...]
            if !suffix.isEmpty && suffix.allSatisfy({ $0.isNumber }) {
                return String(stationId[..<r.lowerBound])
            }
        }
        return stationId
    }
}
