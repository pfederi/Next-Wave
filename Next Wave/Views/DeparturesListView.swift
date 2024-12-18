import SwiftUI
import UserNotifications

struct DeparturesListView: View {
    let departures: [Journey]
    let selectedStation: Lake.Station?
    @ObservedObject var viewModel: LakeStationsViewModel
    @State private var previousDeparturesCount = 0
    @State private var notifiedJourneys: Set<String> = []
    @State private var currentTime = Date()
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    var isCurrentDay: Bool {
        Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: Date())
    }
    
    var body: some View {
        VStack {
            if selectedStation == nil {
                // No station selected, show nothing
            } else if viewModel.isLoading {
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
                                
                                DepartureRowView(
                                    journey: journey,
                                    index: index,
                                    formattedTime: formattedTime,
                                    isPast: isPast,
                                    isCurrentDay: isCurrentDay,
                                    notifiedJourneys: $notifiedJourneys,
                                    scheduleViewModel: scheduleViewModel
                                )
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
                        
                        // Lade den Benachrichtigungsstatus für alle Journeys
                        for journey in departures {
                            updateNotificationStatus(for: journey.id)
                        }
                    }
                }
            } else if viewModel.hasAttemptedLoad {
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
        .onChange(of: viewModel.selectedDate) { oldValue, newValue in
            notifiedJourneys.removeAll()
            viewModel.scrolledToNext = false  // Reset scroll state when date changes
            if Calendar.current.isDateInToday(newValue) {
                // Aktualisiere den Benachrichtigungsstatus nur für den aktuellen Tag
                for journey in departures {
                    updateNotificationStatus(for: journey.id)
                }
            }
        }
    }
    
    private func scrollToNextDeparture(proxy: ScrollViewProxy) {
        if !viewModel.scrolledToNext && isCurrentDay {
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
            viewModel.scrolledToNext = true
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
    
    private func parseFullTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        return formatter.date(from: timeString)
    }
    
    private func formattedDate(_ date: Date) -> String {
        return AppDateFormatter.formatDisplayDate(date)
    }
    
    private func updateNotificationStatus(for journeyId: String) {
        if let journey = departures.first(where: { $0.id == journeyId }),
           Calendar.current.isDateInToday(viewModel.selectedDate) {
            let stationId = journey.stop.station.id
            let notificationId = "\(stationId)_\(journeyId)"
            if scheduleViewModel.hasNotification(for: notificationId) {
                notifiedJourneys.insert(journeyId)
            } else {
                notifiedJourneys.remove(journeyId)
            }
        } else {
            notifiedJourneys.remove(journeyId)
        }
    }
} 