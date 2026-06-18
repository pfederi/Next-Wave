import Foundation
import CryptoKit

struct GPXImportSummary: Identifiable {
    let id = UUID()
    enum Outcome { case imported, alreadyImported, notFoilmotion, noWaves, failed }
    let outcome: Outcome
    let totalDistanceM: Double
    let longestRideM: Double
    let topSpeedKmh: Double
    let rideCount: Int
    let message: String?
}

@MainActor
final class GPXImportCoordinator: ObservableObject {
    static let shared = GPXImportCoordinator()
    private init() {}

    @Published var summary: GPXImportSummary?
    @Published var isBusy = false

    private static func sessionKey(_ session: GPXSession) -> String {
        let creator = session.metadata.creator ?? "?"
        let start = session.metadata.startTime?.timeIntervalSince1970
            ?? session.points.first?.time.timeIntervalSince1970 ?? 0
        let raw = "\(creator)|\(Int(start))|\(session.points.count)"
        return SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func report(_ outcome: GPXImportSummary.Outcome, message: String? = nil,
                        metrics: SessionMetrics? = nil, rideCount: Int = 0) {
        summary = GPXImportSummary(
            outcome: outcome,
            totalDistanceM: metrics?.totalDistance ?? 0,
            longestRideM: metrics?.longestRideDistance ?? 0,
            topSpeedKmh: (metrics?.maxSpeed ?? 0) * 3.6,
            rideCount: rideCount,
            message: message)
    }

    func handleFile(_ url: URL, stations: [Lake.Station]) async {
        isBusy = true
        defer { isBusy = false }

        let session: GPXSession
        do {
            session = try await Task.detached { try GPXParser.parse(url: url) }.value
        } catch {
            report(.failed, message: "Couldn't read the GPX file."); return
        }

        guard (session.metadata.creator ?? "").lowercased().contains("foilmotion") else {
            report(.notFoilmotion, message: "Only Foilmotion GPX files are supported."); return
        }
        guard session.points.count >= 2 else {
            report(.failed, message: "The track has too few points."); return
        }

        let key = Self.sessionKey(session)
        if (try? await VerifiedRidesAPI.shared.sessionExists(key: key)) == true {
            report(.alreadyImported, message: "Already imported."); return
        }

        // Reconstruct nearby scheduled-boat (Kursschiff) trajectories, then match.
        let trajectories = await ferryTrajectories(for: session, stations: stations)
        let rides = WaveMatcher.matchedRides(points: session.points, trajectories: trajectories)
        guard let (metrics, rideCount) = Self.metrics(for: rides) else {
            report(.noWaves, message: "No scheduled-boat waves found in this session — only rides behind a boat count.")
            return
        }

        do {
            try await VerifiedRidesAPI.shared.upload(metrics: metrics, sessionKey: key)
        } catch {
            report(.failed, message: "Couldn't upload — check your connection and try again.",
                   metrics: metrics, rideCount: rideCount)
            return
        }

        report(.imported, metrics: metrics, rideCount: rideCount)
    }

    /// Reconstruct the trajectories of scheduled boats whose route passes near the
    /// track: for every station within 400 m of any track point, fetch that day's
    /// departures and turn each boat journey into a time-stamped path (the journey's
    /// `passList` covers all its downstream legs, so a single trajectory captures the
    /// boat approaching and leaving every stop along its route).
    private func ferryTrajectories(for session: GPXSession, stations: [Lake.Station]) async -> [FerryTrajectory] {
        let candidates = stations.filter { station in
            guard let c = station.coordinates else { return false }
            return session.points.contains {
                GeoMath.distance(lat1: $0.lat, lon1: $0.lon, lat2: c.latitude, lon2: c.longitude) <= 400
            }
        }
        let date = session.metadata.startTime ?? session.points.first?.time ?? Date()
        let api = TransportAPI()
        var trajectories: [FerryTrajectory] = []
        var seen = Set<String>()   // dedupe journeys seen from several stations
        for station in candidates {
            guard let uic = station.uic_ref else { continue }
            let journeys = (try? await api.getStationboard(stationId: uic, for: date, limit: 200)) ?? []
            for j in journeys {
                guard let traj = Self.trajectory(from: j) else { continue }
                let key = "\(traj.routeNumber)_\(Int(traj.waypoints.first?.t ?? 0))"
                if seen.insert(key).inserted { trajectories.append(traj) }
            }
        }
        return trajectories
    }

    /// Build a time-ordered trajectory from a boat journey's origin stop + passList.
    /// (The first passList entry repeats the origin without coordinates, so the origin
    /// comes from `j.stop`.) Returns nil if fewer than two usable waypoints.
    static func trajectory(from j: Journey) -> FerryTrajectory? {
        var pts: [FerryWaypoint] = []
        if let c = j.stop.station.coordinate, let x = c.x, let y = c.y,
           let ts = j.stop.departureTimestamp ?? j.stop.arrivalTimestamp {
            pts.append(FerryWaypoint(lat: x, lon: y, t: TimeInterval(ts)))
        }
        for s in j.passList ?? [] {
            guard let c = s.station.coordinate, let x = c.x, let y = c.y,
                  let ts = s.arrivalTimestamp ?? s.departureTimestamp else { continue }
            pts.append(FerryWaypoint(lat: x, lon: y, t: TimeInterval(ts)))
        }
        pts.sort { $0.t < $1.t }
        var clean: [FerryWaypoint] = []
        for w in pts where clean.last.map({ w.t > $0.t }) ?? true { clean.append(w) }
        guard clean.count >= 2 else { return nil }
        let route = (j.name ?? "").replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        return FerryTrajectory(routeNumber: route, waypoints: clean)
    }

    /// Aggregate session metrics over ONLY the matched (behind-a-ship) rides.
    /// Returns the metrics plus the count of rides that actually contributed,
    /// or nil when no matched ride produced metrics.
    private static func metrics(for rides: [MatchedRide]) -> (SessionMetrics, Int)? {
        let perRide = rides.compactMap { SessionMetrics.compute(from: $0.points) }
        guard !perRide.isEmpty else { return nil }

        let total = perRide.map(\.totalDistance).reduce(0, +)
        let longest = perRide.map(\.totalDistance).max() ?? 0
        let maxSpeed = perRide.map(\.maxSpeed).max() ?? 0
        let moving = perRide.map(\.movingTime).reduce(0, +)
        let starts = perRide.map(\.start)
        let ends = perRide.map(\.end)
        let start = starts.min() ?? Date()
        let end = ends.max() ?? start
        let duration = perRide.map { $0.end.timeIntervalSince($0.start) }.reduce(0, +)

        let metrics = SessionMetrics(start: start, end: end, duration: duration, movingTime: moving,
                                     totalDistance: total, maxSpeed: maxSpeed, longestRideDistance: longest)
        return (metrics, perRide.count)
    }
}
