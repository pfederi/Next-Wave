import Foundation
import CryptoKit

struct GPXImportSummary: Identifiable {
    let id = UUID()
    enum Outcome { case imported, alreadyImported, notFoilmotion, failed }
    let outcome: Outcome
    let totalDistanceM: Double
    let longestRideM: Double
    let topSpeedKmh: Double
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

    private func fail(_ outcome: GPXImportSummary.Outcome, _ message: String,
                      _ metrics: SessionMetrics? = nil) {
        summary = GPXImportSummary(
            outcome: outcome,
            totalDistanceM: metrics?.totalDistance ?? 0,
            longestRideM: metrics?.longestRideDistance ?? 0,
            topSpeedKmh: (metrics?.maxSpeed ?? 0) * 3.6,
            message: message)
    }

    func handleFile(_ url: URL) async {
        isBusy = true
        defer { isBusy = false }

        let session: GPXSession
        do {
            session = try await Task.detached { try GPXParser.parse(url: url) }.value
        } catch {
            fail(.failed, "Couldn't read the GPX file."); return
        }

        // Foilmotion authenticity gate.
        guard (session.metadata.creator ?? "").lowercased().contains("foilmotion") else {
            fail(.notFoilmotion, "Only Foilmotion GPX files are supported."); return
        }

        guard let metrics = SessionMetrics.compute(from: session.points) else {
            fail(.failed, "The track has too few points."); return
        }

        let key = Self.sessionKey(session)
        if (try? await VerifiedRidesAPI.shared.sessionExists(key: key)) == true {
            summary = GPXImportSummary(outcome: .alreadyImported, totalDistanceM: metrics.totalDistance,
                                       longestRideM: metrics.longestRideDistance,
                                       topSpeedKmh: metrics.maxSpeed * 3.6, message: "Already imported.")
            return
        }

        do {
            try await VerifiedRidesAPI.shared.upload(metrics: metrics, sessionKey: key)
        } catch {
            fail(.failed, "Couldn't upload — check your connection and try again.", metrics); return
        }

        summary = GPXImportSummary(outcome: .imported, totalDistanceM: metrics.totalDistance,
                                   longestRideM: metrics.longestRideDistance,
                                   topSpeedKmh: metrics.maxSpeed * 3.6, message: nil)
    }
}
