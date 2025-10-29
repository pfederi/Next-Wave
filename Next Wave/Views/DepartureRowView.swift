import SwiftUI

struct DepartureRowView: View {
    let wave: WaveEvent
    let index: Int
    let formattedTime: String
    let isPast: Bool
    let isCurrentDay: Bool
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var lakeStationsViewModel: LakeStationsViewModel
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .center, spacing: 12) {
                Text(formattedTime)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(isPast ? .gray : .primary)
                if isCurrentDay, let date = AppDateFormatter.parseTime(formattedTime) {
                    RemainingTimeView(targetDate: date)
                }
            }
            .frame(width: 70)
            
            Spacer().frame(width: 16)
            
            VStack(alignment: .leading, spacing: 8) {
                // Erste Zeile: Wave-Nummer, Notification und Wetter
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "water.waves")
                        .foregroundColor(isPast ? .gray : .blue)
                    Text("\(index + 1). Wave")
                        .foregroundColor(isPast ? .gray : .primary)
                    
                    Spacer()
                    
                    // Wetteranzeige
                    if !isPast && appSettings.showWeatherInfo {
                        if let weather = wave.weather {
                            HStack(spacing: 4) {
                                Image(systemName: weather.weatherIcon)
                                    .font(.system(size: 16))
                                
                                Text("|")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12))
                                
                                Text(String(format: "%.1f°", weather.temperature))
                                    .font(.system(size: 12))
                                    .foregroundColor(isPast ? .gray : .primary)
                                
                                // Wassertemperatur direkt nach Lufttemperatur
                                if let selectedStation = lakeStationsViewModel.selectedStation,
                                   let lake = lakeStationsViewModel.lakes.first(where: { lake in
                                       lake.stations.contains(where: { $0.name == selectedStation.name })
                                   }), let waterTemp = lake.waterTemperature {
                                    
                                    Text("|")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 12))
                                    
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(isPast ? .gray : .primary)
                                    
                                    Text(String(format: "%.0f°", waterTemp))
                                        .font(.system(size: 12))
                                        .foregroundColor(isPast ? .gray : .primary)
                                }
                                
                                Text("|")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12))
                                
                                Text("\(Int(weather.windSpeedKnots)) kn \(weather.windDirectionText)")
                                    .font(.system(size: 12))
                                    .foregroundColor(isPast ? .gray : .primary)
                            }
                        } else {
                            Text("Loading weather...")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if scheduleViewModel.hasNotification(for: wave) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                    }
                }
                
                // Zweite Zeile: Route, Schiff und Ziel
                HStack(alignment: .center, spacing: 8) {
                    // Route-Nummer
                    Text(wave.routeNumber)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    
                    if wave.isZurichsee && isWithinNext3Days(wave.time) {
                        // Schiffsname mit Icon (nur für die nächsten 3 Tage)
                        HStack(spacing: 4) {
                            Text(wave.shipName ?? "Loading...")
                                .lineLimit(1)
                            if let shipName = wave.shipName {
                                Image(getWaveIcon(for: shipName))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 12)
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    } else if wave.shipName != nil {
                        // Debug: Zeige warum kein Icon angezeigt wird
                        Text(wave.shipName ?? "")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            .onAppear {
                                print("⚠️ No icon for: \(wave.shipName ?? "nil") - isZurichsee: \(wave.isZurichsee), within3Days: \(isWithinNext3Days(wave.time))")
                            }
                    }
                    
                    Text("→")
                        .font(.caption)
                        .foregroundColor(isPast ? .gray : .primary)
                    
                    Text(wave.neighborStopName)
                        .font(.caption)
                        .foregroundColor(isPast ? .gray : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Spacer()
        }
        .id(wave.id)
        .opacity(isPast ? 0.6 : 1.0)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isPast && isCurrentDay {
                NotificationButton(wave: wave,
                                 scheduleViewModel: scheduleViewModel,
                                 isCurrentDay: isCurrentDay)
            }
        }
    }
}

private struct RemainingTimeView: View {
    let targetDate: Date
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        let timeInterval = targetDate.timeIntervalSince(currentTime)
        let minutes = Int(timeInterval) / 60
        let hours = abs(minutes) / 60
        let remainingMinutes = abs(minutes) % 60
        
        Text({
            if timeInterval <= -300 {
                return "missed"
            } else if timeInterval <= 300 {
                return "now"
            } else if hours > 0 {
                return "\(hours)h \(remainingMinutes)m"
            } else {
                return "\(minutes)m"
            }
        }())
        .font(.caption)
        .foregroundColor({
            if timeInterval <= -300 { 
                return .red
            } else if timeInterval <= 300 {
                return .green
            } else if hours == 0 && minutes <= 15 {
                return .red
            } else {
                return .primary
            }
        }())
        .onReceive(timer) { _ in
            withAnimation {
                currentTime = Date()
            }
        }
        .onAppear {
            currentTime = Date()
        }
    }
}

    private func isWithinNext3Days(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let threeDaysFromNow = calendar.date(byAdding: .day, value: 3, to: today)!
        let dateDay = calendar.startOfDay(for: date)
        
        return dateDay >= today && dateDay < threeDaysFromNow
    }
    
    private func getWaveIcon(for shipName: String) -> String {
        let cleanName = shipName.trimmingCharacters(in: .whitespaces)
        print("🚢 Checking wave icon for ship: '\(cleanName)'")
        switch cleanName {
        case "MS Panta Rhei", "MS Albis", "EMS Uetliberg", "EMS Pfannenstiel", "EM Uetliberg", "EM Pfannenstiel":
            print("✅ Matched 3 waves")
            return "waves3"
        case "MS Wädenswil", "MS Limmat", "MS Helvetia", "MS Linth", "DS Stadt Zürich", "DS Stadt Rapperswil":
            print("✅ Matched 2 waves")
            return "waves2"
        default:
            print("⚠️ Default 1 wave")
            return "waves1"
        }
    }

private struct NotificationButton: View {
    let wave: WaveEvent
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    let isCurrentDay: Bool
    
    var body: some View {
        Button {
            if scheduleViewModel.hasNotification(for: wave) {
                scheduleViewModel.removeNotification(for: wave)
            } else if isCurrentDay {
                scheduleViewModel.scheduleNotification(for: wave)
            }
        } label: {
            Label(scheduleViewModel.hasNotification(for: wave) ? "Remove" : "Notify",
                  systemImage: scheduleViewModel.hasNotification(for: wave) ? "bell.slash" : "bell")
        }
        .tint(scheduleViewModel.hasNotification(for: wave) ? .red : .blue)
        .disabled(!isCurrentDay && !scheduleViewModel.hasNotification(for: wave))
    }
} 