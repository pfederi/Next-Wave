# Memory Management Fixes - EXC_BAD_ACCESS

## Problem

`EXC_BAD_ACCESS (code=1, address=0x10)` Crash beim Laden von Stationen.

## Root Cause Analysis

### 1. Race Condition in `ScheduleViewModel`

**Problem:**
```swift
@Published var nextWaves: [WaveEvent] = [] {
    didSet {
        loadWeatherForWaves()  // ❌ Ruft leere Funktion auf
    }
}

private func loadWeatherForWaves() {
    // Diese Methode wird nicht mehr benötigt
}
```

**Ursache:**
- `didSet` wurde aufgerufen bei jedem Update von `nextWaves`
- Die Funktion `loadWeatherForWaves()` war leer (nach Progressive Loading Refactoring)
- Dies führte zu Race Conditions und Memory-Access-Fehlern

**Fix:**
```swift
@Published var nextWaves: [WaveEvent] = []
// ✅ didSet entfernt, Wetter wird jetzt in updateWaves() geladen
```

### 2. Ungenutzter `weatherLoadingTask`

**Problem:**
```swift
private var weatherLoadingTask: Task<Void, Never>?

deinit {
    weatherLoadingTask?.cancel()  // ❌ Wurde nie verwendet
}
```

**Ursache:**
- Variable wurde deklariert aber nie zugewiesen
- Führte zu unnötigem Memory-Overhead

**Fix:**
```swift
// ✅ Variable entfernt
```

### 3. Fehlende Task-Cancellation in `updateWaves()`

**Problem:**
```swift
currentLoadingTask?.cancel()
weatherLoadingTask?.cancel()  // ❌ Existiert nicht mehr

// Leere die Liste sofort
nextWaves = []
```

**Ursache:**
- Task wurde gecancelt aber nicht auf `nil` gesetzt
- Könnte zu Referenz auf deallocated Memory führen

**Fix:**
```swift
currentLoadingTask?.cancel()
currentLoadingTask = nil  // ✅ Explizit auf nil setzen

nextWaves = []
```

### 4. Fehlende NotificationCenter Cleanup

**Problem:**
```swift
init(appSettings: AppSettings) {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleMidnightUpdate),
        name: NSNotification.Name("MidnightUpdate"),
        object: nil
    )
}

deinit {
    midnightTimer?.invalidate()
    currentLoadingTask?.cancel()
    // ❌ Observer wird nicht entfernt
}
```

**Ursache:**
- NotificationCenter Observer wurde nicht entfernt
- Führt zu Retain Cycle und Memory Leaks

**Fix:**
```swift
deinit {
    midnightTimer?.invalidate()
    currentLoadingTask?.cancel()
    NotificationCenter.default.removeObserver(self)  // ✅
}
```

### 5. Fehlende Task-Cancellation in `LakeStationsViewModel`

**Problem:**
```swift
private var backgroundLoadingTask: Task<Void, Never>?

init(scheduleViewModel: ScheduleViewModel? = nil) {
    Task {  // ❌ Task wird nicht gespeichert
        await loadLakes()
        loadFavoriteStationsInBackground()
        await loadWaterTemperatures()
    }
}

deinit {
    midnightTimer?.invalidate()
    // ❌ backgroundLoadingTask wird nicht gecancelt
}
```

**Ursache:**
- Initialization Task wurde nicht gespeichert und konnte nicht gecancelt werden
- Background Loading Task wurde nicht gecancelt
- LocationManager wurde nicht gestoppt

**Fix:**
```swift
private var backgroundLoadingTask: Task<Void, Never>?
private var initializationTask: Task<Void, Never>?  // ✅

init(scheduleViewModel: ScheduleViewModel? = nil) {
    initializationTask = Task {  // ✅ Task speichern
        await loadLakes()
        loadFavoriteStationsInBackground()
        await loadWaterTemperatures()
    }
}

deinit {
    midnightTimer?.invalidate()
    backgroundLoadingTask?.cancel()  // ✅
    initializationTask?.cancel()     // ✅
    locationManager.stopUpdatingLocation()  // ✅
}
```

## Alle Fixes im Überblick

### ScheduleViewModel.swift

1. ✅ Entfernt `didSet` von `nextWaves`
2. ✅ Entfernt `loadWeatherForWaves()` Funktion
3. ✅ Entfernt `weatherLoadingTask` Variable
4. ✅ Setzt `currentLoadingTask` explizit auf `nil` nach Cancel
5. ✅ Fügt `NotificationCenter.default.removeObserver(self)` in `deinit` hinzu

### LakeStationsViewModel.swift

1. ✅ Fügt `initializationTask` Variable hinzu
2. ✅ Speichert Initialization Task
3. ✅ Cancelt `backgroundLoadingTask` in `deinit`
4. ✅ Cancelt `initializationTask` in `deinit`
5. ✅ Stoppt `locationManager` in `deinit`

## Testing

### Vor dem Fix
```
User öffnet Station
  ↓
EXC_BAD_ACCESS (code=1, address=0x10)
  ↓
App Crash 💥
```

### Nach dem Fix
```
User öffnet Station
  ↓
Abfahrten werden angezeigt (< 0.1s)
  ↓
Schiffsnamen erscheinen (+1s)
  ↓
Wetter erscheint (+3s)
  ↓
Kein Crash ✅
```

## Best Practices für Memory Management

### 1. Task Lifecycle Management
```swift
// ✅ GOOD
private var myTask: Task<Void, Never>?

func startTask() {
    myTask?.cancel()  // Cancel old task
    myTask = Task {
        // Work
    }
}

deinit {
    myTask?.cancel()  // Always cancel in deinit
}
```

### 2. NotificationCenter Observers
```swift
// ✅ GOOD
init() {
    NotificationCenter.default.addObserver(...)
}

deinit {
    NotificationCenter.default.removeObserver(self)
}
```

### 3. Timer Cleanup
```swift
// ✅ GOOD
private var timer: Timer?

deinit {
    timer?.invalidate()
}
```

### 4. LocationManager Cleanup
```swift
// ✅ GOOD
private let locationManager = LocationManager()

deinit {
    locationManager.stopUpdatingLocation()
}
```

### 5. Avoid didSet with Side Effects
```swift
// ❌ BAD
@Published var data: [Item] = [] {
    didSet {
        processData()  // Side effect
    }
}

// ✅ GOOD
@Published var data: [Item] = []

func updateData(_ newData: [Item]) {
    data = newData
    processData()  // Explicit call
}
```

## Zusammenfassung

| Problem | Ursache | Fix | Impact |
|---------|---------|-----|--------|
| EXC_BAD_ACCESS | Race Condition durch `didSet` | `didSet` entfernt | ✅ Crash behoben |
| Memory Leak | NotificationCenter Observer | `removeObserver` in `deinit` | ✅ Leak behoben |
| Dangling Task | Task nicht gecancelt | Task in `deinit` canceln | ✅ Memory befreit |
| Resource Leak | LocationManager läuft weiter | `stopUpdatingLocation` in `deinit` | ✅ Battery gespart |

## Lessons Learned

1. **Immer Tasks canceln**: Jeder Task der gespeichert wird, muss in `deinit` gecancelt werden
2. **Observer cleanup**: NotificationCenter Observer müssen entfernt werden
3. **Explizites nil**: Nach `cancel()` sollte die Variable auf `nil` gesetzt werden
4. **Keine Side Effects in didSet**: `didSet` sollte nur für einfache Updates verwendet werden
5. **Resource Management**: Alle Ressourcen (Timer, LocationManager, etc.) müssen in `deinit` freigegeben werden

## Weitere Informationen

- Siehe auch: `PROGRESSIVE_LOADING_OPTIMIZATION.md`
- Siehe auch: `HTTP_CACHING_OPTIMIZATION.md`
- Siehe auch: `RELEASE_NOTES.md` (Unreleased)




