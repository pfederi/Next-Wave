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

        // Build candidate departures from stations near the track, then match.
        let departures = await candidateDepartures(for: session, stations: stations)
        let rides = WaveMatcher.matchedRides(points: session.points, departures: departures)
        guard let (metrics, rideCount) = Self.metrics(for: rides) else {
            report(.noWaves, message: "No ferry waves found in this session — only rides behind a ship count.")
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

    /// Stations within 400 m of any track point → that day's ferry departures.
    private func candidateDepartures(for session: GPXSession, stations: [Lake.Station]) async -> [CandidateDeparture] {
        let candidates = stations.filter { station in
            guard let c = station.coordinates else { return false }
            return session.points.contains {
                GeoMath.distance(lat1: $0.lat, lon1: $0.lon, lat2: c.latitude, lon2: c.longitude) <= 400
            }
        }
        let date = session.metadata.startTime ?? session.points.first?.time ?? Date()
        let api = TransportAPI()
        var departures: [CandidateDeparture] = []
        for station in candidates {
            guard let c = station.coordinates, let uic = station.uic_ref else { continue }
            let journeys = (try? await api.getStationboard(stationId: uic, for: date, limit: 200)) ?? []
            for j in journeys {
                guard let ts = j.stop.departureTimestamp else { continue }
                let route = (j.name ?? "").replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
                departures.append(CandidateDeparture(
                    stationId: station.id, stationName: station.name, stationUicRef: station.uic_ref,
                    stationLat: c.latitude, stationLon: c.longitude,
                    departure: Date(timeIntervalSince1970: TimeInterval(ts)), routeNumber: route))
            }
        }
        return departures
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
