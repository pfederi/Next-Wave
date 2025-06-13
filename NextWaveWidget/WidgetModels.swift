//
//  WidgetModels.swift
//  NextWaveWidget
//
//  Created by Patrick Federi on 12.06.2025.
//

import Foundation
import WidgetKit

// MARK: - Widget Configuration

enum WidgetDisplayMode: String, CaseIterable {
    case nearestStation = "nearest"
    case firstFavorite = "favorite"
    
    var displayName: String {
        switch self {
        case .nearestStation:
            return "Nächste Station"
        case .firstFavorite:
            return "Erster Favorit"
        }
    }
    
    var description: String {
        switch self {
        case .nearestStation:
            return "Zeigt die nächstgelegene Station basierend auf deinem Standort"
        case .firstFavorite:
            return "Zeigt deinen ersten Favoriten aus der Liste"
        }
    }
}

// MARK: - Widget Entry

struct SimpleEntry: TimelineEntry {
    let date: Date
    let departure: DepartureInfo?
    let departures: [DepartureInfo] // For multiple departure widgets
    let displayMode: WidgetDisplayMode
    let stationName: String?
    
    init(date: Date, departure: DepartureInfo? = nil, departures: [DepartureInfo] = [], displayMode: WidgetDisplayMode = .firstFavorite, stationName: String? = nil) {
        self.date = date
        self.departure = departure
        self.departures = departures
        self.displayMode = displayMode
        self.stationName = stationName
    }
} 