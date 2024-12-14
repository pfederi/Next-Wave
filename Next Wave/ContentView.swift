//
//  ContentView.swift
//  Next Wave
//
//  Created by Patrick Federi on 12.12.2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var showingInfoView = false
    private let toolbarBackground = Color(red: 0.85, green: 0.9, blue: 0.95)
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .long
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            MainContentView(viewModel: viewModel, dateFormatter: dateFormatter)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(toolbarBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Next Wave")
                            .font(.title2)
                            .bold()
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingInfoView = true
                        }) {
                            Image(systemName: "info.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingInfoView) {
                    InfoView()
                }
        }
    }
}

struct MainContentView: View {
    private let maritimeBackground = Color(red: 0.95, green: 0.98, blue: 1.0)
    
    @ObservedObject var viewModel: ScheduleViewModel
    let dateFormatter: DateFormatter
    
    var body: some View {
        VStack {
            ErrorView(errorMessage: viewModel.errorMessage)
            
            Text(dateFormatter.string(from: Date()))
                .font(.callout)
                .foregroundColor(.gray)
                .padding(.top, 16)
            
            if viewModel.selectedStop != nil {
                LocationPickerView(viewModel: viewModel)
                WaveListView(viewModel: viewModel)
            } else {
                Spacer()
                LocationPickerView(viewModel: viewModel)
                EmptyWaveView(selectedStop: "")
                Spacer()
            }
        }
        .background(maritimeBackground)
        .onChange(of: viewModel.selectedStop) { oldValue, newValue in
            viewModel.updateNextWaves()
        }
    }
}

struct ErrorView: View {
    let errorMessage: String?
    
    var body: some View {
        if let error = errorMessage {
            Text("Ship's log: Error! \(error)")
                .foregroundColor(.red)
                .font(.title3)
                .padding()
        }
    }
}

struct LocationPickerView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    
    var body: some View {
        Menu {
            Picker("Port", selection: $viewModel.selectedStop) {
                Text("Choose a spot")
                    .font(.title3)
                    .foregroundColor(.black)
                    .tag(nil as String?)
                ForEach(viewModel.availableStops, id: \.self) { stop in
                    Text(stop)
                        .font(.title3)
                        .foregroundColor(.black)
                        .tag(stop as String?)
                }
            }
        } label: {
            HStack {
                Text(viewModel.selectedStop ?? "Choose your spot")
                    .font(.title3)
                    .foregroundColor(.black)
                Image(systemName: "chevron.down")
                    .font(.title3)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.top,0)
    }
}

struct WaveListView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    
    var currentWaves: [WaveEvent] {
        viewModel.nextWaves.filter { wave in
            viewModel.isDateInRange(wave.period)
        }
    }
    
    var body: some View {
        VStack {
            if currentWaves.isEmpty {
                EmptyWaveView(selectedStop: viewModel.selectedStop ?? "")
            } else {
                List(currentWaves) { wave in
                    let isFirstItem = currentWaves.first?.id == wave.id
                    let rowHeight: CGFloat = 60
                    let isPast = wave.remainingTimeString == "missed"
                    
                    ZStack {
                        if isFirstItem && viewModel.shouldShowSwipeHint {
                            HStack {
                                Spacer()
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.blue)
                                    .padding(.trailing, 16)
                            }
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .center) {
                                Text(wave.timeString)
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(isPast ? .gray : .primary)
                                Text(wave.remainingTimeString)
                                    .font(.caption)
                                    .foregroundColor(wave.remainingTimeString == "now" ? .green : 
                                                   isPast ? .gray : .secondary)
                            }
                            .frame(width: 65)
                            
                            VStack(alignment: .leading) {
                                Text(wave.neighborStop)
                                    .font(.subheadline)
                                    .foregroundColor(isPast ? .gray : .primary)
                                Text(wave.routeName)
                                    .font(.caption)
                                    .foregroundColor(isPast ? .gray : .secondary)
                            }
                            
                            Spacer()
                            
                            if wave.hasNotification && !isPast {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground))
                        .offset(x: isFirstItem && viewModel.shouldShowSwipeHint ? -100 : 0)
                    }
                    .frame(height: rowHeight)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !isPast {
                            NotificationButton(wave: wave, viewModel: viewModel)
                        }
                    }
                }
                .listStyle(.plain)
                .animation(.none, value: currentWaves)
            }
        }
        .onChange(of: viewModel.selectedStop) { oldValue, newValue in
            if newValue != nil && !viewModel.hasShownSwipeHint {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        viewModel.shouldShowSwipeHint = true
                    }
                    viewModel.hasShownSwipeHint = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            viewModel.shouldShowSwipeHint = false
                        }
                    }
                }
            }
        }
    }
}

struct EmptyWaveView: View {
    let selectedStop: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Ahoy Wakethief! 🏄‍♂️")
                .font(.title2)
            Text("Select a spot to catch some waves!")
                .font(.callout)
            Text("Keep your distance and \ndon't foil directly behind the boat.")
                .font(.callout)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.black)
        .padding()
    }
}

struct NotificationButton: View {
    let wave: WaveEvent
    let viewModel: ScheduleViewModel
    
    var body: some View {
        if wave.hasNotification {
            Button {
                viewModel.removeNotification(for: wave)
            } label: {
                Label("Remove Reminder", systemImage: "bell.slash.fill")
            }
            .tint(.red)
        } else {
            Button {
                viewModel.scheduleNotification(for: wave)
            } label: {
                Label("Set Reminder", systemImage: "bell.fill")
            }
            .tint(.blue)
        }
    }
}

struct InfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("How to use Next Wave")
                    .font(.title2)
                    .bold()
                
                List {
                    Text("Select your spot from the menu")
                    Text("Swipe left on a wave to set a reminder")
                    Text("You will receive a notification 5 minutes before the wave.")
                }
                .listStyle(.plain)
                
                GeometryReader { geometry in
                    Image("life-is-good")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: geometry.size.height)
                }
                
                Link("Join Pumpfoiling Community", destination: URL(string: "https://pumpfoiling.community")!)
                    .foregroundColor(.blue)
                    .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 80, height: 5)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
