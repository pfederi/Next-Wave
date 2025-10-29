# Next Wave API Documentation

## Water Temperature API

### Endpoint
`GET /api/water-temperature`

### Description
Scrapes water temperature data from meteonews.ch for Swiss lakes once per day and caches the results.

### Response Format
```json
{
  "lakes": [
    {
      "name": "Zürichsee",
      "temperature": 14,
      "waterLevel": "405.96 m.ü.M."
    },
    {
      "name": "Vierwaldstättersee",
      "temperature": 13,
      "waterLevel": "433.53 m.ü.M."
    }
  ],
  "lastUpdated": "2025-10-26T10:30:00.000Z",
  "debug": {
    "currentSwissTime": "26.10.2025, 12:30:00",
    "lakesCount": 32
  }
}
```

### Caching Strategy
- Data is cached for 24 hours (one day)
- Cache key includes the current date in Swiss timezone
- Automatic cache invalidation at midnight Swiss time
- If cache is unavailable or expired, fresh data is fetched from meteonews.ch

### Supported Lakes
The API tracks water temperatures for the following Swiss lakes:
- Zürichsee
- Vierwaldstättersee
- Genfersee
- Bodensee
- Thunersee
- Brienzersee
- Zugersee
- Walensee
- Bielersee
- Neuenburgersee
- Murtensee
- Lago Maggiore
- Luganersee
- Sempachersee
- Hallwilersee
- Greifensee
- Pfäffikersee
- Ägerisee
- Baldeggersee
- Sarnersee
- Alpnachersee
- Sihlsee
- Lauerzersee
- Türlersee
- Katzensee
- Lützelsee
- Silsersee
- Silvaplanersee
- St. Moritzersee
- Lac de Joux
- Burgäschisee
- Mettmenhaslisee

### Error Handling
If the API fails to fetch data, it returns:
```json
{
  "lakes": [],
  "lastUpdated": "2025-10-26T10:30:00.000Z",
  "error": "Error message"
}
```

### Usage in iOS App
The iOS app uses the `WaterTemperatureAPI` class to fetch water temperatures:

```swift
// Fetch all water temperatures
let temperatures = try await WaterTemperatureAPI.shared.getWaterTemperatures()

// Get temperature for a specific lake
let temp = try await WaterTemperatureAPI.shared.getTemperature(for: "Zürichsee")

// Preload data (called at app startup)
await WaterTemperatureAPI.shared.preloadData()
```

### Data Source
Water temperature data is sourced from [MeteoNews](https://meteonews.ch/de/Cms/D121/seen-in-der-schweiz).

---

## Ship Deployment API

### Endpoint
`GET /api/ships`

### Description
Scrapes ship deployment data from ZSG (Zürichsee-Schifffahrtsgesellschaft) for the next 3 days.

### Response Format
```json
{
  "dailyDeployments": [
    {
      "date": "2025-10-26",
      "routes": [
        {
          "shipName": "Stadt Zürich",
          "courseNumber": "1"
        }
      ]
    }
  ],
  "lastUpdated": "2025-10-26T10:30:00.000Z",
  "debug": {
    "daysProcessed": 3,
    "firstDay": "2025-10-26",
    "lastDay": "2025-10-28",
    "currentSwissTime": "26.10.2025, 12:30:00"
  }
}
```

### Caching Strategy
- Data is cached for 24 hours (one day)
- Cache key includes the current date in Swiss timezone
- Automatic cache invalidation at midnight Swiss time

### Data Source
Ship deployment data is sourced from [ZSG Schiffeinsatz](https://einsatzderschiffe.zsg.ch/).


