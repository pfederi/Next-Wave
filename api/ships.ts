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

function cleanShipName(rawName: string): string {
  // Extract only the ship name from the title link
  const name = rawName.replace(/\n/g, ' ').trim()
  // Remove any "Kurs" numbers that might be in the name
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
    // Find the title link and clean the ship name
    const rawShipName = $ship.find('.legend .title').first().text()
    const shipName = cleanShipName(rawShipName)

    // Only process ships that have routes
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

export async function parseZSGWebsite(): Promise<{dailyDeployments: DailyDeployment[], debug?: any}> {
  try {
    const dailyDeployments: DailyDeployment[] = []
    const today = new Date()
    
    // Fetch next 7 days in parallel
    const promises = Array.from({ length: 7 }, (_, i) => {
      const date = new Date(today)
      date.setDate(date.getDate() + i)
      return {
        date: date.toISOString().split('T')[0],
        promise: fetchDayData(date.toISOString().split('T')[0])
      }
    })
    
    const results = await Promise.all(promises.map(({ promise }) => promise))
    
    dailyDeployments.push(...promises.map(({ date }, index) => ({
      date,
      routes: results[index]
    })))

    return { 
      dailyDeployments,
      debug: {
        daysProcessed: dailyDeployments.length,
        firstDay: dailyDeployments[0]?.date,
        lastDay: dailyDeployments[dailyDeployments.length - 1]?.date
      }
    }
    
  } catch (error) {
    console.error('Error fetching ZSG data:', error)
    throw error
  }
}

export default async function handler(
  req: VercelRequest,
  res: VercelResponse
) {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET')
  
  try {
    const result = await parseZSGWebsite()
    return res.status(200).json({
      dailyDeployments: result.dailyDeployments,
      lastUpdated: new Date().toISOString(),
      debug: result.debug
    })

  } catch (error) {
    console.error('API Error:', error)
    return res.status(500).json({
      dailyDeployments: [],
      lastUpdated: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error'
    })
  }
} 