# Wassertemperatur-Feature Setup

## 🚀 Schnellstart

Die Wassertemperatur-Funktion ist jetzt in der App integriert! Hier sind die Schritte, um sie zu aktivieren:

## 1. Vercel API deployen

Zuerst musst du die API auf Vercel deployen:

```bash
cd /Users/federi/Library/CloudStorage/Dropbox/Apps/Next-Wave
vercel deploy --prod
```

Nach dem Deployment erhältst du eine URL wie: `https://dein-projekt.vercel.app`

## 2. API URL in der App aktualisieren

Öffne die Datei:
```
Next Wave/API/WaterTemperatureAPI.swift
```

Ändere Zeile 7:
```swift
private let baseURL = "https://dein-projekt.vercel.app/api/water-temperature"
```

Ersetze `dein-projekt` mit deiner tatsächlichen Vercel-URL.

## 3. App in Xcode kompilieren

1. Öffne `NextWave.xcodeproj` in Xcode
2. Stelle sicher, dass die neue Datei `WaterTemperatureAPI.swift` im Projekt enthalten ist
3. Kompiliere und starte die App

## 4. Wassertemperaturen anzeigen

Die Wassertemperaturen werden automatisch angezeigt, wenn:
- ✅ "Wetterinformationen anzeigen" in den Einstellungen aktiviert ist
- ✅ Die Station zu einem See gehört, für den Temperaturdaten verfügbar sind

Die Anzeige erscheint unter den Wetter-Informationen mit einem Wassertropfen-Icon 💧

## 🧪 Lokales Testen (ohne Vercel)

Wenn du die API lokal testen möchtest, bevor du sie deployed:

### Option 1: Vercel Dev Server

```bash
cd /Users/federi/Library/CloudStorage/Dropbox/Apps/Next-Wave
vercel dev
```

Die API ist dann verfügbar unter: `http://localhost:3000/api/water-temperature`

Ändere in `WaterTemperatureAPI.swift`:
```swift
private let baseURL = "http://localhost:3000/api/water-temperature"
```

### Option 2: Mock-Daten für Tests

Wenn du die App testen möchtest, ohne die API zu deployen, kannst du temporär Mock-Daten verwenden.

Füge in `WaterTemperatureAPI.swift` nach Zeile 9 hinzu:

```swift
// MARK: - Mock Data (nur für Tests!)
private let useMockData = true

private func getMockData() -> [LakeTemperature] {
    return [
        LakeTemperature(name: "Zürichsee", temperature: 14, waterLevel: "405.96 m.ü.M."),
        LakeTemperature(name: "Vierwaldstättersee", temperature: 13, waterLevel: "433.53 m.ü.M."),
        LakeTemperature(name: "Genfersee", temperature: 15, waterLevel: nil),
        // Füge weitere Seen hinzu...
    ]
}
```

Und ändere die `getWaterTemperatures()` Methode:

```swift
func getWaterTemperatures() async throws -> [LakeTemperature] {
    // Mock-Daten für Tests
    if useMockData {
        print("🌊 Using mock water temperature data")
        return getMockData()
    }
    
    // Rest der Methode...
}
```

**WICHTIG:** Entferne die Mock-Daten wieder, bevor du die App veröffentlichst!

## 📊 Unterstützte Seen

Die API liefert Wassertemperaturen für 32 Schweizer Seen:

- Zürichsee, Vierwaldstättersee, Genfersee
- Bodensee, Thunersee, Brienzersee
- Zugersee, Walensee, Bielersee
- Neuenburgersee, Murtensee
- Lago Maggiore, Luganersee
- Sempachersee, Hallwilersee
- Greifensee, Pfäffikersee
- Und viele mehr...

Vollständige Liste siehe: `API_DOCUMENTATION.md`

## 🔍 Debugging

Wenn die Wassertemperaturen nicht angezeigt werden:

1. **Prüfe die Xcode-Konsole** auf Fehlermeldungen:
   - Suche nach Zeilen mit 🌊 (Wassertemperatur-Logs)
   - Achte auf Fehler beim API-Aufruf

2. **Teste die API direkt** im Browser:
   ```
   https://dein-projekt.vercel.app/api/water-temperature
   ```
   Du solltest JSON-Daten mit Wassertemperaturen sehen.

3. **Prüfe die Einstellungen**:
   - Ist "Wetterinformationen anzeigen" aktiviert?
   - Hast du eine Station ausgewählt, die zu einem See gehört?

4. **Prüfe die Namens-Zuordnung**:
   Die Station muss zu einem See gehören. Prüfe in `stations.json`, ob der See-Name mit den Namen in der API übereinstimmt.

## 🎨 Anpassungen

### Anzeige-Format ändern

In den Views (`FavoriteStationTileView.swift` und `NearestStationTileView.swift`) kannst du das Format anpassen:

```swift
Text("Water: \(String(format: "%.0f°C", waterTemp))")
```

Ändere zu:
```swift
Text("🌊 \(String(format: "%.1f°C", waterTemp))") // Mit Dezimalstelle
```

### Cache-Dauer anpassen

In `WaterTemperatureAPI.swift` (Zeile 31):

```swift
private let cacheValidityDuration: TimeInterval = 3600 // 1 Stunde
```

Ändere zu:
```swift
private let cacheValidityDuration: TimeInterval = 7200 // 2 Stunden
```

## 📝 Datenquelle

Die Wassertemperaturen werden von [MeteoNews](https://meteonews.ch/de/Cms/D121/seen-in-der-schweiz) bezogen und einmal täglich aktualisiert.

## ❓ Probleme?

Bei Problemen:
1. Prüfe die Xcode-Konsole auf Fehlermeldungen
2. Teste die API-URL direkt im Browser
3. Stelle sicher, dass die Vercel-Deployment erfolgreich war
4. Prüfe, ob die `WaterTemperatureAPI.swift` Datei im Xcode-Projekt enthalten ist








