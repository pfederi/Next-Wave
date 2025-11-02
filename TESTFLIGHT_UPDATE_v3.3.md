# Next Wave v3.3 - TestFlight Update 🚀

Hallo liebe Testuser! 👋

Heute gibt es ein wichtiges Update mit massiven Performance-Verbesserungen für die Schiffsnamen-Anzeige. Die App sollte jetzt deutlich flüssiger und professioneller wirken!

## Was ist neu? ✨

### 🎯 Hauptverbesserung: Schiffsnamen ohne Flackern

**Das Problem:**
- Beim Öffnen einer Station erschien kurz "Loading..." bei den Schiffsnamen
- Die Liste "flackerte" mehrmals während des Ladens
- Schiffsnamen für morgen und übermorgen wurden nicht korrekt geladen

**Die Lösung:**
✅ **Keine "Loading..."-Anzeige mehr** - Schiffsnamen erscheinen sofort aus dem Cache  
✅ **Kein UI-Flackern** - Die Liste wird nur einmal aktualisiert, wenn alle Daten bereit sind  
✅ **Korrekte 3-Tages-Daten** - Schiffsnamen für heute, morgen und übermorgen werden jetzt zuverlässig geladen  
✅ **Deutlich schneller** - Daten werden für 24 Stunden gecacht, keine redundanten API-Aufrufe mehr  

### 🔧 Technische Verbesserungen

**Intelligentes Caching:**
- 3-Schicht-Cache-System (API, URLSession, In-Memory)
- Daten werden nur einmal pro Tag vom Server geladen
- Danach sofortiger Zugriff ohne Wartezeit

**Verbessertes Scraping:**
- Neue Puppeteer-basierte Technologie für zuverlässigeres Laden der ZSG-Daten
- Simuliert echte Browser-Interaktion (Klick auf "Nächster Tag" Button)
- Robustere Fehlerbehandlung

**Optimierte UI-Updates:**
- Alle Daten (Wetter + Schiffsnamen) werden im Hintergrund geladen
- UI wird nur einmal aktualisiert, wenn alles fertig ist
- Smooth, professionelle User Experience

## Was solltet ihr testen? 🧪

1. **Schiffsnamen-Anzeige:**
   - Öffnet verschiedene Zürichsee-Stationen
   - Achtet darauf, ob "Loading..." noch erscheint (sollte es nicht!)
   - Prüft, ob die Schiffsnamen sofort angezeigt werden

2. **Mehrfaches Öffnen:**
   - Öffnet die gleiche Station mehrmals hintereinander
   - Die Schiffsnamen sollten beim zweiten Mal instant erscheinen

3. **Tageswechsel:**
   - Schaut euch Abfahrten für morgen und übermorgen an
   - Prüft, ob auch dort Schiffsnamen angezeigt werden

4. **Performance:**
   - Achtet auf die allgemeine Geschwindigkeit der App
   - Gibt es noch irgendwo Verzögerungen oder Flackern?

## Bekannte Einschränkungen ⚠️

- Schiffsnamen nur für Zürichsee-Stationen verfügbar
- Beim ersten App-Start des Tages werden Daten neu geladen (kurze Wartezeit)
- Danach sind alle Daten für 24 Stunden gecacht

## Feedback erwünscht! 💬

Bitte meldet euch, wenn:
- Ihr noch "Loading..." seht
- Die App irgendwo flackert oder ruckelt
- Schiffsnamen fehlen oder falsch sind
- Ihr andere Performance-Probleme bemerkt

Vielen Dank für euer Testing! 🙏

Patrick

---

**Version:** 3.3  
**Build:** [TBD]  
**Datum:** 2. November 2025

