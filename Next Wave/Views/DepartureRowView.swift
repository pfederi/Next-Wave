import SwiftUI
import MessageUI

struct DepartureRowView: View {
    let wave: WaveEvent
    let index: Int
    let formattedTime: String
    let isPast: Bool
    let isCurrentDay: Bool
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var lakeStationsViewModel: LakeStationsViewModel
    @State private var showShareSheet = false
    @State private var showWeatherLegend = false
    
    // Helper: Gibt die richtige Wassertemperatur für das Datum und die Uhrzeit der Wave zurück
    private func getWaterTemperatureForWave(lake: Lake) -> Double? {
        let waveDate = wave.time
        let calendar = Calendar.current
        
        // Für heute: Aktuelle Temperatur verwenden
        if calendar.isDateInToday(waveDate) {
            return lake.waterTemperature
        }
        
        // Für zukünftige Tage: Vorhersage-Temperatur zur Abfahrtszeit verwenden
        guard let forecasts = lake.temperatureForecast, !forecasts.isEmpty else {
            return nil // Keine Vorhersage verfügbar
        }
        
        // Finde die Vorhersage, die der Abfahrtszeit am nächsten liegt
        let closestForecast = forecasts.min(by: { forecast1, forecast2 in
            let diff1 = abs(forecast1.time.timeIntervalSince(waveDate))
            let diff2 = abs(forecast2.time.timeIntervalSince(waveDate))
            return diff1 < diff2
        })
        
        // Prüfe, ob die nächstliegende Vorhersage am selben Tag ist (max. 12h Differenz)
        if let forecast = closestForecast,
           abs(forecast.time.timeIntervalSince(waveDate)) < 12 * 3600 {
            return forecast.temperature
        }
        
        return nil // Keine passende Vorhersage verfügbar
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                        
                        if !isPast {
                            if scheduleViewModel.hasNotification(for: wave) {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                            }
                            
                            // Share Button
                            Button(action: {
                                print("🔵 Share button tapped")
                                showShareSheet = true
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
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
                                if let shipName = wave.shipName {
                                    if shipName == "Unknown" {
                                        Text("No data")
                                            .lineLimit(1)
                                    } else {
                                        Text(shipName)
                                            .lineLimit(1)
                                        Image(getWaveIcon(for: shipName))
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 12)
                                    }
                                } else {
                                    // Noch am Laden
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                        Text("Loading...")
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
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
            
            // Dritte Zeile: Wetterdaten und Wasserpegel (volle Breite)
            if !isPast && appSettings.showWeatherInfo {
                if let weather = wave.weather {
                    Button(action: {
                        showWeatherLegend = true
                    }) {
                        HStack(spacing: 0) {
                            Spacer()
                            HStack(spacing: 4) {
                            // Night/Darkness Indicator (if applicable)
                            if let darknessIcon = getDarknessIcon(for: wave.time) {
                                Image(systemName: darknessIcon)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                
                                Text("|")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 11))
                            }
                            
                            // Wetter-Icon
                            Image(systemName: weather.weatherIcon)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            
                            Text("|")
                                .foregroundColor(.gray)
                                .font(.system(size: 11))
                            
                            // Lufttemperatur Icon
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                            
                            // Lufttemperatur
                            Text(String(format: "%.1f°", weather.temperature))
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                            
                            Text("|")
                                .foregroundColor(.gray)
                                .font(.system(size: 11))
                            
                            // Wassertemperatur & Neoprenanzug-Dicke (nur wenn Wassertemp verfügbar)
                            if let selectedStation = lakeStationsViewModel.selectedStation,
                               let lake = lakeStationsViewModel.lakes.first(where: { lake in
                                   lake.stations.contains(where: { $0.name == selectedStation.name })
                               }), let waterTemp = getWaterTemperatureForWave(lake: lake) {
                                
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                
                                Text(String(format: "%.1f°", waterTemp))
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                
                                Text("|")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 11))
                            }
                            
                            // Wind
                            Image(systemName: "wind")
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                            
                            Text("\(Int(weather.windSpeedKnots)) kn \(weather.windDirectionText)")
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                            
                            // Neoprenanzug-Dicke (nur wenn Wassertemperatur verfügbar)
                            if let selectedStation = lakeStationsViewModel.selectedStation,
                               let lake = lakeStationsViewModel.lakes.first(where: { lake in
                                   lake.stations.contains(where: { $0.name == selectedStation.name })
                               }), let waterTemp = getWaterTemperatureForWave(lake: lake),
                               let thickness = getWetsuitThickness(for: waterTemp, airTemp: weather.feelsLike) {
                                
                                Text("|")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 11))
                                
                                Image(systemName: "figure.arms.open")
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                
                                Text(thickness)
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                            }
                            
                            // Wasserpegel-Differenz (nur für heutigen Tag)
                            if Calendar.current.isDateInToday(lakeStationsViewModel.selectedDate),
                               let selectedStation = lakeStationsViewModel.selectedStation,
                               let lake = lakeStationsViewModel.lakes.first(where: { lake in
                                   lake.stations.contains(where: { $0.name == selectedStation.name })
                               }), let waterLevelDiff = lake.waterLevelDifference {
                                
                                Text("|")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 11))
                                
                                // Icon basierend auf Wasserpegel-Richtung
                                let isHigher = waterLevelDiff.hasPrefix("+")
                                let iconName = isHigher ? "water.waves.and.arrow.trianglehead.up" : "water.waves.and.arrow.trianglehead.down"
                                
                                Image(systemName: iconName)
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                
                                Text("\(waterLevelDiff) cm")
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                            }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
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
        .sheet(isPresented: $showShareSheet) {
            CustomShareSheet(text: generateShareText(), isPresented: $showShareSheet)
        }
        .sheet(isPresented: $showWeatherLegend) {
            WeatherLegendView(isPresented: $showWeatherLegend)
        }
    }
    
    private func getWetsuitThickness(for waterTemp: Double, airTemp: Double? = nil) -> String? {
        // Basierend auf Quiksilver Neoprenanzug-Dicke Tabelle
        // https://quiksilver.de/expert-guide/surf/buying/neoprenanzug-dicke-beratung.html
        // Regel: Wenn Lufttemperatur + Wassertemperatur < 30 °C, eine Stufe dicker wählen
        
        var adjustedWaterTemp = waterTemp
        
        // Prüfe ob wir eine Stufe dicker gehen müssen
        if let air = airTemp, (air + waterTemp) < 30 {
            // Simuliere eine niedrigere Wassertemperatur für dickeren Anzug
            adjustedWaterTemp = waterTemp - 3
        }
        
        switch adjustedWaterTemp {
        case 23...:
            return nil // Zu warm für Neoprenanzug
        case 18..<23:
            return "0.5-2"
        case 15..<18:
            return "3/2"
        case 12..<15:
            return "4/3"
        case 10..<12:
            return "5/4"
        case 1..<10:
            return "6/5"
        default:
            return "6/5"
        }
    }
    
    // MARK: - Darkness Indicator Helpers
    
    private func getDarknessIcon(for departureTime: Date) -> String? {
        guard let sunTimes = scheduleViewModel.sunTimes else {
            return nil
        }
        
        let calendar = Calendar.current
        let departureComponents = calendar.dateComponents([.hour, .minute], from: departureTime)
        let sunriseComponents = calendar.dateComponents([.hour, .minute], from: sunTimes.sunrise)
        let sunsetComponents = calendar.dateComponents([.hour, .minute], from: sunTimes.sunset)
        let twilightBeginComponents = calendar.dateComponents([.hour, .minute], from: sunTimes.civilTwilightBegin)
        let twilightEndComponents = calendar.dateComponents([.hour, .minute], from: sunTimes.civilTwilightEnd)
        
        guard let departureMinutes = departureComponents.hour.map({ $0 * 60 + (departureComponents.minute ?? 0) }),
              let sunriseMinutes = sunriseComponents.hour.map({ $0 * 60 + (sunriseComponents.minute ?? 0) }),
              let sunsetMinutes = sunsetComponents.hour.map({ $0 * 60 + (sunsetComponents.minute ?? 0) }),
              let twilightBeginMinutes = twilightBeginComponents.hour.map({ $0 * 60 + (twilightBeginComponents.minute ?? 0) }),
              let twilightEndMinutes = twilightEndComponents.hour.map({ $0 * 60 + (twilightEndComponents.minute ?? 0) }) else {
            return nil
        }
        
        // Check if departure is before sunrise or after sunset
        if departureMinutes < sunriseMinutes || departureMinutes > sunsetMinutes {
            // Check if it's during twilight (±15 minutes)
            if (departureMinutes >= twilightBeginMinutes && departureMinutes < sunriseMinutes) ||
               (departureMinutes > sunsetMinutes && departureMinutes <= twilightEndMinutes) {
                return "moon.stars.fill" // Twilight icon
            } else {
                return "moon.fill" // Full night icon
            }
        }
        
        return nil // Daylight - no icon
    }
    
    private func isDuskOrDawn(for departureTime: Date) -> Bool {
        guard let sunTimes = scheduleViewModel.sunTimes else {
            return false
        }
        
        let calendar = Calendar.current
        let departureComponents = calendar.dateComponents([.hour, .minute], from: departureTime)
        let sunriseComponents = calendar.dateComponents([.hour, .minute], from: sunTimes.sunrise)
        let sunsetComponents = calendar.dateComponents([.hour, .minute], from: sunTimes.sunset)
        let twilightBeginComponents = calendar.dateComponents([.hour, .minute], from: sunTimes.civilTwilightBegin)
        let twilightEndComponents = calendar.dateComponents([.hour, .minute], from: sunTimes.civilTwilightEnd)
        
        guard let departureMinutes = departureComponents.hour.map({ $0 * 60 + (departureComponents.minute ?? 0) }),
              let sunriseMinutes = sunriseComponents.hour.map({ $0 * 60 + (sunriseComponents.minute ?? 0) }),
              let sunsetMinutes = sunsetComponents.hour.map({ $0 * 60 + (sunsetComponents.minute ?? 0) }),
              let twilightBeginMinutes = twilightBeginComponents.hour.map({ $0 * 60 + (twilightBeginComponents.minute ?? 0) }),
              let twilightEndMinutes = twilightEndComponents.hour.map({ $0 * 60 + (twilightEndComponents.minute ?? 0) }) else {
            return false
        }
        
        // Check if departure is during twilight period
        return (departureMinutes >= twilightBeginMinutes && departureMinutes < sunriseMinutes) ||
               (departureMinutes > sunsetMinutes && departureMinutes <= twilightEndMinutes)
    }
    
    private func generateShareText() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, d. MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "de_CH")
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        
        let dateString = dateFormatter.string(from: wave.time)
        let stationName = lakeStationsViewModel.selectedStation?.name ?? ""
        
        // Zufälliger Intro-Text
        let introTexts = [
            "🥳 Let's share the next wave for a party wave!",
            "🌊 Catch the wave with me!",
            "🌊 Ready to ride the next wave together?",
            "🚢 All aboard for the next adventure!",
            "🌊 Join me on this wave - it's going to be epic!"
        ]
        let randomIntro = introTexts.randomElement() ?? introTexts[0]
        
        var text = "\(randomIntro)\n\n"
        text += "📍 \(stationName) → \(wave.neighborStopName)\n"
        text += "📅 \(dateString)\n"
        text += "🕐 \(formattedTime) Uhr\n"
        text += "🚢 Route \(wave.routeNumber)\n"
        
        // Schiffsname hinzufügen wenn vorhanden
        if let shipName = wave.shipName {
            text += "⛴️ \(shipName)\n"
        }
        
        // Wetterdaten in der Reihenfolge der Wetterzeile
        // 1. Lufttemperatur
        if let weather = wave.weather {
            text += "🌡️ \(String(format: "%.1f°C", weather.temperature))\n"
        }
        
        // 2. Wassertemperatur
        if let selectedStation = lakeStationsViewModel.selectedStation,
           let lake = lakeStationsViewModel.lakes.first(where: { lake in
               lake.stations.contains(where: { $0.name == selectedStation.name })
           }), let waterTemp = getWaterTemperatureForWave(lake: lake) {
            text += "💧 Water Temperature: \(String(format: "%.1f°C", waterTemp))\n"
        }
        
        // 3. Wind
        if let weather = wave.weather {
            text += "💨 \(Int(weather.windSpeedKnots)) kn \(weather.windDirectionText)\n"
        }
        
        // 4. Neoprenanzug-Dicke
        if let selectedStation = lakeStationsViewModel.selectedStation,
           let lake = lakeStationsViewModel.lakes.first(where: { lake in
               lake.stations.contains(where: { $0.name == selectedStation.name })
           }), let waterTemp = getWaterTemperatureForWave(lake: lake),
           let weather = wave.weather,
           let thickness = getWetsuitThickness(for: waterTemp, airTemp: weather.feelsLike) {
            text += "🤸 Wetsuit: \(thickness)mm\n"
        }
        
        // 5. Wasserpegel-Differenz (nur für heutigen Tag)
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(wave.time)
        
        if isToday,
           let selectedStation = lakeStationsViewModel.selectedStation,
           let lake = lakeStationsViewModel.lakes.first(where: { lake in
               lake.stations.contains(where: { $0.name == selectedStation.name })
           }), let waterLevelDiff = lake.waterLevelDifference {
            text += "📊 Water Level: \(waterLevelDiff) cm\n"
        }
        
        text += "\n📱 Shared via NextWave App\n"
        text += "https://apps.apple.com/ch/app/nextwave/id6739363035"
        
        return text
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
        switch cleanName {
        case "MS Panta Rhei", "MS Albis", "EMS Uetliberg", "EMS Pfannenstiel", "EM Uetliberg", "EM Pfannenstiel":
            return "waves3"
        case "MS Wädenswil", "MS Limmat", "MS Helvetia", "MS Linth", "DS Stadt Zürich", "DS Stadt Rapperswil":
            return "waves2"
        default:
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

// Custom Share Sheet
struct CustomShareSheet: View {
    let text: String
    @Binding var isPresented: Bool
    @State private var showMessageComposer = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button("Fertig") {
                    isPresented = false
                }
                .padding()
            }
            
            // Erklärungstext
            Text("Share your next wave with friends")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 25)
            
            // Share Options in Grid
            HStack(spacing: 0) {
                // WhatsApp
                if canOpenWhatsApp() {
                    ShareTileButton(
                        icon: "message.fill",
                        iconColor: .white,
                        backgroundColor: Color(red: 0.15, green: 0.78, blue: 0.45),
                        title: "WhatsApp",
                        action: {
                            shareToWhatsApp()
                            isPresented = false
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
                
                // Messages
                ShareTileButton(
                    icon: "message.fill",
                    iconColor: .white,
                    backgroundColor: .green,
                    title: "Messages",
                    action: {
                        if MFMessageComposeViewController.canSendText() {
                            showMessageComposer = true
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                
                // Mail
                ShareTileButton(
                    icon: "envelope.fill",
                    iconColor: .white,
                    backgroundColor: .blue,
                    title: "Mail",
                    action: {
                        shareToMail()
                        isPresented = false
                    }
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showMessageComposer) {
            MessageComposeView(text: text, isPresented: $showMessageComposer)
                .onDisappear {
                    isPresented = false
                }
        }
    }
    
    private func canOpenWhatsApp() -> Bool {
        guard let whatsappURL = URL(string: "whatsapp://") else { return false }
        return UIApplication.shared.canOpenURL(whatsappURL)
    }
    
    private func shareToWhatsApp() {
        if let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let whatsappURL = URL(string: "whatsapp://send?text=\(encodedText)") {
            UIApplication.shared.open(whatsappURL)
        }
    }
    
    
    private func shareToMail() {
        if let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let mailURL = URL(string: "mailto:?subject=Next%20Wave&body=\(encodedText)") {
            UIApplication.shared.open(mailURL)
        }
    }
}

struct ShareTileButton: View {
    let icon: String
    let iconColor: Color
    let backgroundColor: Color
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 28))
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Message Compose View
struct MessageComposeView: UIViewControllerRepresentable {
    let text: String
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.body = text
        controller.messageComposeDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        @Binding var isPresented: Bool
        
        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            isPresented = false
        }
    }
}

// Weather Legend View
struct WeatherLegendView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Weather Information")) {
                    LegendRow(
                        icon: "sun.max.fill",
                        iconColor: .primary,
                        title: "Weather Condition",
                        description: "Current weather condition (sunny, cloudy, rainy, etc.)"
                    )
                    
                    LegendRow(
                        icon: "thermometer.medium",
                        iconColor: .primary,
                        title: "Air Temperature",
                        description: "Current air temperature in degrees Celsius"
                    )
                    
                    LegendRow(
                        icon: "drop.fill",
                        iconColor: .primary,
                        title: "Water Temperature",
                        description: "Current lake water temperature in degrees Celsius"
                    )
                    
                    LegendRow(
                        icon: "figure.arms.open",
                        iconColor: .primary,
                        title: "Wetsuit Thickness",
                        description: "Recommended wetsuit thickness in millimeters based on water temperature and wind chill. If air + water temp < 30°C, one size thicker is recommended (e.g. 3/2mm, 4/3mm)"
                    )
                    
                    LegendRow(
                        icon: "wind",
                        iconColor: .primary,
                        title: "Wind Speed & Direction",
                        description: "Wind speed in knots (kn) and wind direction (N, NE, E, SE, S, SW, W, NW)"
                    )
                    
                    LegendRow(
                        icon: "moon.fill",
                        iconColor: .primary,
                        title: "Night Time",
                        description: "Departure is before sunrise or after sunset. Moon icon indicates full darkness, moon with stars indicates twilight (dusk/dawn)"
                    )
                    
                    LegendRow(
                        icon: "water.waves.and.arrow.trianglehead.up",
                        iconColor: .primary,
                        title: "Water Level",
                        description: "Difference from average water level in centimeters. Arrow up (↑) indicates higher water level, arrow down (↓) indicates lower water level (only shown for today)"
                    )
                }
                
                Section(header: Text("Weather Conditions")) {
                    LegendRow(
                        icon: "sun.max.fill",
                        iconColor: .primary,
                        title: "Clear Sky",
                        description: "Sunny weather with no clouds"
                    )
                    
                    LegendRow(
                        icon: "cloud.sun.fill",
                        iconColor: .primary,
                        title: "Partly Cloudy",
                        description: "Mix of sun and clouds"
                    )
                    
                    LegendRow(
                        icon: "cloud.fill",
                        iconColor: .primary,
                        title: "Cloudy",
                        description: "Overcast sky"
                    )
                    
                    LegendRow(
                        icon: "cloud.rain.fill",
                        iconColor: .primary,
                        title: "Rain",
                        description: "Rainy weather"
                    )
                }
            }
            .navigationTitle("Weather Legend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// Legend Row Component
struct LegendRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
} 