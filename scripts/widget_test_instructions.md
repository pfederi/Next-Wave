# Widget Test Anweisungen

## 🔧 Was wurde geändert

Das iPhone Widget wurde mit einem **Test-Modus** ausgestattet:

- ✅ Wenn Favoriten gefunden werden, erstellt das Widget automatisch Test-Abfahrtsdaten
- ✅ Das Widget sollte jetzt "Küsnacht ZH (See)" mit einer Test-Abfahrt in 15 Minuten anzeigen
- ✅ Umfassendes Logging für Debugging

## 📱 Test-Schritte

### 1. App neu installieren
```bash
# In Xcode:
# 1. Product → Clean Build Folder
# 2. Product → Build (NextWave scheme)
# 3. Product → Run (auf Gerät/Simulator)
```

### 2. Widget hinzufügen/aktualisieren
1. **Alle alten NextWave Widgets entfernen**
2. **Lange auf Home Screen drücken**
3. **"+" Symbol tippen**
4. **"NextWave" suchen**
5. **Widget hinzufügen (Small, Medium oder Large)**

### 3. Erwartetes Verhalten

**✅ ERFOLG - Widget sollte zeigen:**
- Station: "Küsnacht ZH (See)"
- Abfahrt: "at [Zeit]" (15 Minuten in der Zukunft)
- Blaues Design mit Fähren-Symbol

**❌ PROBLEM - Widget zeigt noch "No Favorites Set":**
- Das Widget kann die Favoriten nicht laden
- App Group funktioniert nicht korrekt

### 4. Debug-Logs prüfen

**In Xcode Console nach diesen Nachrichten suchen:**
```
🔍 iPhone Widget getTimeline called
🔍 SharedDataManager.loadFavoriteStations() returned X stations
🔍 FORCE CREATING TEST DEPARTURE for: Küsnacht ZH (See)
🔍 FORCE CREATED 30 entries with test departure
```

**Falls diese Logs nicht erscheinen:**
- Widget Extension läuft nicht
- Logging funktioniert nicht

## 🚨 Troubleshooting

### Problem: Widget zeigt noch "No Favorites Set"

**Lösung 1: Widget-Cache löschen**
```bash
# Simulator zurücksetzen
xcrun simctl erase all

# Oder Gerät neu starten
```

**Lösung 2: App Group prüfen**
- In Xcode: Project Settings → Capabilities → App Groups
- Sicherstellen dass "group.com.federi.Next-Wave" aktiviert ist
- Für ALLE Targets (App, Widget Extension, Watch App)

**Lösung 3: Manuelle Widget-Aktualisierung**
- Widget vom Home Screen entfernen
- App öffnen → Debug Button drücken
- Widget wieder hinzufügen

### Problem: Keine Debug-Logs sichtbar

**Lösung:**
- Xcode → Window → Devices and Simulators
- Gerät auswählen → "Open Console"
- Nach "NextWave" oder "🔍" filtern

## 🎯 Nächste Schritte

**Wenn Test erfolgreich:**
- Test-Code entfernen
- Echte Abfahrtsdaten implementieren

**Wenn Test fehlschlägt:**
- App Group Konfiguration prüfen
- Separate Widget Extension erstellen
- Alternative Datenübertragung implementieren 