import SwiftUI

struct WaveAnalyticsView: View {
    @ObservedObject var viewModel: WaveAnalyticsViewModel
    let spotId: String
    let spotName: String
    let allWaves: [WaveEvent]
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                if let analytics = viewModel.spotAnalytics.first(where: { $0.spotId == spotId }) {
                    if analytics.timeSlots.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("No Good Surf Sessions")
                                .font(.title2)
                                .padding(.bottom, 4)
                            
                            Text("Not enough waves in this time period for a good surf session. A good session needs at least 3 waves within a reasonable time frame.")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        )
                    } else {
                        Text("Best Surf Sessions")
                            .font(.title2)
                            .padding(.top, -12)
                        
                        Text("Wave Timeline")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        // Timeline Chart with all waves and recommended session highlighted
                        WaveTimelineChart(
                            waves: allWaves.sorted { $0.time < $1.time },
                            selectedSlot: analytics.timeSlots[0],
                            timeFormatter: timeFormatter
                        )
                        
                        Text("All waves for this spot, recommended session highlighted in yellow")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        Text("Recommended Session")
                            .font(.headline)
                            .padding(.top, 16)
                        
                        // Recommended session details
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("\(timeFormatter.string(from: analytics.timeSlots[0].startTime)) - \(timeFormatter.string(from: analytics.timeSlots[0].endTime))")
                                    .font(.title3)
                            }
                            
                            HStack {
                                Label {
                                    Text("\(analytics.timeSlots[0].waveCount) \(analytics.timeSlots[0].waveCount == 1 ? "wave" : "waves")")
                                } icon: {
                                    Image(systemName: "water.waves")
                                }
                                Text("•")
                                Text("\(Int(analytics.timeSlots[0].duration / 60))min session")
                            }
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        )
                        
                        if analytics.timeSlots.count > 1 {
                            Text("Alternative Sessions")
                                .font(.headline)
                                .padding(.top, 24)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(analytics.timeSlots.dropFirst()) { slot in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("\(timeFormatter.string(from: slot.startTime)) - \(timeFormatter.string(from: slot.endTime))")
                                                .font(.body)
                                            
                                            Spacer()
                                            
                                            Text("\(slot.waveCount) \(slot.waveCount == 1 ? "wave" : "waves")")
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text("\(Int(slot.duration / 60))min session")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemBackground))
                                    )
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
        }
    }
}

struct BestTimeSlotView: View {
    let slot: WaveTimeSlot
    let timeFormatter: DateFormatter
    
    private var durationInMinutes: Int {
        Int(slot.duration / 60)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended Session")
                .font(.headline)
            
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("\(timeFormatter.string(from: slot.startTime)) - \(timeFormatter.string(from: slot.endTime))")
                    .font(.title3)
            }
            
            HStack {
                Label {
                    Text("\(slot.waveCount) \(slot.waveCount == 1 ? "wave" : "waves")")
                } icon: {
                    Image(systemName: "water.waves")
                }
                Text("•")
                Text("\(durationInMinutes)min session")
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
    }
}

struct TimeSlotsList: View {
    let timeSlots: [WaveTimeSlot]
    let timeFormatter: DateFormatter
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(timeSlots) { slot in
                    HStack {
                        Text("\(timeFormatter.string(from: slot.startTime)) - \(timeFormatter.string(from: slot.endTime))")
                            .font(.system(.body, design: .monospaced))
                        
                        Spacer()
                        
                        Text("\(slot.waveCount) waves")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                    )
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
} 