import Foundation
import SwiftUI
import Supabase

/// Extra gamification fields captured at check-in time.
struct CheckinContext {
    let stationId: String
    let lakeId: String
    let isFirstOfDay: Bool
    let isLastOfDay: Bool
}

@MainActor
final class CheckinStore: ObservableObject {
    static let shared = CheckinStore()

    @Published private(set) var counts: [String: WaveCheckinCount] = [:]
    @Published private(set) var mine: Set<String> = []

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var didSubscribe = false
    private var subscribedWaveIds: [String] = []

    private init() {}

    /// Load counts + my-state for the visible waves and ensure a Realtime subscription.
    func refresh(waveIds: [String]) async {
        subscribedWaveIds = waveIds
        await reloadCounts()
        do {
            mine = try await CheckinAPI.shared.myCheckins(waveIds: waveIds)
        } catch {
            print("⚠️ Checkin myCheckins failed: \(error)")
        }
        await ensureSubscribed()
    }

    private func reloadCounts() async {
        do {
            let fetched = try await CheckinAPI.shared.counts(for: subscribedWaveIds)
            var dict: [String: WaveCheckinCount] = [:]
            for item in fetched { dict[item.waveId] = item }
            counts = dict
        } catch {
            print("⚠️ Checkin counts failed: \(error)")
        }
    }

    /// Subscribe exactly once. The channel listens table-wide; on any change we
    /// reload counts for whatever waves are currently visible.
    private func ensureSubscribed() async {
        guard !didSubscribe else { return }
        didSubscribe = true

        // Ensure an (anonymous) session so Realtime is authorized before joining.
        _ = try? await SupabaseManager.shared.ensureSession()

        let client = SupabaseManager.shared.client
        let channel = client.channel("wave_checkins_live")
        // Register the postgres-change callback BEFORE subscribing.
        let changes = channel.postgresChange(AnyAction.self,
                                             schema: "public",
                                             table: "wave_checkins")
        realtimeChannel = channel
        do {
            try await channel.subscribeWithError()
        } catch {
            print("⚠️ Checkin realtime subscribe failed: \(error)")
            // Remove the cached channel so a later attempt starts from a fresh,
            // unsubscribed channel (channel(_:) is cached per topic).
            await client.removeChannel(channel)
            realtimeChannel = nil
            didSubscribe = false
            return
        }
        realtimeTask = Task { [weak self] in
            for await _ in changes {
                guard let self else { return }
                await self.reloadCounts()
            }
        }
    }

    func toggle(waveId: String, departureAt: Date, identity: CheckinIdentity, context: CheckinContext) async {
        do {
            if mine.contains(waveId) {
                try await CheckinAPI.shared.checkOut(waveId: waveId)
                mine.remove(waveId)
            } else {
                try await CheckinAPI.shared.checkIn(
                    waveId: waveId,
                    displayName: identity.displayName,
                    departureAt: departureAt,
                    context: context)
                mine.insert(waveId)
            }
            await reloadCounts()
        } catch {
            print("⚠️ Checkin toggle failed: \(error)")
        }
    }
}
