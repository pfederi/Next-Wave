import type { VercelRequest, VercelResponse } from '@vercel/node'
import axios from 'axios'
import * as cheerio from 'cheerio'

interface LakeTemperature {
  name: string
  temperature: number | null
  waterLevel: string | null
}

interface CachedData {
  lakes: LakeTemperature[]
  lastUpdated: string
}

// Mapping von deutschen Seenamen zu den Namen in der App
const lakeNameMapping: Record<string, string> = {
  'Zürichsee': 'Zürichsee',
  'Vierwaldstätter See': 'Vierwaldstättersee',
  'Genfersee': 'Genfersee',
  'Bodensee': 'Bodensee',
  'Thunersee': 'Thunersee',
  'Brienzersee': 'Brienzersee',
  'Zugersee': 'Zugersee',
  'Walensee': 'Walensee',
  'Bielersee': 'Bielersee',
  'Neuenburgersee': 'Neuenburgersee',
  'Murtensee': 'Murtensee',
  'Lago Maggiore': 'Lago Maggiore',
  'Luganersee': 'Luganersee',
  'Sempachersee': 'Sempachersee',
  'Hallwilersee': 'Hallwilersee',
  'Greifensee': 'Greifensee',
  'Pfäffikersee': 'Pfäffikersee',
  'Ägerisee': 'Ägerisee',
  'Baldeggersee': 'Baldeggersee',
  'Sarnersee': 'Sarnersee',
  'Alpnachersee': 'Alpnachersee',
  'Sihlsee': 'Sihlsee',
  'Lauerzersee': 'Lauerzersee',
  'Türlersee': 'Türlersee',
  'Katzensee': 'Katzensee',
  'Lützelsee': 'Lützelsee',
  'Silsersee': 'Silsersee',
  'Silvaplanersee': 'Silvaplanersee',
  'St. Moritzersee': 'St. Moritzersee',
  'Lac de Joux': 'Lac de Joux',
  'Burgäschisee': 'Burgäschisee',
  'Mettmenhaslisee': 'Mettmenhaslisee'
}

async function fetchWaterTemperatures(): Promise<LakeTemperature[]> {
  try {
    const url = 'https://meteonews.ch/de/Cms/D121/seen-in-der-schweiz'
    
    console.log('Fetching water temperatures from meteonews.ch...')
    
    const response = await axios.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'de-DE,de;q=0.9,en;q=0.8',
        'Referer': 'https://meteonews.ch/'
      }
    })

    const $ = cheerio.load(response.data)
    const lakes: LakeTemperature[] = []

    // Die Tabelle mit den Wassertemperaturen finden
    $('table tbody tr').each((_, row) => {
      const $row = $(row)
      const cells = $row.find('td')
      
      if (cells.length >= 2) {
        // Erste Spalte: Gewässername (enthält einen Link)
        const rawName = cells.eq(0).find('a').text().trim()
        
        // Zweite Spalte: Wassertemperatur
        const tempText = cells.eq(1).text().trim()
        
        // Dritte Spalte: Pegel (optional)
        const waterLevel = cells.length >= 3 ? cells.eq(2).text().trim() : null
        
        if (rawName) {
          // Extrahiere Temperatur (z.B. "14 °C" -> 14)
          const tempMatch = tempText.match(/(\d+)\s*°C/)
          const temperature = tempMatch ? parseInt(tempMatch[1], 10) : null
          
          // Verwende das Mapping, um den Namen zu normalisieren
          const mappedName = lakeNameMapping[rawName] || rawName
          
          lakes.push({
            name: mappedName,
            temperature,
            waterLevel
          })
          
          console.log(`Parsed: ${mappedName} - ${temperature}°C`)
        }
      }
    })

    console.log(`Successfully parsed ${lakes.length} lakes`)
    return lakes
    
  } catch (error) {
    console.error('Error fetching water temperatures:', error)
    throw error
  }
}

// Get current date in Swiss timezone
function getCurrentSwissDate(): Date {
  return new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Zurich' }))
}

// Check if data needs to be updated (once per day)
function needsUpdate(lastUpdated: string): boolean {
  const lastUpdate = new Date(lastUpdated)
  const now = getCurrentSwissDate()
  
  // Update if it's a different day
  return lastUpdate.toDateString() !== now.toDateString()
}

// Cache key for the current day
function getCacheKey(): string {
  return `water-temp-${getCurrentSwissDate().toISOString().split('T')[0]}`
}

export default async function handler(
  req: VercelRequest,
  res: VercelResponse
) {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET')
  res.setHeader('Cache-Control', 's-maxage=86400') // Cache for 24 hours
  
  try {
    const cacheKey = getCacheKey()
    
    // Try to get data from cache
    const cachedData = await fetch(`https://${req.headers.host}/_vercel/kv/${cacheKey}`)
      .then(r => r.json())
      .catch(() => null) as CachedData | null

    let result: CachedData

    // If no cached data or needs update, fetch new data
    if (!cachedData || needsUpdate(cachedData.lastUpdated)) {
      console.log('Fetching new water temperature data...')
      const lakes = await fetchWaterTemperatures()
      result = {
        lakes,
        lastUpdated: getCurrentSwissDate().toISOString()
      }
      console.log(`Fetched ${result.lakes.length} lakes`)

      // Store new data in cache
      await fetch(`https://${req.headers.host}/_vercel/kv/${cacheKey}`, {
        method: 'PUT',
        body: JSON.stringify(result),
        headers: {
          'Content-Type': 'application/json'
        }
      }).catch(err => {
        console.warn('Failed to cache data:', err)
      })
    } else {
      console.log('Using cached water temperature data')
      result = cachedData
    }

    return res.status(200).json({
      lakes: result.lakes,
      lastUpdated: result.lastUpdated,
      debug: {
        currentSwissTime: getCurrentSwissDate().toLocaleString('de-CH', { timeZone: 'Europe/Zurich' }),
        lakesCount: result.lakes.length
      }
    })

  } catch (error) {
    console.error('API Error:', error)
    return res.status(500).json({
      lakes: [],
      lastUpdated: getCurrentSwissDate().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
}


