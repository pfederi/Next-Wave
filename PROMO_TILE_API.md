# Promo Tile API Documentation

## Übersicht

Die NextWave App kann dynamische Werbe- oder Info-Kacheln anzeigen, die über eine JSON-API gesteuert werden. Diese Kacheln erscheinen nach den Favoriten-Stationen auf der Hauptseite.

### User-Kontrolle

**Swipe-to-Dismiss:**
- Benutzer können einzelne Tiles nach links wischen um sie zu entfernen
- Dismissed Tiles werden persistent in `UserDefaults` gespeichert
- Dismissed Tiles werden nicht mehr angezeigt, auch nach App-Neustart
- Neue Tiles (mit neuer ID) werden automatisch wieder angezeigt

**Settings:**
- Promo-Tiles können komplett in den App-Settings deaktiviert werden
- Toggle: "Show Promo Tiles" (Standard: aktiviert)
- Wenn deaktiviert, werden keine Tiles angezeigt (auch keine neuen)

## API Endpoint

```
https://nextwaveapp.ch/api/promo-tiles.json
```

## JSON Format

```json
{
  "version": 1,
  "tiles": [
    {
      "id": "winter-special-2026",
      "title": "Winterfahrplan 2026",
      "subtitle": "Neue Routen verfügbar",
      "text": "Entdecke die neuen Winterrouten auf dem Zürichsee! Jetzt mit erweiterten Abfahrtszeiten.",
      "imageUrl": "https://nextwaveapp.ch/images/winter-2026.jpg",
      "linkUrl": "https://nextwaveapp.ch/winter-schedule",
      "isActive": true,
      "priority": 1,
      "validFrom": "2026-01-01T00:00:00Z",
      "validUntil": "2026-03-31T23:59:59Z"
    },
    {
      "id": "app-update-info",
      "title": "Neue Features",
      "subtitle": null,
      "text": "Version 2.0 ist da! Mit verbesserter Performance und neuen Funktionen.",
      "imageUrl": null,
      "linkUrl": null,
      "isActive": true,
      "priority": 2,
      "validFrom": null,
      "validUntil": null
    }
  ]
}
```

## Feld-Beschreibungen

### PromoTilesResponse

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `version` | `int` | API-Version für Cache-Invalidierung |
| `tiles` | `array` | Array von Promo-Tiles |

### PromoTile

| Feld | Typ | Pflicht | Beschreibung |
|------|-----|---------|--------------|
| `id` | `string` | ✅ | Eindeutige ID der Tile |
| `title` | `string` | ✅ | Haupttitel (fett) |
| `subtitle` | `string?` | ❌ | Untertitel (grau, kleiner) |
| `text` | `string` | ✅ | Beschreibungstext (max. 3 Zeilen) |
| `imageUrl` | `string?` | ❌ | URL zum Bild (wird oben angezeigt, 120px hoch) |
| `linkUrl` | `string?` | ❌ | URL die beim Klick geöffnet wird (Safari) |
| `isActive` | `bool` | ✅ | Ob die Tile aktiv ist |
| `priority` | `int` | ✅ | Sortierung (niedriger = höher) |
| `validFrom` | `string?` | ❌ | Start-Datum (ISO 8601) |
| `validUntil` | `string?` | ❌ | End-Datum (ISO 8601) |

## Validierungs-Regeln

Eine Tile wird nur angezeigt wenn:
1. `isActive = true`
2. Aktuelles Datum >= `validFrom` (falls gesetzt)
3. Aktuelles Datum <= `validUntil` (falls gesetzt)

## Caching

- Die App cached die Tiles für **1 Stunde**
- Bei 404-Response werden keine Tiles angezeigt (kein Fehler)
- Cache kann in den App-Settings manuell geleert werden

## Bilder

### Empfohlene Spezifikationen
- **Format**: JPG oder PNG
- **Breite**: 800-1200px
- **Höhe**: 400-600px (wird auf 120px Höhe skaliert)
- **Aspect Ratio**: 2:1 oder 16:9
- **Dateigröße**: < 500KB

### Hinweise
- Bilder werden mit `aspectRatio(.fill)` angezeigt
- Wichtige Inhalte sollten zentriert sein
- Bilder werden asynchron geladen (Spinner während Ladezeit)

## Beispiel-Szenarien

### 1. Keine Promo-Tiles (404)
```
GET https://nextwaveapp.ch/api/promo-tiles.json
Response: 404 Not Found
```
→ App zeigt keine Tiles an (kein Fehler)

### 2. Leere Tiles
```json
{
  "version": 1,
  "tiles": []
}
```
→ App zeigt keine Tiles an

### 3. Inaktive Tile
```json
{
  "version": 1,
  "tiles": [
    {
      "id": "test",
      "title": "Test",
      "text": "Test",
      "isActive": false,
      "priority": 1
    }
  ]
}
```
→ Tile wird nicht angezeigt

### 4. Zeitlich begrenzte Tile
```json
{
  "version": 1,
  "tiles": [
    {
      "id": "summer-2026",
      "title": "Sommerfahrplan",
      "text": "Ab 1. Juni neue Routen!",
      "isActive": true,
      "priority": 1,
      "validFrom": "2026-06-01T00:00:00Z",
      "validUntil": "2026-08-31T23:59:59Z"
    }
  ]
}
```
→ Tile wird nur zwischen 1. Juni und 31. August 2026 angezeigt

## Admin-Bereich (Website)

Der Admin-Bereich auf `nextwaveapp.ch` sollte folgende Funktionen bieten:

### Erforderliche Features
1. **Tile erstellen/bearbeiten**
   - Titel, Untertitel, Text eingeben
   - Bild hochladen (mit Preview)
   - Link-URL eingeben
   - Aktiv/Inaktiv Toggle
   - Gültigkeitszeitraum festlegen
   - Priority setzen

2. **Tile-Liste**
   - Alle Tiles anzeigen
   - Status (aktiv/inaktiv) sehen
   - Gültigkeit sehen
   - Sortieren nach Priority
   - Löschen/Bearbeiten

3. **Preview**
   - Vorschau wie die Tile in der App aussieht
   - Test-JSON generieren

4. **Authentifizierung**
   - Login-Schutz für Admin-Bereich
   - Sichere Passwort-Speicherung

### Technische Umsetzung (Vorschlag)
- **Backend**: Node.js/Express oder PHP
- **Datenbank**: JSON-File oder SQLite (einfach) oder PostgreSQL (professionell)
- **Frontend**: React oder Vue.js
- **Bildupload**: Zu `/images/` Ordner mit automatischer Optimierung
- **Deployment**: Vercel, Netlify oder eigener Server

## Testing

### Lokales Testen
1. JSON-File erstellen und auf Server hochladen
2. App-Cache in Settings löschen
3. App neu starten oder Pull-to-Refresh
4. Promo-Tile sollte erscheinen

### Fehlerbehandlung
- Bei Netzwerkfehlern: Keine Tiles angezeigt (kein Crash)
- Bei ungültigem JSON: Fehler geloggt, keine Tiles angezeigt
- Bei fehlendem Bild: Grauer Platzhalter mit Spinner

## Monitoring

Empfohlene Metriken für den Admin-Bereich:
- Anzahl API-Aufrufe pro Tag
- Anzahl aktiver Tiles
- Durchschnittliche Ladezeit
- Fehlerrate

## Sicherheit

### Best Practices
1. **HTTPS verwenden** für alle API-Calls
2. **CORS konfigurieren** um nur App-Zugriffe zu erlauben
3. **Rate Limiting** implementieren (z.B. max. 10 Requests/Minute pro IP)
4. **Input Validation** im Admin-Bereich
5. **XSS-Schutz** für Text-Felder
6. **Bild-Validierung** (Format, Größe, Inhalt)

## Zukünftige Erweiterungen

Mögliche Features für später:
- **A/B Testing**: Mehrere Tiles rotieren
- **Analytics**: Klick-Tracking
- **Personalisierung**: Tiles basierend auf User-Standort
- **Push-Notifications**: Bei neuen Tiles benachrichtigen
- **Multi-Language**: Tiles in verschiedenen Sprachen
