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

Automatisches Hinzufügen von Device Frames zu App Store Screenshots.

## 📋 Voraussetzungen

- **frameme** installiert unter `/tmp/frameme`
- **Device Bezel** vorhanden unter:
  `/Users/federi/Library/CloudStorage/Dropbox/Apps/Bezels/iPhone 17 Pro - Deep Blue - Portrait.png`

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

### 4. Fertig! 🎉
Die Screenshots werden automatisch mit Device Frames versehen und die Originale werden ersetzt.

## 📸 Empfohlene Screenshot-Größen

- **iPhone 17 Pro Max** (6.7"): 1290 x 2796 px
- **iPad Pro 13"** (6.9"): 2048 x 2732 px

## 🎨 Device Bezel ändern

Um einen anderen Device Bezel zu verwenden, bearbeite die Zeile in `frame_screenshots.sh`:
```bash
BEZEL_PATH="/Users/federi/Library/CloudStorage/Dropbox/Apps/Bezels/[DEIN-BEZEL].png"
```

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

