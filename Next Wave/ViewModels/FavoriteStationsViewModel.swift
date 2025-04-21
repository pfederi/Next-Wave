import Foundation
import SwiftUI
import WidgetKit

// Erweiterung von Journey zum einfacheren Zugriff auf wichtige Informationen
extension Journey {
    var time: Date {
        guard let departure = self.stop.departure else { return Date() }
        return AppDateFormatter.parseFullTime(departure) ?? Date()
    }
    
    var routeName: String {
        return name ?? "Unbekannt"
    }
    
    var direction: String {
        return to ?? "Unbekannt"
    }
}

// Struktur für eine Station mit Abfahrtsinformationen
struct StationWithDepartures {
    let station: FavoriteStation
    var nextDeparture: Date?
    
    var name: String { station.name }
}

class FavoriteStationsViewModel: ObservableObject {
    @Published var stations: [StationWithDepartures] = []
    private var updateTimer: Timer?
    private let lakeStationsViewModel: LakeStationsViewModel
    
    init(lakeStationsViewModel: LakeStationsViewModel) {
        self.lakeStationsViewModel = lakeStationsViewModel
        startPeriodicUpdates()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    private func startPeriodicUpdates() {
        // Initial update
        Task { @MainActor in
            await updateNextDepartures()
        }
        
        // Update every 5 minutes
        updateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateNextDepartures()
            }
        }
    }
    
    @MainActor
    func updateNextDepartures() async {
        let favoritesManager = FavoriteStationsManager.shared
        var updatedStations: [StationWithDepartures] = []
        
        for favorite in favoritesManager.favorites {
            if let nextDeparture = await lakeStationsViewModel.getNextDeparture(for: favorite.id) {
                updatedStations.append(StationWithDepartures(
                    station: favorite,
                    nextDeparture: nextDeparture
                ))
            }
        }
        
        stations = updatedStations
        
        // Update widget data
        let departureInfos = stations.compactMap { station -> DepartureInfo? in
            guard let nextDeparture = station.nextDeparture else { return nil }
            
            return DepartureInfo(
                stationName: station.name,
                nextDeparture: nextDeparture,
                routeName: "Next Wave",
                direction: "Departure"
            )
        }
        
        // Save data for widget
        SharedDataManager.shared.saveNextDepartures(departureInfos)
        
        // Reload widget
        WidgetCenter.shared.reloadAllTimelines()
    }
} 