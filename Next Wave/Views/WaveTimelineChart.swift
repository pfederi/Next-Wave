import SwiftUI

struct WaveTimelineChart: View {
    let waves: [WaveEvent]
    let selectedSlot: WaveTimeSlot?
    let timeFormatter: DateFormatter
    @Environment(\.colorScheme) var colorScheme
    
    @State private var sunTimes: SunTimes?
    @State private var scrollOffset: CGFloat = 0
    
    private let chartHeight: CGFloat = 80
    private let hourWidth: CGFloat = 120
    
    private var twilightColor: Color {
        colorScheme == .dark ? Color.blue.opacity(0.3) : Color.blue.opacity(0.1)
    }
    
    private var chartRange: (start: Date, end: Date)? {
        guard let firstWave = waves.first?.time,
              let lastWave = waves.last?.time else {
            return nil
        }
        
        let calendar = Calendar.current
        
        // Get the sun times if available
        var endTime = lastWave
        if let sunTimes = sunTimes,
           sunTimes.civilTwilightEnd > lastWave {
            endTime = sunTimes.civilTwilightEnd
        }
        
        let startHour = calendar.component(.hour, from: firstWave)
        let endHour = calendar.component(.hour, from: endTime)
        
        guard let dayStart = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: firstWave),
              let dayEnd = calendar.date(bySettingHour: endHour + 1, minute: 0, second: 0, of: endTime) else {
            return nil
        }
        
        return (dayStart, dayEnd)
    }
    
    private var visibleHours: [Date] {
        guard let range = chartRange else { return [] }
        let calendar = Calendar.current
        
        let startHour = calendar.component(.hour, from: range.start)
        let endHour = calendar.component(.hour, from: range.end)
        
        var hours: [Date] = []
        for hour in startHour...endHour {
            if let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: range.start) {
                hours.append(hourDate)
            }
        }
        
        return hours
    }
    
    private func xPosition(for date: Date) -> CGFloat {
        guard let range = chartRange else { return 0 }
        let calendar = Calendar.current
        
        let startHour = calendar.component(.hour, from: range.start)
        let dateHour = calendar.component(.hour, from: date)
        let dateMinute = calendar.component(.minute, from: date)
        
        let hourDiff = dateHour - startHour
        let minutePercentage = CGFloat(dateMinute) / 60.0
        
        return (CGFloat(hourDiff) * hourWidth) + (minutePercentage * hourWidth)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if waves.isEmpty {
                Text("No waves available")
                    .foregroundColor(.secondary)
                    .frame(height: chartHeight)
                    .padding(.horizontal, 16)
            } else {
                ZStack(alignment: .topLeading) {
                    // Background
                    Color.clear
                        .frame(width: CGFloat(visibleHours.count) * hourWidth, height: chartHeight)
                    
                    // Night and Twilight zones
                    if let sunTimes = sunTimes, let range = chartRange {
                        // Night before morning twilight
                        if sunTimes.civilTwilightBegin >= range.start {
                            let nightWidth = xPosition(for: sunTimes.civilTwilightBegin)
                            Rectangle()
                                .fill(twilightColor)
                                .frame(width: nightWidth, height: chartHeight - 20)
                                .offset(x: 0, y: 10)
                        }
                        
                        // Morning twilight
                        if sunTimes.civilTwilightBegin >= range.start && sunTimes.civilTwilightBegin <= range.end {
                            let twilightWidth = xPosition(for: sunTimes.sunrise) - xPosition(for: sunTimes.civilTwilightBegin)
                            Rectangle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [
                                        twilightColor,
                                        twilightColor.opacity(0.0)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: max(0, twilightWidth), height: chartHeight - 20)
                                .offset(x: xPosition(for: sunTimes.civilTwilightBegin), y: 10)
                        }
                        
                        // Evening twilight
                        if sunTimes.civilTwilightEnd >= range.start && sunTimes.civilTwilightEnd <= range.end {
                            let twilightWidth = xPosition(for: sunTimes.civilTwilightEnd) - xPosition(for: sunTimes.sunset)
                            Rectangle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [
                                        twilightColor.opacity(0.0),
                                        twilightColor
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: max(0, twilightWidth), height: chartHeight - 20)
                                .offset(x: xPosition(for: sunTimes.sunset), y: 10)
                        }
                        
                        // Night after evening twilight
                        if sunTimes.civilTwilightEnd <= range.end {
                            let nightStartX = xPosition(for: sunTimes.civilTwilightEnd)
                            let totalWidth = CGFloat(visibleHours.count) * hourWidth
                            let nightWidth = totalWidth - nightStartX
                            Rectangle()
                                .fill(twilightColor)
                                .frame(width: max(0, nightWidth), height: chartHeight - 20)
                                .offset(x: nightStartX, y: 10)
                        }
                    }
                    
                    // Time axis with lines
                    ForEach(visibleHours, id: \.timeIntervalSince1970) { hour in
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 1)
                            Text(timeFormatter.string(from: hour))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: chartHeight)
                        .offset(x: xPosition(for: hour))
                    }
                    
                    // Selected session highlight
                    if let slot = selectedSlot {
                        let startX = xPosition(for: slot.startTime)
                        let endX = xPosition(for: slot.endTime)
                        let width = endX - startX
                        
                        Rectangle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: width, height: chartHeight - 20)
                            .offset(x: startX, y: 10)
                    }
                    
                    // Wave points and times
                    ForEach(Array(waves.enumerated()), id: \.element.id) { index, wave in
                        ZStack(alignment: .center) {
                            // Time label
                            if index.isMultiple(of: 2) {
                                Text(timeFormatter.string(from: wave.time))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .offset(y: -12)
                            } else {
                                Text(timeFormatter.string(from: wave.time))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .offset(y: 12)
                            }
                            
                            // Wave point
                            Circle()
                                .fill(isWaveInSelectedSlot(wave) ? Color.blue : Color.gray)
                                .frame(width: 8, height: 8)
                        }
                        .offset(x: xPosition(for: wave.time), y: 20)
                    }
                    
                    // Sun times
                    if let sunTimes = sunTimes {
                        // Sunrise
                        if let range = chartRange, sunTimes.sunrise >= range.start && sunTimes.sunrise <= range.end {
                            Image(systemName: "sunrise.fill")
                                .foregroundColor(.orange)
                                .offset(x: xPosition(for: sunTimes.sunrise) - 8, y: chartHeight - 33)
                        }
                        
                        // Sunset
                        if let range = chartRange, sunTimes.sunset >= range.start && sunTimes.sunset <= range.end {
                            Image(systemName: "sunset.fill")
                                .foregroundColor(.orange)
                                .offset(x: xPosition(for: sunTimes.sunset) - 8, y: chartHeight - 33)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .offset(x: -scrollOffset)
            }
        }
        .frame(height: chartHeight + 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .task {
            if let firstWave = waves.first {
                do {
                    sunTimes = try await SunTimeService.shared.getSunTimes(date: firstWave.time)
                } catch {
                    print("Error fetching sun times: \(error)")
                }
            }
            
            // Calculate initial scroll position
            if let range = chartRange {
                let now = Date()
                if now >= range.start && now <= range.end {
                    let offset = xPosition(for: now)
                    // Center the current time in the view
                    scrollOffset = max(0, offset - 120) // 120 is about one hour width
                }
            }
        }
    }
    
    private func isWaveInSelectedSlot(_ wave: WaveEvent) -> Bool {
        guard let slot = selectedSlot else { return false }
        return wave.time >= slot.startTime && wave.time <= slot.endTime
    }
} 