import SwiftUI
import UserNotifications

struct DeparturesListView: View {
    let departures: [Journey]
    let selectedStation: Lake.Station?
    @ObservedObject var viewModel: LakeStationsViewModel
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @StateObject private var analyticsViewModel = WaveAnalyticsViewModel()
    @State private var showingAnalytics = false
    @State private var errorMessage: String?
    @ObservedObject private var favoritesManager = FavoriteStationsManager.shared
    @State private var showingMaxFavoritesAlert = false
    @State private var noServiceMessage: String = NoWavesMessageService.shared.getNoServiceMessage()
    @State private var hasTomorrowDepartures: Bool = true
    
    private var isCurrentDay: Bool {
        Calendar.current.isDateInToday(viewModel.selectedDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showingAnalytics {
                WaveAnalyticsView(
                    viewModel: analyticsViewModel,
                    spotId: selectedStation?.id ?? "",
                    spotName: selectedStation?.name ?? "",
                    allWaves: scheduleViewModel.nextWaves
                )
            } else {
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
                    VStack(spacing: 0) {
                        // Fixed filter indicator at the top
                        if scheduleViewModel.albisClassFilterActive {
                            HStack {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Albis-Class Filter Active")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("🚢")
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.1))
                        }
                        
                        // Scrollable list
                        ScrollViewReader { proxy in
                            List {
                                if !scheduleViewModel.nextWaves.isEmpty {
                                    let filteredWaves = scheduleViewModel.getFilteredWaves()
                                    ForEach(filteredWaves) { wave in
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
                                if let station = viewModel.selectedStation {
                                    scheduleViewModel.updateWaves(from: departures, station: station)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    scrollToNextWave(proxy: proxy)
                                }
                            }
                            .onChange(of: viewModel.selectedDate) { oldDate, newDate in
                                if let station = viewModel.selectedStation {
                                    scheduleViewModel.updateWaves(from: departures, station: station)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    scrollToNextWave(proxy: proxy)
                                }
                            }
                        }
                    }
                } else if viewModel.hasAttemptedLoad {
                    VStack {
                        Spacer()
                        Text(noServiceMessage)
                            .foregroundColor(Color("text-color"))
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .task {
                        if let station = selectedStation {
                            hasTomorrowDepartures = await viewModel.hasDeparturesTomorrow(for: station.id)
                        }
                    }
                }
            }
            
            // Fixed footer with schedule information
            if let station = selectedStation {
                ScheduleFooterView(stationName: station.name)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if let station = selectedStation {
                        Button(action: {
                            if favoritesManager.isFavorite(station) {
                                favoritesManager.removeFavorite(station)
                            } else if favoritesManager.favorites.count >= FavoriteStation.maxFavorites {
                                showingMaxFavoritesAlert = true
                            } else {
                                favoritesManager.addFavorite(station)
                            }
                        }) {
                            Image(systemName: favoritesManager.isFavorite(station) ? "heart.fill" : "heart")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    if !departures.isEmpty {
                        Button(action: {
                            showingAnalytics.toggle()
                            if showingAnalytics {
                                analyticsViewModel.analyzeWaves(
                                    scheduleViewModel.nextWaves,
                                    for: selectedStation?.id ?? "",
                                    spotName: selectedStation?.name ?? ""
                                )
                            }
                        }) {
                            Image(systemName: showingAnalytics ? "list.bullet" : "chart.bar")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .alert("Maximum Favorites Reached", isPresented: $showingMaxFavoritesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can have a maximum of \(FavoriteStation.maxFavorites) favorite spots. Please remove one before adding another.")
        }
        .onFlip {
            // Toggle Albis-Klasse Filter (nur in der Stationview)
            scheduleViewModel.toggleAlbisClassFilter()
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
