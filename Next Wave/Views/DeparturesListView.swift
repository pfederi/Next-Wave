import SwiftUI
import UserNotifications

struct DeparturesListView: View {
    let departures: [Journey]
    let selectedStation: Lake.Station?
    @ObservedObject var viewModel: LakeStationsViewModel
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @State private var scrollTrigger = UUID()
    @State private var isRefreshing = false
    
    let updateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private var isCurrentDay: Bool {
        Calendar.current.isDateInToday(viewModel.selectedDate)
    }
    
    var body: some View {
        if !departures.isEmpty {
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(scheduleViewModel.nextWaves.enumerated()), id: \.element.id) { index, wave in
                        DepartureRowView(
                            wave: wave,
                            index: index,
                            formattedTime: AppDateFormatter.formatTime(wave.time),
                            isPast: wave.time < Date(),
                            isCurrentDay: isCurrentDay,
                            scheduleViewModel: scheduleViewModel
                        )
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    guard !isRefreshing else { return }
                    isRefreshing = true
                    await viewModel.refreshDepartures()
                    scheduleViewModel.updateWaves(from: departures)
                    scrollTrigger = UUID()
                    isRefreshing = false
                }
                .onAppear {
                    scheduleViewModel.updateWaves(from: departures)
                    scrollTrigger = UUID()
                }
                .onChange(of: viewModel.selectedDate) { _, _ in
                    scheduleViewModel.updateWaves(from: departures)
                    scrollTrigger = UUID()
                }
                .onChange(of: scrollTrigger) { _, _ in
                    scrollToNextDeparture(proxy: proxy)
                }
            }
            .overlay {
                Color.clear
                    .onReceive(updateTimer) { _ in
                        guard !isRefreshing else { return }
                        scheduleViewModel.updateWaves(from: departures)
                    }
            }
        } else if viewModel.hasAttemptedLoad {
            VStack {
                Spacer()
                Text("No departures found for \(selectedStation?.name ?? "")")
                    .foregroundColor(Color("text-color"))
                    .multilineTextAlignment(.center)
                if !Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: Date()) {
                    Text("on \(formattedDate(viewModel.selectedDate))")
                        .foregroundColor(Color("text-color"))
                }
                Spacer()
            }
        }
    }
    
    private func scrollToNextDeparture(proxy: ScrollViewProxy) {
        if let nextWave = scheduleViewModel.nextWaves.first(where: { !($0.time < Date()) }) {
            withAnimation {
                proxy.scrollTo(nextWave.id, anchor: .top)
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
} 
