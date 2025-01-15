import SwiftUI
import UserNotifications

struct DeparturesListView: View {
    let departures: [Journey]
    let selectedStation: Lake.Station?
    @ObservedObject var viewModel: LakeStationsViewModel
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @State private var errorMessage: String?
    
    private var isCurrentDay: Bool {
        Calendar.current.isDateInToday(viewModel.selectedDate)
    }
    
    var body: some View {
        if viewModel.isLoading {
            LoaderView()
        } else if let error = viewModel.error {
            VStack {
                Spacer()
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
        } else if !departures.isEmpty {
            ScrollViewReader { proxy in
                List {
                    if !scheduleViewModel.nextWaves.isEmpty {
                        ForEach(scheduleViewModel.nextWaves) { wave in
                            DepartureRowView(
                                wave: wave,
                                index: scheduleViewModel.nextWaves.firstIndex(of: wave) ?? 0,
                                formattedTime: AppDateFormatter.formatTime(wave.time),
                                isPast: wave.time < Date(),
                                isCurrentDay: isCurrentDay,
                                scheduleViewModel: scheduleViewModel
                            )
                            .id(wave.id)
                        }
                    }
                }
                .listStyle(.plain)
                .onAppear {
                    scheduleViewModel.updateWaves(from: departures)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToNextWave(proxy: proxy)
                    }
                }
                .onChange(of: viewModel.selectedDate) { oldDate, newDate in
                    scheduleViewModel.updateWaves(from: departures)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToNextWave(proxy: proxy)
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
    
    private func scrollToNextWave(proxy: ScrollViewProxy) {
        let now = Date()
        if let currentOrNextWave = scheduleViewModel.nextWaves.first(where: { wave in
            let timeDifference = wave.time.timeIntervalSince(now)
            return timeDifference >= -300 // Within 5 minutes in the past or any future departure
        }) {
            withAnimation {
                proxy.scrollTo(currentOrNextWave.id, anchor: .top)
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
