# Promo Tiles - Quick Start Guide

## Übersicht

Die NextWave App kann dynamische Werbe- oder Info-Kacheln anzeigen, die über eine JSON-API gesteuert werden. Diese Kacheln erscheinen nach den Favoriten-Stationen auf der Hauptseite.

**User-Kontrolle:**
- Benutzer können einzelne Tiles nach links wischen um sie zu entfernen (Swipe-to-Dismiss)
- Dismissed Tiles werden nicht mehr angezeigt (persistent gespeichert)
- Neue Tiles werden automatisch wieder angezeigt
- Promo-Tiles können komplett in den Settings deaktiviert werden

## Schnellstart

### 1. JSON-Datei erstellen

Erstelle eine Datei `promo-tiles.json` mit folgendem Inhalt:

```json
{
  "version": 1,
  "tiles": [
    {
      "id": "my-first-promo",
      "title": "Mein Titel",
      "subtitle": "Optional: Untertitel",
      "text": "Hier steht der Beschreibungstext. Maximal 3 Zeilen werden angezeigt.",
      "imageUrl": null,
      "linkUrl": null,
      "isActive": true,
      "priority": 1,
      "validFrom": null,
      "validUntil": null
    }
  ]
}
```

### 2. Auf Server hochladen

Lade die Datei auf deinen Server hoch:
- URL: `https://nextwaveapp.ch/api/promo-tiles.json`
- HTTPS ist erforderlich
- CORS muss erlaubt sein

### 3. Testen

1. Öffne die NextWave App
2. Gehe zu Settings → Data Management → "Clear All Cache"
3. Gehe zurück zur Hauptseite
4. Die Promo-Tile sollte nach den Favoriten erscheinen

## Beispiele

### Einfache Text-Tile (ohne Bild)

```json
{
  "version": 1,
  "tiles": [
    {
      "id": "info-tile-1",
      "title": "Neue Features",
      "subtitle": null,
      "text": "Version 2.0 ist da! Mit verbesserter Performance und neuen Funktionen.",
      "imageUrl": null,
      "linkUrl": null,
      "isActive": true,
      "priority": 1,
      "validFrom": null,
      "validUntil": null
    }
  ]
}
```

### Tile mit Bild und Link

```json
{
  "version": 1,
  "tiles": [
    {
      "id": "winter-special",
      "title": "Winterfahrplan 2026",
      "subtitle": "Neue Routen verfügbar",
      "text": "Entdecke die neuen Winterrouten auf dem Zürichsee! Jetzt mit erweiterten Abfahrtszeiten.",
      "imageUrl": "https://nextwaveapp.ch/images/winter-2026.jpg",
      "linkUrl": "https://nextwaveapp.ch/winter-schedule",
      "isActive": true,
      "priority": 1,
      "validFrom": null,
      "validUntil": null
    }
  ]
}
```

### Zeitlich begrenzte Tile

```json
{
  "version": 1,
  "tiles": [
    {
      "id": "summer-2026",
      "title": "Sommerfahrplan",
      "subtitle": "Ab 1. Juni",
      "text": "Ab 1. Juni neue Routen und mehr Abfahrten!",
      "imageUrl": null,
      "linkUrl": null,
      "isActive": true,
      "priority": 1,
      "validFrom": "2026-06-01T00:00:00Z",
      "validUntil": "2026-08-31T23:59:59Z"
    }
  ]
}
```

### Mehrere Tiles

```json
{
  "version": 1,
  "tiles": [
    {
      "id": "tile-1",
      "title": "Erste Tile",
      "text": "Diese Tile wird zuerst angezeigt (priority: 1)",
      "isActive": true,
      "priority": 1
    },
    {
      "id": "tile-2",
      "title": "Zweite Tile",
      "text": "Diese Tile wird danach angezeigt (priority: 2)",
      "isActive": true,
      "priority": 2
    }
  ]
}
```

## Häufige Probleme

### Tile wird nicht angezeigt

**Mögliche Ursachen:**
1. `isActive` ist `false` → Setze auf `true`
2. `validFrom` liegt in der Zukunft → Prüfe Datum
3. `validUntil` liegt in der Vergangenheit → Prüfe Datum
4. JSON-Datei ist nicht erreichbar (404) → Prüfe URL
5. Cache ist noch aktiv → Lösche Cache in App-Settings

**Debugging:**
1. Öffne Xcode Console
2. Suche nach `[PromoTile]` Logs
3. Prüfe Fehlermeldungen

### Bild wird nicht geladen

**Mögliche Ursachen:**
1. URL ist falsch → Prüfe `imageUrl`
2. Bild ist zu groß → Max. 500KB empfohlen
3. HTTPS fehlt → Nur HTTPS-URLs werden geladen
4. CORS nicht konfiguriert → Erlaube App-Zugriff

## Feld-Referenz

| Feld | Typ | Pflicht | Beschreibung |
|------|-----|---------|--------------|
| `id` | string | ✅ | Eindeutige ID (z.B. "winter-2026") |
| `title` | string | ✅ | Haupttitel (fett, groß) |
| `subtitle` | string? | ❌ | Untertitel (grau, kleiner) |
| `text` | string | ✅ | Beschreibung (max. 3 Zeilen) |
| `imageUrl` | string? | ❌ | URL zum Bild (HTTPS) |
| `linkUrl` | string? | ❌ | URL die beim Klick geöffnet wird |
| `isActive` | bool | ✅ | Ob Tile aktiv ist (true/false) |
| `priority` | int | ✅ | Sortierung (1 = höchste Priorität) |
| `validFrom` | string? | ❌ | Start-Datum (ISO 8601) |
| `validUntil` | string? | ❌ | End-Datum (ISO 8601) |

## Bilder

### Empfohlene Spezifikationen
- **Format**: JPG oder PNG
- **Breite**: 800-1200px
- **Höhe**: 400-600px
- **Aspect Ratio**: 2:1 oder 16:9
- **Dateigröße**: < 500KB
- **HTTPS**: Erforderlich

### Hinweise
- Bilder werden auf 120px Höhe skaliert
- Wichtige Inhalte sollten zentriert sein
- Wird asynchron geladen (Spinner während Ladezeit)

## Datumsformat

Verwende ISO 8601 Format für Datumsangaben:

```
2026-01-08T00:00:00Z  ← Mitternacht UTC
2026-06-01T12:00:00Z  ← 12:00 Uhr UTC
2026-12-31T23:59:59Z  ← 23:59:59 UTC
```

**Wichtig**: Verwende immer UTC-Zeit (mit `Z` am Ende)!

## Cache

- Die App cached Tiles für **1 Stunde**
- Nach 1 Stunde werden automatisch neue Daten geladen
- Manuelles Löschen: Settings → Data Management → "Clear All Cache"

## Keine Tiles anzeigen

Um keine Tiles anzuzeigen, gibt es 3 Möglichkeiten:

### Option 1: Leeres Array
```json
{
  "version": 1,
  "tiles": []
}
```

### Option 2: Alle inaktiv
```json
{
  "version": 1,
  "tiles": [
    {
      "id": "tile-1",
      "title": "...",
      "text": "...",
      "isActive": false,
      "priority": 1
    }
  ]
}
```

### Option 3: 404 Response
Lösche die `promo-tiles.json` Datei vom Server.

## Weitere Dokumentation

Für detaillierte technische Dokumentation siehe:
- `PROMO_TILE_API.md` - Vollständige API-Dokumentation
- `promo-tiles-example.json` - Beispiel-JSON
- `ARC42_DOCUMENTATION.md` - Architektur-Dokumentation

## Support

Bei Fragen oder Problemen:
1. Prüfe die Xcode Console Logs
2. Teste mit `promo-tiles-example.json`
3. Kontaktiere den Entwickler
