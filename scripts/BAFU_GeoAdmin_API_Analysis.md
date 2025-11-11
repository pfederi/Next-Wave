# BAFU GeoAdmin API - Komplette Analyse

## 🎯 HAUPTERKENNTNISS

Die offizielle Schweizer **GeoAdmin API** ([api3.geo.admin.ch](https://api3.geo.admin.ch/index.html)) bietet Zugriff auf BAFU-Hydrodaten!

---

## 📊 Verfügbare Hydrologische Layer

### Wichtigste Layer für Next Wave:

| Layer ID | Name | Beschreibung |
|----------|------|--------------|
| `ch.bafu.hydroweb-messstationen_zustand` | Lage Fliessgewässer und Seen | **Aktueller Zustand** aller Messstationen |
| `ch.bafu.hydroweb-messstationen_temperatur` | Wassertemperatur der Flüsse | Temperatur-Messstationen |
| `ch.bafu.hydroweb-messstationen_vorhersage` | Vorhersagen | **Vorhersage-Daten** |
| `ch.bafu.hydrologie-hydromessstationen` | Hydrologische Messstationen | Alle BAFU Messstationen |

### Weitere relevante Layer:
- `ch.bafu.hydrologie-wassertemperaturmessstationen`
- `ch.bafu.hydroweb-messstationen_grundwasser`
- `ch.bafu.hydroweb-warnkarte_national`

---

## 🗺️ GeoJSON Datenquellen

### Station-Metadaten (ohne aktuelle Messwerte):

```bash
# Alle Seen und Flüsse mit Status
https://data.geo.admin.ch/ch.bafu.hydroweb-messstationen_zustand/ch.bafu.hydroweb-messstationen_zustand_de.json

# Temperatur-Messstationen
https://data.geo.admin.ch/ch.bafu.hydroweb-messstationen_temperatur/ch.bafu.hydroweb-messstationen_temperatur_de.json
```

---

## 📍 Seen-Stationen für Next Wave

### Alle Swiss Lakes mit BAFU Station IDs:

| See | Station ID | Stationsname | Link |
|-----|------------|--------------|------|
| **Zürichsee** | 2209 | Zürichsee - Zürich | [Link](https://www.hydrodaten.admin.ch/de/2209.html) |
| **Zürichsee** | 2014 | Zürichsee - Schmerikon | [Link](https://www.hydrodaten.admin.ch/de/2014.html) |
| **Vierwaldstättersee** | 2207 | Vierwaldstättersee - Luzern | [Link](https://www.hydrodaten.admin.ch/de/2207.html) |
| **Vierwaldstättersee** | 2025 | Vierwaldstättersee - Brunnen | [Link](https://www.hydrodaten.admin.ch/de/2025.html) |
| **Thunersee** | 2093 | Thunersee - Spiez | [Link](https://www.hydrodaten.admin.ch/de/2093.html) |
| **Brienzersee** | 2023 | Brienzersee - Ringgenberg | [Link](https://www.hydrodaten.admin.ch/de/2023.html) |
| **Zugersee** | 2017 | Zugersee - Zug | [Link](https://www.hydrodaten.admin.ch/de/2017.html) |
| **Genfersee** | 2009 | Genfersee - Geneva | [Link](https://www.hydrodaten.admin.ch/de/2009.html) |
| **Bodensee** | ? | ? | TBD |
| **Lago Maggiore** | 2006 | Lago Maggiore - Locarno | [Link](https://www.hydrodaten.admin.ch/de/2006.html) |
| **Luganersee** | 2012 | Luganersee - Melide | [Link](https://www.hydrodaten.admin.ch/de/2012.html) |
| **Bielersee** | 2021 | Bielersee - Nidau | [Link](https://www.hydrodaten.admin.ch/de/2021.html) |
| **Neuenburgersee** | 2020 | Neuenburgersee - Neuenburg | [Link](https://www.hydrodaten.admin.ch/de/2020.html) |
| **Murtensee** | 2030 | Murtensee - Muntelier | [Link](https://www.hydrodaten.admin.ch/de/2030.html) |
| **Walensee** | 2304 | Walensee - Weesen | [Link](https://www.hydrodaten.admin.ch/de/2304.html) |
| **Hallwilersee** | 2416 | (über Aabach) | [Link](https://www.hydrodaten.admin.ch/de/2416.html) |
| **Ägerisee** | ? | ? | TBD |

---

## 🔧 API Nutzung

### 1. Alle Stationen abrufen:

```bash
curl "https://data.geo.admin.ch/ch.bafu.hydroweb-messstationen_zustand/ch.bafu.hydroweb-messstationen_zustand_de.json" | jq '.'
```

### 2. Nur Seen filtern:

```bash
curl -s "https://data.geo.admin.ch/ch.bafu.hydroweb-messstationen_zustand/ch.bafu.hydroweb-messstationen_zustand_de.json" \
  | jq '.features[] | select(.properties["w-typ"] == "See")'
```

### 3. Zürichsee-Stationen finden:

```bash
curl -s "https://data.geo.admin.ch/ch.bafu.hydroweb-messstationen_zustand/ch.bafu.hydroweb-messstationen_zustand_de.json" \
  | jq '.features[] | select(.properties.name | contains("Zürich"))'
```

### 4. Swift Integration (Beispiel):

```swift
struct BAFUStation: Codable {
    let id: String
    let properties: Properties
    let geometry: Geometry
    
    struct Properties: Codable {
        let name: String
        let wTyp: String // "See" oder "Fliessgewässer"
        let quantClass: Int
        
        enum CodingKeys: String, CodingKey {
            case name
            case wTyp = "w-typ"
            case quantClass = "quant-class"
        }
    }
    
    struct Geometry: Codable {
        let coordinates: [Double]
        let type: String
    }
}

// API Call
let url = URL(string: "https://data.geo.admin.ch/ch.bafu.hydroweb-messstationen_zustand/ch.bafu.hydroweb-messstationen_zustand_de.json")!

URLSession.shared.dataTask(with: url) { data, response, error in
    guard let data = data else { return }
    
    let decoder = JSONDecoder()
    if let geojson = try? decoder.decode(GeoJSONFeatureCollection.self, from: data) {
        // Filter Seen
        let lakes = geojson.features.filter { $0.properties.wTyp == "See" }
        print("Gefunden: \(lakes.count) Seen")
    }
}.resume()
```

---

## ⚠️ WICHTIG: Limitierungen

### Was die GeoJSON-Dateien ENTHALTEN:
- ✅ Station IDs
- ✅ Koordinaten
- ✅ Namen
- ✅ Gewässertyp (See/Fluss)
- ✅ Eigentümer (BAFU)
- ✅ Links zu detail-Seiten

### Was die GeoJSON-Dateien NICHT ENTHALTEN:
- ❌ Aktuelle Messwerte (Wasserstand, Temperatur)
- ❌ Historische Daten
- ❌ Vorhersagen
- ❌ Zeitstempel der letzten Messung

---

## 🔍 Nächste Schritte: Messwerte abrufen

### Option A: Proxyman Analysis (EMPFOHLEN)
1. Proxyman öffnen
2. Browser → https://www.hydrodaten.admin.ch/de/2209.html (Zürichsee)
3. In Proxyman nach API-Calls suchen:
   - Wahrscheinlich: `GET /api/stations/2209/measurements`
   - Oder: WebSocket-Verbindung
   - Oder: GraphQL Query

### Option B: Web Scraping (nicht ideal)
- HTML der Station-Seite parsen
- JavaScript-Variablen extrahieren
- ⚠️ Kann bei Updates brechen

### Option C: BAFU kontaktieren
- Email: info@bafu.admin.ch
- Frage nach offizieller REST API für aktuelle Messwerte
- Verweis auf GeoAdmin API-Dokumentation

### Option D: Alplakes-Team fragen
- Email: james.runnalls@eawag.ch
- Sie haben das Problem bereits gelöst
- Möglicherweise bereit, Lösung zu teilen

---

## 📝 GeoAdmin API Dokumentation

### Offizielle Links:
- **Hauptdokumentation**: https://api3.geo.admin.ch/index.html
- **REST Services**: https://api3.geo.admin.ch/services/sdiservices.html
- **FAQ**: https://api3.geo.admin.ch/doc/faq.html
- **Forum**: http://groups.google.com/group/geoadmin-api

### Nutzungsbedingungen:
- ✅ Kostenlos
- ✅ HTTPS required
- ✅ Fair Use Policy beachten
- ⚠️ Kein intensives Web Scraping via Bots
- 📄 Terms: www.geo.admin.ch/terms-of-use

### Update-Intervall:
- `updateDelay: 300000` = 5 Minuten (300'000ms)
- Daten werden alle 5 Minuten aktualisiert

---

## 🚀 Empfehlung für Next Wave

### Zwei-Stufen-Ansatz:

#### Phase 1: Alplakes Temperature API (JETZT)
```
✅ Sofort verfügbar
✅ Gut dokumentiert
✅ Temperatur + Vorhersagen
✅ Viele Seen abgedeckt
```

#### Phase 2: BAFU Wasserstand (NACH Proxyman-Analyse)
```
🔍 API-Endpunkt via Proxyman herausfinden
📊 Wasserstand + Vorhersagen
📈 Hochwasser-Warnungen
✅ Offizielle Schweizer Daten
```

---

## 📊 Vergleich: Datenquellen

| Feature | Alplakes API | GeoAdmin/BAFU | MeteoNews |
|---------|-------------|---------------|-----------|
| Wassertemperatur | ✅ Excellent | ✅ Gut | ✅ Gut |
| Temperatur-Vorhersage | ✅ Ja (3-5 Tage) | ❌ Nein | ❌ Nein |
| Wasserstand | ❌ Nein | ✅ Ja | ✅ Ja |
| Wasserstand-Vorhersage | ❌ Nein | ✅ Ja | ❓ ? |
| Hochwasser-Warnungen | ❌ Nein | ✅ Ja | ❓ ? |
| API-Dokumentation | ✅ Excellent | ⚠️ Teilweise | ❓ ? |
| Kosten | ✅ Gratis | ✅ Gratis | ❓ ? |
| Update-Frequenz | 3h | 5 min | ❓ ? |

---

## 🎯 Nächste Schritte

### Immediate Actions:
1. ✅ GeoAdmin API für Station-Metadaten nutzen
2. 🔍 Proxyman-Analyse für Messwerte-API
3. 📧 Alplakes-Team kontaktieren

### Development:
1. Alplakes Temperatur-API integrieren
2. GeoAdmin Station-Metadaten integrieren
3. BAFU Messwert-API integrieren (nach Proxyman)

### Documentation:
1. API-Calls dokumentieren
2. Error Handling planen
3. Fallback-Strategien definieren

---

**Erstellt am:** 2025-11-11  
**Status:** In Progress  
**Nächster Review:** Nach Proxyman-Analyse

