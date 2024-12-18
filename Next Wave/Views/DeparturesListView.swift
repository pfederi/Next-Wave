import SwiftUI
import UserNotifications

struct DeparturesListView: View {
    let departures: [Journey]
    let selectedStation: Lake.Station?
    @ObservedObject var viewModel: LakeStationsViewModel
    @State private var scrolledToNext = false
    @State private var previousDeparturesCount = 0
    @State private var notifiedJourneys: Set<String> = []
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    var isCurrentDay: Bool {
        Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: Date())
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color("text-color"))
                    .padding()
                Text("Loading timetable...")
                    .foregroundColor(Color("text-color"))
                Spacer()
            } else if !departures.isEmpty {
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(departures.enumerated()), id: \.element.id) { index, journey in
                            if let departureTime = journey.stop.departure {
                                let formattedTime = formatTime(departureTime)
                                let isPast = isCurrentDay ? isPastDeparture(formattedTime) : false
                                
                                HStack(alignment: .firstTextBaseline) {
                                    // Left side - Time
                                    VStack(alignment: .center, spacing: 4) {
                                        Text(formattedTime)
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(isPast ? .gray : .primary)
                                        if isCurrentDay, let date = parseTime(formattedTime) {
                                            let remainingTime = calculateRemainingTime(for: date)
                                            Text(remainingTime)
                                                .font(.caption)
                                                .foregroundColor(getTimeColor(remainingTime))
                                                .padding(.top, 6)
                                        }
                                    }
                                    .frame(width: 70)
                                    
                                    Spacer().frame(width: 16)
                                    
                                    // Middle section - Wave and Course number
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .center) {
                                            Image(systemName: "water.waves")
                                                .foregroundColor(isPast ? .gray : .blue)
                                            Text("\(index + 1). Wave")
                                                .foregroundColor(isPast ? .gray : .primary)
                                            
                                            Spacer()
                                            
                                            if notifiedJourneys.contains(journey.id) {
                                                Image(systemName: "bell.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 16))
                                            }
                                        }
                                        
                                        HStack(spacing: 8) {
                                            if let name = journey.name {
                                                Text(name.replacingOccurrences(of: "^0+", with: "", options: .regularExpression))
                                                    .font(.caption)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.gray.opacity(0.1))
                                                    .cornerRadius(12)
                                            }
                                            
                                            if let passList = journey.passList,
                                               passList.count > 1,
                                               let nextStationName = passList[1].station.name {
                                                Text("→ \(nextStationName)")
                                                    .font(.caption)
                                                    .foregroundColor(isPast ? .gray : .primary)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .id(journey.id)
                                .opacity(isPast ? 0.6 : 1.0)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if !isPast {
                                        Button {
                                            if notifiedJourneys.contains(journey.id) {
                                                removeNotification(for: journey)
                                            } else {
                                                scheduleNotification(for: journey)
                                            }
                                        } label: {
                                            Label(notifiedJourneys.contains(journey.id) ? "Remove" : "Notify", 
                                                  systemImage: notifiedJourneys.contains(journey.id) ? "bell.slash" : "bell")
                                        }
                                        .tint(notifiedJourneys.contains(journey.id) ? .red : .blue)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await viewModel.refreshDepartures()
                    }
                    .onChange(of: previousDeparturesCount) { oldValue, newValue in
                        scrollToNextDeparture(proxy: proxy)
                    }
                    .onAppear {
                        if previousDeparturesCount != departures.count {
                            previousDeparturesCount = departures.count
                        }
                        scrollToNextDeparture(proxy: proxy)
                    }
                }
            } else if selectedStation != nil {
                Spacer()
                Text("No departures found for \(selectedStation?.name ?? "")")
                    .foregroundColor(Color("text-color"))
                    .multilineTextAlignment(.center)
                if !Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: Date()) {
                    Text("on \(formattedDate(viewModel.selectedDate))")
                        .foregroundColor(Color("text-color"))
                        .padding(.top, 4)
                }
                Spacer()
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private func scrollToNextDeparture(proxy: ScrollViewProxy) {
        if !scrolledToNext {
            if let nextDeparture = departures.first(where: { journey in
                if let departureTime = journey.stop.departure {
                    return !isPastDeparture(formatTime(departureTime))
                }
                return false
            }) {
                withAnimation {
                    proxy.scrollTo(nextDeparture.id, anchor: .top)
                }
            }
            scrolledToNext = true
        }
    }
    
    private func isPastDeparture(_ timeString: String) -> Bool {
        guard let date = parseTime(timeString) else { return false }
        return date < Date()
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
    
    private func scheduleNotification(for journey: Journey) {
        guard let departureTime = journey.stop.departure,
              let date = parseFullTime(departureTime) else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Wave is coming"
        if let nextStation = journey.passList?.first(where: { $0.station.name != selectedStation?.name })?.station.name {
            content.body = "Ship \(journey.name ?? "") to \(nextStation) at \(formatTime(departureTime))"
        }
        
        if let soundURL = Bundle.main.url(forResource: "boat-horn", withExtension: "wav") {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundURL.lastPathComponent))
        } else {
            content.sound = .default
        }
        
        let triggerDate = Calendar.current.date(byAdding: .minute, value: -5, to: date)!
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: journey.id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
        notifiedJourneys.insert(journey.id)
    }
    
    private func removeNotification(for journey: Journey) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [journey.id])
        notifiedJourneys.remove(journey.id)
    }
    
    private func parseFullTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        return formatter.date(from: timeString)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d. MMMM"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
} 