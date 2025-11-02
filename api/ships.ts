import type { VercelRequest, VercelResponse } from '@vercel/node'
import puppeteer from 'puppeteer-core'
import chromium from '@sparticuz/chromium'
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
    processedDates?: string[]
    swissTime?: string
    detailedStats?: Array<{
      date: string
      routesFound: number
      shipsFound: number
      htmlLength: number
    }>
  }
}

function cleanShipName(rawName: string): string {
  const name = rawName.replace(/\n/g, ' ').trim()
  return name.split('Kurs')[0].trim()
}

async function fetchDayData(date: string, dayOffset: number): Promise<{routes: ShipRoute[], stats: {shipsFound: number, htmlLength: number}}> {
  const url = `https://einsatzderschiffe.zsg.ch/`
  
  console.log(`📡 Fetching data for date: ${date} (day offset: ${dayOffset})`)
  
  let browser: Awaited<ReturnType<typeof puppeteer.launch>> | null = null
  
  try {
    // Launch browser with chromium
    browser = await puppeteer.launch({
      args: chromium.args,
      defaultViewport: chromium.defaultViewport,
      executablePath: await chromium.executablePath(),
      headless: chromium.headless,
    })
    
    const page = await browser.newPage()
    
    // Navigate to the page
    await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 })
    
    console.log(`  ✅ Page loaded`)
    
    // Click the "next day" arrow for each day offset
    for (let i = 0; i < dayOffset; i++) {
      console.log(`  🔄 Clicking next day arrow (${i + 1}/${dayOffset})`)
      
      // Wait for the next button and click it
      await page.waitForSelector('.datepicker-next', { timeout: 10000 })
      await page.click('.datepicker-next')
      
      // Wait for the content to update (wait for network to be idle)
      await new Promise(resolve => setTimeout(resolve, 1500)) // Give it time to load
      
      console.log(`  ✅ Clicked and waited for content to update`)
    }
    
    // Get the HTML content
    const htmlContent = await page.content()
    const htmlLength = htmlContent.length
    
    console.log(`📄 HTML length for ${date}: ${htmlLength} chars`)
    
    // Parse with cheerio
    const $ = cheerio.load(htmlContent)
    const routes: ShipRoute[] = []
    const shipsFound = $('.ship').length
    
    console.log(`🚢 Found ${shipsFound} ship elements`)
    
    $('.ship').each((shipIndex, shipElement) => {
      const $ship = $(shipElement)
      const rawShipName = $ship.find('.legend .title').first().text()
      const shipName = cleanShipName(rawShipName)
      
      console.log(`  Ship ${shipIndex + 1}: "${shipName}"`)
      
      const dispositions = $ship.find('.disposition')
      console.log(`    Found ${dispositions.length} dispositions`)
      
      if (dispositions.length > 0) {
        dispositions.each((dispIndex, routeElement) => {
          const $route = $(routeElement)
          
          // Versuche verschiedene Selektoren für die Kursnummer
          let courseNumber = $route.find('.cruise span:last-child').first().text().trim()
          
          // Fallback: Versuche alle spans in .cruise
          if (!courseNumber) {
            const allSpans = $route.find('.cruise span')
            console.log(`      Disposition ${dispIndex + 1}: Found ${allSpans.length} spans in .cruise`)
            allSpans.each((spanIndex, span) => {
              const text = $(span).text().trim()
              console.log(`        Span ${spanIndex + 1}: "${text}"`)
            })
            // Nimm den letzten span mit Inhalt
            courseNumber = allSpans.last().text().trim()
          }
          
          console.log(`      Disposition ${dispIndex + 1}: Course="${courseNumber}"`)
          
          if (courseNumber && shipName) {
            routes.push({ shipName, courseNumber })
            console.log(`      ✅ Added route: ${shipName} -> ${courseNumber}`)
          } else {
            console.log(`      ⚠️ Skipped: shipName="${shipName}", courseNumber="${courseNumber}"`)
          }
        })
      }
    })
    
    console.log(`✅ Total routes found for ${date}: ${routes.length}`)
    return { routes, stats: { shipsFound, htmlLength } }
    
  } finally {
    if (browser) {
      await browser.close()
    }
  }
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
    const detailedStats: Array<{date: string, routesFound: number, shipsFound: number, htmlLength: number}> = []
    
    console.log('Starting to fetch ship data for 3 days...')
    
    // Fetch data for today and the next 2 days (total 3 days)
    // We now use a single browser session and click through the days
    for (let i = 0; i < 3; i++) {
      // Calculate target date properly in Swiss timezone
      const targetDate = new Date(today.getTime())
      targetDate.setDate(today.getDate() + i)
      
      // Format date as DD.MM.YYYY for display
      const year = targetDate.getFullYear()
      const month = String(targetDate.getMonth() + 1).padStart(2, '0')
      const day = String(targetDate.getDate()).padStart(2, '0')
      const dateStringForAPI = `${day}.${month}.${year}`
      
      // Also keep YYYY-MM-DD format for storage/debugging
      const dateString = `${year}-${month}-${day}`
      
      console.log(`Fetching day ${i + 1}/3: ${dateStringForAPI} (stored as ${dateString}, offset=${i})`)
      
      try {
        // Pass the day offset (0 for today, 1 for tomorrow, 2 for day after)
        const result = await fetchDayData(dateStringForAPI, i)
        console.log(`Successfully fetched ${result.routes.length} routes for ${dateStringForAPI}`)
        dailyDeployments.push({
          date: dateString,
          routes: result.routes
        })
        processedDates.push(dateString)
        detailedStats.push({
          date: dateString,
          routesFound: result.routes.length,
          shipsFound: result.stats.shipsFound,
          htmlLength: result.stats.htmlLength
        })
        
        // No delay needed between requests since each one launches its own browser
      } catch (error) {
        console.error(`Error fetching data for ${dateStringForAPI} (${dateString}):`, error)
        // Continue with next day even if one fails
        // Still add to deployments with empty routes
        dailyDeployments.push({
          date: dateString,
          routes: []
        })
        // Also add to processedDates to track that we tried
        processedDates.push(dateString)
        detailedStats.push({
          date: dateString,
          routesFound: 0,
          shipsFound: 0,
          htmlLength: 0
        })
      }
    }
    
    console.log(`Finished fetching. Processed ${processedDates.length} days:`, processedDates)
    console.log('Detailed stats:', detailedStats)

    const firstDay = processedDates[0] || today.toISOString().split('T')[0]
    const lastDay = processedDates[processedDates.length - 1] || firstDay

    return { 
      dailyDeployments,
      debug: {
        daysProcessed: processedDates.length,
        firstDay: firstDay,
        lastDay: lastDay,
        processedDates: processedDates,
        swissTime: today.toLocaleString('de-CH', { timeZone: 'Europe/Zurich' }),
        detailedStats: detailedStats
      }
    }
    
  } catch (error) {
    console.error('Error fetching ZSG data:', error)
    throw error
  }
}

// Check if data needs to be updated (once per day OR if format changed)
function needsUpdate(lastUpdated: string, cachedData?: CachedData): boolean {
  const lastUpdate = new Date(lastUpdated)
  const now = getCurrentSwissDate()
  
  // Update if it's a different day
  if (lastUpdate.toDateString() !== now.toDateString()) {
    return true
  }
  
  // Also update if we don't have 3 days of data (old cache format)
  if (cachedData && cachedData.dailyDeployments.length < 3) {
    console.log('Cache has less than 3 days, forcing update')
    return true
  }
  
  return false
}

// Cache key for the current day (v2 for 3-day support)
function getCacheKey(): string {
  return `vessel-data-v2-${getCurrentSwissDate().toISOString().split('T')[0]}`
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
    if (!cachedData || needsUpdate(cachedData.lastUpdated, cachedData)) {
      console.log('Fetching new data from ZSG website...')
      const newData = await parseZSGWebsite()
      result = {
        dailyDeployments: newData.dailyDeployments,
        lastUpdated: getCurrentSwissDate().toISOString(),
        debug: newData.debug
      }
      console.log(`Fetched ${result.dailyDeployments.length} days of data`)

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
        currentSwissTime: getCurrentSwissDate().toLocaleString('de-CH', { timeZone: 'Europe/Zurich' }),
        cacheUsed: cachedData !== null && !needsUpdate(cachedData.lastUpdated, cachedData)
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