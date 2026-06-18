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
                        let total = store.stats?.totalWaves ?? 0
                        Text("\(total)")
                            .font(.system(size: 44, weight: .bold))
                        Text(total == 1 ? "wave ridden" : "waves ridden")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }

                    NavigationLink(destination: LeaderboardView(stationId: nil, title: "Leaderboard")) {
                        HStack {
                            Label("Leaderboard", systemImage: "trophy")
                            Spacer()
                            if let me = store.leaderboard.first(where: { $0.isMe }) {
                                Text(me.totalWaves > 0 ? "You — #\(me.rank)" : "Not ranked yet")
                                    .foregroundColor(.secondary)
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

                // MARK: Verified badges
                if store.verifiedStats.sessionCount > 0 || store.verifiedBadges.contains(where: { $0.isEarned }) {
                    verifiedSection
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

    private var earnedVerified: [EvaluatedVerifiedBadge] { store.verifiedBadges.filter { $0.isEarned } }
    private var lockedVerified: [EvaluatedVerifiedBadge] { store.verifiedBadges.filter { !$0.isEarned } }

    private var verifiedSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) {
                sectionHeader("Verified")
                if UIImage(named: "foilmotion_logo") != nil {
                    Image("foilmotion_logo").resizable().scaledToFit().frame(height: 22)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Verified from your Foilmotion sessions. Record a session in Foilmotion, then share the GPX file to Next Wave.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Link("Open Foilmotion →", destination: URL(string: "https://foilmotion.webchoice.ch/")!)
                    .font(.caption.weight(.semibold))
            }
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                stat("\(store.verifiedStats.sessionCount)", "sessions")
                stat(String(format: "%.0f km", store.verifiedStats.totalDistanceM / 1000), "total")
                stat(String(format: "%.0f m", store.verifiedStats.longestRideM), "longest")
                stat(String(format: "%.0f", store.verifiedStats.maxSpeedMs * 3.6), "km/h top")
            }
            if !earnedVerified.isEmpty {
                verifiedSubsection("Earned (\(earnedVerified.count))", earnedVerified)
            }
            if !lockedVerified.isEmpty {
                verifiedSubsection("Locked (\(lockedVerified.count))", lockedVerified)
            }
        }
    }

    private func verifiedSubsection(_ title: String, _ items: [EvaluatedVerifiedBadge]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline).foregroundColor(.secondary)
            LazyVGrid(columns: columns, spacing: 32) {
                ForEach(items) { item in
                    VStack(spacing: 20) {
                        BadgeMedalView(imageName: item.badge.imageName, ringColor: item.badge.ringColor,
                                       isEarned: item.isEarned, verified: true, size: 120)
                        VStack(spacing: 3) {
                            Text(item.badge.title).font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(item.isEarned ? .primary : .secondary)
                            Text(item.badge.detail).font(.subheadline)
                                .multilineTextAlignment(.center).foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundColor(.secondary)
        }
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

    private var earnedBadges: [EvaluatedBadge] { store.badges.filter { $0.isEarned } }
    private var lockedBadges: [EvaluatedBadge] { store.badges.filter { !$0.isEarned } }

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
