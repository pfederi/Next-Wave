import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var lakeVM: LakeStationsViewModel
    @StateObject private var store = StatsStore()

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    /// Unified grid item so verified and normal badges sit in the same Earned/Locked grids.
    private enum GridBadge: Identifiable {
        case normal(EvaluatedBadge)
        case verified(EvaluatedVerifiedBadge)

        var id: String {
            switch self {
            case .normal(let e): return "n_\(e.id)"
            case .verified(let v): return "v_\(v.id)"
            }
        }
        var isEarned: Bool {
            switch self {
            case .normal(let e): return e.isEarned
            case .verified(let v): return v.isEarned
            }
        }
        var title: String {
            switch self {
            case .normal(let e): return e.badge.title
            case .verified(let v): return v.badge.title
            }
        }
        var detail: String {
            switch self {
            case .normal(let e): return e.badge.detail
            case .verified(let v): return v.badge.detail
            }
        }
    }

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

                // Foilmotion attribution + verified figures (not a separate badge list).
                verifiedInfo

                // MARK: Earned badges (normal + verified, mixed)
                if !earnedItems.isEmpty {
                    badgeSection("Earned (\(earnedItems.count))", earnedItems)
                }

                // MARK: Locked badges (normal + verified, mixed)
                if !lockedItems.isEmpty {
                    badgeSection("Locked (\(lockedItems.count))", lockedItems)
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

    private var verifiedInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Verified rides").font(.headline)
                if UIImage(named: "foilmotion_logo") != nil {
                    Image("foilmotion_logo").resizable().scaledToFit().frame(height: 20)
                }
            }
            Text("Verified badges come from your Foilmotion sessions. Record a session in Foilmotion, then share the GPX file to Next Wave.")
                .font(.caption)
                .foregroundColor(.secondary)
            Link("Open Foilmotion →", destination: URL(string: "https://foilmotion.webchoice.ch/")!)
                .font(.caption.weight(.semibold))
            if store.verifiedStats.sessionCount > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    stat("\(store.verifiedStats.sessionCount)", "sessions")
                    stat(String(format: "%.0f km", store.verifiedStats.totalDistanceM / 1000), "total")
                    stat(String(format: "%.0f m", store.verifiedStats.longestRideM), "longest")
                    stat(String(format: "%.0f", store.verifiedStats.maxSpeedMs * 3.6), "km/h top")
                }
                .padding(.top, 4)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func medallion(_ item: GridBadge) -> some View {
        switch item {
        case .normal(let e):
            BadgeMedalView(badge: e.badge, isEarned: e.isEarned, size: 120)
        case .verified(let v):
            BadgeMedalView(imageName: v.badge.imageName, ringColor: v.badge.ringColor,
                           isEarned: v.isEarned, verified: true, size: 120)
        }
    }

    private func badgeSection(_ title: String, _ items: [GridBadge]) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            sectionHeader(title)
            LazyVGrid(columns: columns, spacing: 32) {
                ForEach(items) { item in
                    VStack(spacing: 20) {
                        medallion(item)
                        VStack(spacing: 3) {
                            Text(item.title)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(item.isEarned ? .primary : .secondary)
                            Text(item.detail)
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

    // Normal + verified badges merged, split only by earned state.
    private var allBadges: [GridBadge] {
        store.badges.map(GridBadge.normal) + store.verifiedBadges.map(GridBadge.verified)
    }
    private var earnedItems: [GridBadge] { allBadges.filter { $0.isEarned } }
    private var lockedItems: [GridBadge] { allBadges.filter { !$0.isEarned } }

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
