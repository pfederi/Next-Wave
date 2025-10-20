import type { VercelRequest, VercelResponse } from '@vercel/node'
import axios from 'axios'
import * as cheerio from 'cheerio'

interface ShipRoute {
  shipName: string
  courseNumber: string
}

interface DailyDeployment {
  date: string
  routes: ShipRoute[]
}

interface CachedData {
  dailyDeployments: DailyDeployment[]
  lastUpdated: string
  debug: {
    daysProcessed: number
    firstDay: string
    lastDay: string
  }
}

function cleanShipName(rawName: string): string {
  const name = rawName.replace(/\n/g, ' ').trim()
  return name.split('Kurs')[0].trim()
}

async function fetchDayData(date: string): Promise<ShipRoute[]> {
  const url = `https://einsatzderschiffe.zsg.ch/schiffeinsatz`
  
  const response = await axios.get(url, {
    params: {
      date,
      timestamp: Date.now()
    },
    headers: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
      'Accept': '*/*',
      'Accept-Language': 'de-DE,de;q=0.8',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': 'https://einsatzderschiffe.zsg.ch/'
    }
  })

  const $ = cheerio.load(response.data)
  const routes: ShipRoute[] = []

  $('.ship').each((_, shipElement) => {
    const $ship = $(shipElement)
    const rawShipName = $ship.find('.legend .title').first().text()
    const shipName = cleanShipName(rawShipName)

    if ($ship.find('.disposition').length > 0) {
      $ship.find('.disposition').each((_, routeElement) => {
        const courseNumber = $(routeElement).find('.cruise span:last-child').first().text().trim()
        
        if (courseNumber && shipName) {
          routes.push({ shipName, courseNumber })
        }
      })
    }
  })

  return routes
}

// Get current date in Swiss timezone
function getCurrentSwissDate(): Date {
  return new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Zurich' }))
}

async function parseZSGWebsite(): Promise<{dailyDeployments: DailyDeployment[], debug?: any}> {
  try {
    const dailyDeployments: DailyDeployment[] = []
    const today = getCurrentSwissDate()
    const processedDates: string[] = []
    
    // Fetch data for today and the next 2 days (total 3 days)
    for (let i = 0; i < 3; i++) {
      // Calculate target date properly in Swiss timezone
      const targetDate = new Date(today.getTime())
      targetDate.setDate(today.getDate() + i)
      
      // Format date as DD.MM.YYYY (required by ZSG website)
      const year = targetDate.getFullYear()
      const month = String(targetDate.getMonth() + 1).padStart(2, '0')
      const day = String(targetDate.getDate()).padStart(2, '0')
      const dateStringForAPI = `${day}.${month}.${year}`
      
      // Also keep YYYY-MM-DD format for storage/debugging
      const dateString = `${year}-${month}-${day}`
      
      try {
        const routes = await fetchDayData(dateStringForAPI)
        dailyDeployments.push({
          date: dateString,
          routes: routes
        })
        processedDates.push(dateString)
        
        // Small delay between requests to be nice to the server
        if (i < 2) {
          await new Promise(resolve => setTimeout(resolve, 500))
        }
      } catch (error) {
        console.error(`Error fetching data for ${dateString}:`, error)
        // Continue with next day even if one fails
        dailyDeployments.push({
          date: dateString,
          routes: []
        })
      }
    }

    const firstDay = processedDates[0] || today.toISOString().split('T')[0]
    const lastDay = processedDates[processedDates.length - 1] || firstDay

    return { 
      dailyDeployments,
      debug: {
        daysProcessed: processedDates.length,
        firstDay: firstDay,
        lastDay: lastDay,
        processedDates: processedDates,
        swissTime: today.toLocaleString('de-CH', { timeZone: 'Europe/Zurich' })
      }
    }
    
  } catch (error) {
    console.error('Error fetching ZSG data:', error)
    throw error
  }
}

// Check if data needs to be updated (once per day)
function needsUpdate(lastUpdated: string): boolean {
  const lastUpdate = new Date(lastUpdated)
  const now = getCurrentSwissDate()
  return lastUpdate.toDateString() !== now.toDateString()
}

// Cache key for the current day
function getCacheKey(): string {
  return `vessel-data-${getCurrentSwissDate().toISOString().split('T')[0]}`
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
    const today = getCurrentSwissDate().toISOString().split('T')[0]
    
    // Try to get data from cache
    const cachedData = await fetch(`https://${req.headers.host}/_vercel/kv/${cacheKey}`).then(r => r.json()).catch(() => null) as CachedData | null

    let result: CachedData

    // If no cached data or needs update, fetch new data
    if (!cachedData || needsUpdate(cachedData.lastUpdated)) {
      const newData = await parseZSGWebsite()
      result = {
        dailyDeployments: newData.dailyDeployments,
        lastUpdated: getCurrentSwissDate().toISOString(),
        debug: newData.debug
      }

      // Store new data in cache
      await fetch(`https://${req.headers.host}/_vercel/kv/${cacheKey}`, {
        method: 'PUT',
        body: JSON.stringify(result),
        headers: {
          'Content-Type': 'application/json'
        }
      })
    } else {
      result = cachedData
    }

    // Return all 3 days of deployments
    return res.status(200).json({
      dailyDeployments: result.dailyDeployments,
      lastUpdated: result.lastUpdated,
      debug: {
        ...result.debug,
        currentSwissTime: getCurrentSwissDate().toLocaleString('de-CH', { timeZone: 'Europe/Zurich' })
      }
    })

  } catch (error) {
    console.error('API Error:', error)
    return res.status(500).json({
      dailyDeployments: [{
        date: getCurrentSwissDate().toISOString().split('T')[0],
        routes: []
      }],
      lastUpdated: getCurrentSwissDate().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
} 