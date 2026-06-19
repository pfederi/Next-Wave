import SwiftUI

struct GPXImportSummaryView: View {
    let summary: GPXImportSummary
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(summary.outcome == .imported ? .green : .orange)
                .padding(.top, 24)

            Text(title).font(.title2.bold())

            if summary.outcome == .imported {
                VStack(spacing: 8) {
                    row("Wake-thieving rides", "\(summary.rideCount)")
                    row("Distance (behind ships)", String(format: "%.2f km", summary.totalDistanceM / 1000))
                    row("Longest ride", String(format: "%.0f m", summary.longestRideM))
                    row("Top speed", String(format: "%.1f km/h", summary.topSpeedKmh))
                }
                .padding(.horizontal)
            }
            if let m = summary.message {
                Text(m).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }

            Button("Done", action: onDone).font(.headline).padding(.top, 8)
            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
    }

    private var icon: String {
        switch summary.outcome {
        case .imported: return "checkmark.seal.fill"
        case .alreadyImported: return "tray.full"
        case .noWaves: return "ferry"
        case .notFoilmotion, .failed: return "exclamationmark.triangle"
        }
    }
    private var title: String {
        switch summary.outcome {
        case .imported: return "Session imported! 🏄"
        case .alreadyImported: return "Already imported"
        case .noWaves: return "No boat waves"
        case .notFoilmotion: return "Unsupported file"
        case .failed: return "Import failed"
        }
    }
    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundColor(.secondary); Spacer(); Text(value).fontWeight(.semibold) }
    }
}
