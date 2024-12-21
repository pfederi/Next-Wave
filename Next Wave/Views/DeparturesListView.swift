import SwiftUI
import UserNotifications

struct DeparturesListView: View {
    let departures: [Journey]
    let selectedStation: Lake.Station?
    @ObservedObject var viewModel: LakeStationsViewModel
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @State private var isRefreshing = false
    
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
                    if !isRefreshing {
                        isRefreshing = true
                        await viewModel.refreshDepartures()
                        scheduleViewModel.updateWaves(from: departures)
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        isRefreshing = false
                    }
                }
                .task {
                    scheduleViewModel.updateWaves(from: departures)
                    if let nextWave = scheduleViewModel.nextWaves.first(where: { !($0.time < Date()) }) {
                        proxy.scrollTo(nextWave.id, anchor: .top)
                    }
                }
                .onChange(of: viewModel.selectedDate) { oldDate, newDate in
                    scheduleViewModel.updateWaves(from: departures)
                }
                .onChange(of: scheduleViewModel.nextWaves) { oldWaves, newWaves in
                    if let nextWave = newWaves.first(where: { !($0.time < Date()) }) {
                        withAnimation {
                            proxy.scrollTo(nextWave.id, anchor: .top)
                        }
                    }
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
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
} 
