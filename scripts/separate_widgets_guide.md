# Widget-Trennung: iOS vs watchOS

## Warum Widgets trennen?

Der Fehler `unable to find or unarchive file for key: [com.federi.Next-Wave::com.federi.Next-Wave.NextWaveWidget:iPhoneWidget:systemMedium]` zeigt, dass das Widget-System versucht, ein iPhone Widget zu rendern, aber die Timeline-Snapshots nicht finden kann.

### Probleme mit gemeinsamen Widget Bundles:

1. **Plattform-Konflikte**: Ein Widget Bundle für beide Plattformen kann zu Verwirrung führen
2. **Verschiedene Widget-Größen**: iPhone (systemSmall/Medium/Large) vs Watch (accessory*)
3. **Unterschiedliche Timeline-Anforderungen**: iPhone und Watch haben verschiedene Update-Zyklen
4. **Bundle-ID Konflikte**: Das System kann nicht eindeutig zuordnen, welches Widget gemeint ist

## Aktuelle Änderungen

✅ **Bereits implementiert:**

1. **Watch Widget separiert** (`NextWaveWidget.swift`):
   - Nur für watchOS kompiliert (`#if os(watchOS)`)
   - Eigenes Widget Bundle: `NextWaveWatchWidgetBundle`
   - Widget Name: `NextWaveWatchWidget`
   - Kind: `"NextWaveWatchWidget"`

2. **iPhone Widget separiert** (`iPhoneWidget.swift`):
   - Nur für iOS kompiliert (`#if os(iOS)`)
   - Eigenes Widget Bundle: `NextWaveiPhoneWidgetBundle`
   - Widget Name: `NextWaveiPhoneWidget`
   - Kind: `"NextWaveiPhoneWidget"`

3. **Robuste Timeline Provider**:
   - Garantiert mindestens einen Timeline-Eintrag
   - Fallback-Mechanismen für leere Daten
   - Umfassendes Logging für Debugging

## Nächste Schritte

### 1. Xcode-Projekt aktualisieren

Das Xcode-Projekt muss möglicherweise aktualisiert werden, um separate Widget-Targets zu haben:

```bash
# Aktuelles Setup prüfen
xcodebuild -list -project NextWave.xcodeproj
```

### 2. Widget Extension konfigurieren

Stellen Sie sicher, dass die Widget Extension richtig konfiguriert ist:

- **Bundle ID**: `com.federi.Next-Wave.NextWaveWidgetExtension`
- **App Groups**: `group.com.federi.Next-Wave`
- **Supported Platforms**: iOS und watchOS

### 3. Testen

1. **Clean Build**:
   ```bash
   ./scripts/debug_widget.sh
   ```

2. **Widget entfernen und neu hinzufügen**:
   - Alle NextWave Widgets vom Home Screen entfernen
   - App neu installieren
   - Widgets wieder hinzufügen

3. **Debug-Logs prüfen**:
   - Xcode Console nach `🔍` und `🚨` Nachrichten durchsuchen
   - Debug-Button in der App verwenden

## Erwartete Verbesserungen

Nach der Trennung sollten folgende Probleme behoben sein:

- ✅ Keine Timeline-Archivierungsfehler mehr
- ✅ Klare Trennung zwischen iPhone und Watch Widgets
- ✅ Bessere Performance durch plattformspezifische Optimierung
- ✅ Einfacheres Debugging durch separate Logs

## Fallback-Strategie

Falls die Trennung nicht funktioniert, können wir:

1. **Conditional Compilation** verwenden (bereits implementiert)
2. **Separate Widget Extensions** erstellen (komplexer, aber sauberer)
3. **Widget-Größen dynamisch handhaben** (weniger robust)

Die aktuelle Lösung mit getrennten Widget Bundles sollte das Problem lösen, ohne die Projektstruktur drastisch zu ändern. 