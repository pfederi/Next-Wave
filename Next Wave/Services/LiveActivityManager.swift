import Foundation
import ActivityKit

/// Owns the single "next wave" Live Activity. All ActivityKit side effects live here.
@available(iOS 16.2, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    static let window: TimeInterval = 8 * 3600

    private var currentActivity: Activity<WaveActivityAttributes>?
    private var currentWaveID: String?

    /// Start (or re-target) the activity for `wave` if it is the soonest in-window belled wave.
    func startOrRetarget(for wave: WaveEvent, station: Lake.Station?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        guard wave.time > now, wave.time <= now.addingTimeInterval(Self.window) else { return }

        // Keep the existing activity if it already tracks a sooner (or equal) wave.
        if currentActivity != nil, let trackedTime = trackedWaveTime, wave.time >= trackedTime {
            return
        }
        start(for: wave, station: station)
    }

    /// End the activity if it currently tracks `wave`.
    func end(for wave: WaveEvent) {
        guard currentWaveID == wave.id else { return }
        endCurrent()
    }

    /// Reconcile: end any stale activity and start one for the soonest in-window belled wave.
    func syncToSoonestBelledWave(among waves: [WaveEvent], station: Lake.Station?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let target = LiveActivitySelector.soonestInWindow(waves, now: Date(), window: Self.window)
        guard let target else { endCurrent(); return }
        if currentWaveID == target.id { return } // already tracking it
        start(for: target, station: station)
    }

    // MARK: - Private

    private var trackedWaveTime: Date? { currentActivity?.attributes.waveTime }

    private func start(for wave: WaveEvent, station: Lake.Station?) {
        endCurrent()

        let stationName = station?.name ?? ""
        var shipName: String? = nil
        var iconName: String? = nil
        if wave.isZurichsee, isWithinNext7Days(wave.time),
           let name = wave.shipName, name != "Unknown" {
            shipName = name
            iconName = WaveIcon.name(for: name)
        }

        let attributes = WaveActivityAttributes(
            stationName: stationName,
            destinationName: wave.neighborStopName,
            waveTime: wave.time,
            shipName: shipName,
            waveIconName: iconName,
            deepLinkURL: Self.deepLink(stationName: stationName, date: wave.time)
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: WaveActivityAttributes.ContentState(),
                               staleDate: wave.time.addingTimeInterval(120)),
                pushType: nil
            )
            currentActivity = activity
            currentWaveID = wave.id
        } catch {
            currentActivity = nil
            currentWaveID = nil
        }
    }

    private func endCurrent() {
        guard let activity = currentActivity else { currentWaveID = nil; return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        currentWaveID = nil
    }

    private func isWithinNext7Days(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: today)!
        let dateDay = calendar.startOfDay(for: date)
        return dateDay >= today && dateDay < sevenDaysFromNow
    }

#if DEBUG
    /// Starts a sample Live Activity with a fake wave ~11 minutes out, so the Lock Screen
    /// and Dynamic Island can be verified without a real upcoming departure.
    func debugStartSampleActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endCurrent()
        let waveTime = Date().addingTimeInterval(11 * 60)
        let ship = "MS Panta Rhei"
        let attributes = WaveActivityAttributes(
            stationName: "Thalwil",
            destinationName: "Zürich",
            waveTime: waveTime,
            shipName: ship,
            waveIconName: WaveIcon.name(for: ship),
            deepLinkURL: Self.deepLink(stationName: "Thalwil", date: waveTime)
        )
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: WaveActivityAttributes.ContentState(),
                               staleDate: waveTime.addingTimeInterval(120)),
                pushType: nil
            )
            currentActivity = activity
            currentWaveID = "debug-sample"
        } catch {
            currentActivity = nil
            currentWaveID = nil
        }
    }

    /// Ends any running Live Activity (used by the debug controls).
    func debugEndAll() {
        endCurrent()
    }
#endif

    static func deepLink(stationName: String, date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        var components = URLComponents()
        components.scheme = "nextwave"
        components.host = "station"
        components.queryItems = [
            URLQueryItem(name: "name", value: stationName),
            URLQueryItem(name: "date", value: dateString)
        ]
        return components.url ?? URL(string: "nextwave://station")!
    }
}
