# Screenshot Tools

Zwei Scripts für einfaches Screenshot-Management:
1. **capture_screenshots.sh** - Interaktives Tool (empfohlen!)
2. **frame_screenshots.sh** - Batch-Framing

---

## 🚀 Script 1: capture_screenshots.sh (EMPFOHLEN)

**Automatischer Workflow: Simulator öffnen → Screenshots machen → Automatisch framen**

### Verwendung

```bash
./scripts/capture_screenshots.sh
```

### Was passiert:

1. **Geräteauswahl**: Wähle zwischen iPhone 17 Pro, iPad Air 13" (M3) oder Apple Watch Ultra 3 (49mm)
2. **App wird gebaut** für den ausgewählten Simulator
3. **Simulator öffnet automatisch**
4. **Location wird gesetzt** (Zürich Bürkliplatz)
5. **Next Wave App wird automatisch geöffnet**
6. **Du machst Screenshots** mit Cmd+S
7. **Automatisches Framing** im Hintergrund
8. **Fertig!** - Screenshots sind in `Screenshots/en-US/`

### Features:

- ✅ Baut die App automatisch für den ausgewählten Simulator
- ✅ Öffnet automatisch den richtigen Simulator
- ✅ Startet die Next Wave App automatisch
- ✅ Setzt Location für realistische Daten (Zürich Bürkliplatz)
- ✅ Überwacht Screenshots in Echtzeit
- ✅ Framed automatisch beim Erstellen mit frameme
- ✅ Gibt Screenshots sinnvolle Namen
- ✅ Verschiebt Screenshots direkt in den Zielordner (keine Desktop-Unordnung!)

---

## 📦 Script 2: frame_screenshots.sh

**Automatisches Framing von bestehenden Screenshots mit Device-Erkennung**

Dieses Script analysiert die Dimensionen deiner Screenshots und wählt automatisch den richtigen Bezel:
- **iPhone 17 Pro**: 1290x2796px → Deep Blue Frame
- **iPad Air 13-inch**: 2048x2732px → Space Gray Frame  
- **Apple Watch Ultra 3**: 416x496px → Black Ocean Band Frame

## 🚀 Verwendung

### 1. Screenshots erstellen
Erstelle deine Screenshots manuell:
- Im **Simulator**: Cmd+S
- Auf **Device**: Screenshots machen und via AirDrop auf Mac übertragen

### 2. Screenshots in Ordner kopieren
Kopiere alle Screenshots nach:
```
Screenshots/en-US/
```

Beispiel:
```
Screenshots/en-US/
├── 1-home.png
├── 2-departure-list.png
├── 3-settings.png
└── 4-watch.png
```

### 3. Script ausführen
```bash
./scripts/frame_screenshots.sh
```

Das Script:
- ✅ **Erkennt automatisch das Device** anhand der Dimensionen
- ✅ Wählt den passenden Bezel (iPhone, iPad oder Watch)
- ✅ Framed den Screenshot
- ✅ Löscht das Original
- ✅ Speichert als `*-framed.png`

### 4. Beispiel-Output
```
→ Framing: 0x0ss.png
  Device: Apple Watch Ultra 3
  ✓ Framed successfully: 0x0ss-framed.png

→ Framing: IMG_1234.png
  Device: iPhone 17 Pro
  ✓ Framed successfully: IMG_1234-framed.png
```

### 5. Fertig! 🎉
Alle Screenshots sind jetzt geframed und bereit für den App Store Upload!

## 📸 Empfohlene Screenshot-Größen

- **iPhone 17 Pro Max** (6.7"): 1290 x 2796 px
- **iPad Pro 13"** (6.9"): 2048 x 2732 px

## 🎨 Unterstützte Geräte

Das Script erkennt automatisch folgende Geräte:

| Device | Auflösung | Bezel |
|--------|-----------|-------|
| iPhone 17 Pro | 1290 x 2796 px | Deep Blue - Portrait |
| iPad Air 13-inch | 2048 x 2732 px | Space Gray - Portrait |
| Apple Watch Ultra 3 | 416 x 496 px | Black + Ocean Band Black |

**Neue Geräte hinzufügen:**  
Bearbeite die `detect_device()` Funktion in `frame_screenshots.sh` und füge die Dimensionen und den Bezel-Pfad hinzu.

## 🔧 Troubleshooting

### "frameme not found"
Stelle sicher, dass frameme installiert ist:
```bash
ls -la /tmp/frameme
```

### "Device bezel not found"
Prüfe, ob der Bezel-Pfad korrekt ist:
```bash
ls -la "/Users/federi/Library/CloudStorage/Dropbox/Apps/Bezels/iPhone 17 Pro - Deep Blue - Portrait.png"
```

## ⚡ Workflow

1. **Screenshots machen** (Simulator oder Device)
2. **In `Screenshots/en-US/` kopieren**
3. **Script ausführen**: `./scripts/frame_screenshots.sh`
4. **Fertig** - Screenshots sind geframed und bereit für App Store Connect!

Viel schneller und einfacher als Fastlane Snapshot! 🚀

