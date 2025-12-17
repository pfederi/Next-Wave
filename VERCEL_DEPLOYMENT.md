# Vercel Deployment Guide

## Cache Warm-Up Cron Job

### Was ist das?

Ein Vercel Cron Job, der **jeden Morgen um 6:00 Uhr** automatisch die populären Stationen vorlädt, um den API-Cache von `transport.opendata.ch` aufzuwärmen.

### Vorteile

- ✅ Garantiert um 6:00 Uhr (nicht abhängig von iOS)
- ✅ Funktioniert für alle User (auch ohne App installiert)
- ✅ Funktioniert auch wenn App geschlossen ist
- ✅ Unabhängig von iOS Background Refresh Einstellungen
- ✅ Server-Cache ist warm, wenn User die App öffnen

### Setup

#### 1. Environment Variable setzen

In Vercel Dashboard:
1. Gehe zu deinem Projekt
2. Settings → Environment Variables
3. Füge hinzu:
   - **Key**: `CRON_SECRET`
   - **Value**: Ein zufälliges Secret (z.B. generiert mit `openssl rand -base64 32`)
   - **Environment**: Production, Preview, Development

```bash
# Generiere ein Secret
openssl rand -base64 32
```

#### 2. Deploy zu Vercel

```bash
# Commit und push
git add .
git commit -m "Add cache warm-up cron job"
git push

# Oder manuell deployen
vercel --prod
```

#### 3. Cron Job verifizieren

Nach dem Deployment:
1. Gehe zu Vercel Dashboard
2. Dein Projekt → Cron Jobs
3. Du solltest sehen: `/api/cache-warmup` mit Schedule `0 6 * * *`

### Testen

#### Manuell triggern (mit CRON_SECRET)

```bash
curl -X GET https://your-app.vercel.app/api/cache-warmup \
  -H "Authorization: Bearer YOUR_CRON_SECRET"
```

#### Erwartete Response

```json
{
  "success": true,
  "stats": {
    "total": 20,
    "success": 20,
    "failed": 0,
    "duration": "4532ms",
    "timestamp": "2025-12-17T06:00:00.000Z"
  }
}
```

### Logs ansehen

1. Vercel Dashboard → Dein Projekt
2. Deployments → Latest
3. Functions → `/api/cache-warmup`
4. Logs

Oder mit Vercel CLI:

```bash
vercel logs
```

### Cron Schedule

```
0 6 * * *
```

- `0` = Minute 0
- `6` = Stunde 6 (6:00 AM)
- `*` = Jeden Tag
- `*` = Jeden Monat
- `*` = Jeden Wochentag

**Bedeutung**: Jeden Tag um 6:00 AM UTC

⚠️ **Wichtig**: Vercel Cron Jobs laufen in **UTC Timezone**!
- 6:00 AM UTC = 7:00 AM CET (Winter)
- 6:00 AM UTC = 8:00 AM CEST (Sommer)

#### Für 6:00 AM Schweizer Zeit (CET/CEST):

**Winter (CET = UTC+1):**
```json
"schedule": "0 5 * * *"  // 5:00 AM UTC = 6:00 AM CET
```

**Sommer (CEST = UTC+2):**
```json
"schedule": "0 4 * * *"  // 4:00 AM UTC = 6:00 AM CEST
```

**Oder: Nutze 5:00 AM UTC als Kompromiss:**
```json
"schedule": "0 5 * * *"  // 6:00 AM Winter, 7:00 AM Sommer
```

### Kosten

#### Vercel Hobby (Kostenlos)
- ✅ Cron Jobs sind **kostenlos** enthalten!
- ✅ Bis zu 100 Cron Job Executions pro Tag
- ✅ Mehr als genug für 1x täglich

#### Vercel Pro ($20/Monat)
- Unbegrenzte Cron Job Executions
- Bessere Performance
- Priority Support

**Für diesen Use Case: Hobby Plan reicht!** 🎉

### Stationen

Die Datei `api/cache-warmup.ts` enthält **alle 300+ Stationen** aus `stations.json`.

**Anzahl Stationen pro See:**
- Zürichsee: 27 Stationen
- Vierwaldstättersee: 32 Stationen
- Bodensee: 24 Stationen
- Lac Léman: 41 Stationen
- Thunersee: 16 Stationen
- Brienzersee: 7 Stationen
- Lago Maggiore: 11 Stationen
- Lago di Lugano: 16 Stationen
- Bielersee: 10 Stationen
- Neuenburgersee: 19 Stationen
- Murtensee: 7 Stationen
- Aare: 6 Stationen
- Zugersee: 10 Stationen
- Walensee: 10 Stationen
- Hallwilersee: 8 Stationen
- Ägerisee: 7 Stationen

**Total: ~300 Stationen**

⚠️ **Wichtig:** Mit 300 Stationen dauert der Cron Job ca. 60 Sekunden (200ms Delay pro Station). Das ist OK für den Vercel Hobby Plan (max 10s pro Request), aber du musst eventuell auf Pro upgraden (max 300s) oder die Anzahl Stationen reduzieren.

### Monitoring

#### Vercel Dashboard
- Cron Jobs → Executions
- Siehe Success/Failure Rate
- Siehe Execution Duration

#### Logs
```bash
# Live logs
vercel logs --follow

# Nur Cron Job logs
vercel logs --follow | grep "cache-warmup"
```

#### Alerts einrichten
1. Vercel Dashboard → Integrations
2. Slack/Discord/Email Notifications
3. Configure für Cron Job Failures

### Troubleshooting

#### Cron Job läuft nicht

**Prüfe:**
1. Ist `vercel.json` korrekt deployed?
2. Ist der Cron Job im Dashboard sichtbar?
3. Sind die Logs im Dashboard sichtbar?

**Fix:**
```bash
# Re-deploy
vercel --prod
```

#### 401 Unauthorized

**Prüfe:**
1. Ist `CRON_SECRET` in Vercel Environment Variables gesetzt?
2. Ist das Secret korrekt in der Authorization Header?

**Fix:**
```bash
# Setze Environment Variable in Vercel Dashboard
# Dann re-deploy
vercel --prod
```

#### Timeout

**Wenn der Cron Job länger als 60 Sekunden braucht:**

In `vercel.json`:
```json
"api/cache-warmup.ts": {
  "memory": 512,
  "maxDuration": 300  // 5 Minuten (nur mit Pro Plan)
}
```

⚠️ **Hobby Plan**: Max 10 Sekunden
⚠️ **Pro Plan**: Max 300 Sekunden (5 Minuten)

**Lösung für Hobby Plan:**
- Reduziere Anzahl Stationen
- Erhöhe Delay zwischen Requests
- Oder: Upgrade zu Pro Plan

### Best Practices

1. **Nicht zu viele Stationen**: 20-30 ist optimal
2. **Delay zwischen Requests**: 200ms verhindert API-Überlastung
3. **Monitoring**: Prüfe regelmäßig die Logs
4. **Error Handling**: Cron Job sollte nicht bei einzelnen Fehlern abbrechen
5. **Timezone beachten**: UTC vs. lokale Zeit

### Kombination mit iOS Background Refresh

**Beste Strategie:**
1. **Vercel Cron Job**: Wärmt Server-Cache um 6:00 AM
2. **iOS Background Refresh**: Wärmt URLCache für individuelle User

**Vorteil:**
- Server-Cache ist warm für alle User
- URLCache ist warm für User mit installierter App
- Beste Performance für alle!

### Weitere Optimierungen

#### Mehrere Zeitpunkte

```json
"crons": [
  {
    "path": "/api/cache-warmup",
    "schedule": "0 6 * * *"  // 6:00 AM
  },
  {
    "path": "/api/cache-warmup",
    "schedule": "0 12 * * *"  // 12:00 PM
  },
  {
    "path": "/api/cache-warmup",
    "schedule": "0 18 * * *"  // 6:00 PM
  }
]
```

#### Nur an Wochentagen

```json
"schedule": "0 6 * * 1-5"  // Montag-Freitag
```

#### Nur am Wochenende

```json
"schedule": "0 6 * * 6,0"  // Samstag & Sonntag
```

### Support

- [Vercel Cron Jobs Dokumentation](https://vercel.com/docs/cron-jobs)
- [Vercel Functions Dokumentation](https://vercel.com/docs/functions)
- [Cron Schedule Generator](https://crontab.guru/)

