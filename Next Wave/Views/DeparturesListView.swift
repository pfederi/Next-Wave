import SwiftUI

struct DeparturesListView: View {
    let departures: [Journey]
    let selectedStation: Lake.Station?
    @ObservedObject var viewModel: LakeStationsViewModel
    
    var body: some View {
        VStack {
            
            if !departures.isEmpty {
                List {
                    ForEach(Array(departures.enumerated()), id: \.element.id) { index, journey in
                        if let departureTime = journey.stop.departure {
                            HStack(alignment: .firstTextBaseline) {
                                // Left side - Time
                                VStack(alignment: .center, spacing: 4) {
                                    Text(formatTime(departureTime))
                                        .font(.system(size: 24, weight: .bold))
                                    let formattedTime = formatTime(departureTime)
                                    if let date = parseTime(formattedTime) {
                                        let remainingTime = calculateRemainingTime(for: date)
                                        Text(remainingTime)
                                            .font(.caption)
                                            .foregroundColor(getTimeColor(remainingTime))
                                            .padding(.top, remainingTime == "missed" ? 6 : 0)
                                    }
                                }
                                .frame(width: 70)
                                
                                Spacer().frame(width: 16)
                                
                                // Middle section - Wave and Course number
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Image(systemName: "water.waves")
                                            .foregroundColor(.blue)
                                        Text("\(index + 1). Wave of the Day")
                                            .foregroundColor(.primary)
                                    }
                                    
                                    if let name = journey.name {
                                        Text("Course number: \(name.replacingOccurrences(of: "^0+", with: "", options: .regularExpression))")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.secondary.opacity(0.2))
                                            .cornerRadius(8)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    // TODO: Add notification action
                                } label: {
                                    Label("Notify", systemImage: "bell.fill")
                                }
                                .tint(.blue)
                            }
                            .onAppear {
                                viewModel.loadJourneyDetails(for: journey)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await viewModel.refreshDepartures()
                }
            } else if selectedStation != nil {
                Text("No departures available")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "HH:mm"
        
        if let date = inputFormatter.date(from: timeString) {
            return outputFormatter.string(from: date)
        }
        return timeString.prefix(5).description
    }
    
    private func parseTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        
        if let date = formatter.date(from: timeString) {
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return calendar.date(bySettingHour: components.hour ?? 0,
                               minute: components.minute ?? 0,
                               second: 0,
                               of: now)
        }
        return nil
    }
    
    private func calculateRemainingTime(for date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute], from: now, to: date)
        let minutes = components.minute ?? 0
        
        if minutes >= -5 && minutes <= 5 {
            return "now"
        }
        if minutes < -5 {
            return "missed"
        }
        if minutes > 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMinutes)min"
        }
        return "\(minutes)min"
    }

    private func getTimeColor(_ remainingTime: String) -> Color {
        switch remainingTime {
        case "now":
            return .green
        case "missed":
            return .red
        default:
            return .gray
        }
    }
} 