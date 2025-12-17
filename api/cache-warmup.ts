import type { VercelRequest, VercelResponse } from '@vercel/node';

/**
 * Cache Warm-Up Endpoint
 * 
 * This endpoint is called by Vercel Cron Job every morning at 6:00 AM
 * to warm up the transport.opendata.ch API cache for popular stations.
 * 
 * This ensures that when users open the app in the morning, the API
 * responds quickly because its cache is already warm.
 */

// All stations from stations.json
// These stations will be pre-loaded every morning to warm up the API cache
const ALL_STATIONS = [
  // Zürichsee
  { id: '8503651', name: 'Zürich Bürkliplatz (See)' },
  { id: '8503681', name: 'Zürich Wollishofen (See)' },
  { id: '8503677', name: 'Kilchberg ZH (See)' },
  { id: '8503675', name: 'Rüschlikon (See)' },
  { id: '8503674', name: 'Thalwil (See)' },
  { id: '8503673', name: 'Oberrieden (See)' },
  { id: '8503672', name: 'Horgen (See)' },
  { id: '8503671', name: 'Halbinsel Au' },
  { id: '8503670', name: 'Wädenswil (See)' },
  { id: '8503669', name: 'Richterswil (See)' },
  { id: '8503680', name: 'Pfäffikon SZ (See)' },
  { id: '8503683', name: 'Altendorf Seestatt' },
  { id: '8503648', name: 'Lachen SZ (See)' },
  { id: '8503647', name: 'Schmerikon (See)' },
  { id: '8503667', name: 'Rapperswil SG (See)' },
  { id: '8503668', name: 'Insel Ufenau' },
  { id: '8503666', name: 'Uerikon (See)' },
  { id: '8503665', name: 'Stäfa (See)' },
  { id: '8503664', name: 'Männedorf (See)' },
  { id: '8503661', name: 'Meilen (See)' },
  { id: '8503659', name: 'Erlenbach ZH (See)' },
  { id: '8503682', name: 'Küsnacht ZH Heslibach' },
  { id: '8503657', name: 'Küsnacht ZH (See)' },
  { id: '8503655', name: 'Zollikon (See)' },
  { id: '8505332', name: 'Zürich Tiefenbrunnen (See)' },
  { id: '8503653', name: 'Zürichhorn (See)' },
  
  // Vierwaldstättersee
  { id: '8508505', name: 'Luzern Schweizerhofquai' },
  { id: '8508459', name: 'Verkehrshaus-Lido' },
  { id: '8508489', name: 'Kehrsiten-Bürgenstock' },
  { id: '8508462', name: 'Hertenstein (See)' },
  { id: '8508463', name: 'Weggis' },
  { id: '8508464', name: 'Vitznau' },
  { id: '8508465', name: 'Ennetbürgen (See)' },
  { id: '8508466', name: 'Buochs (See)' },
  { id: '8508467', name: 'Beckenried (See)' },
  { id: '8530722', name: 'Landungssteg Gersau Förstli (Fähre)' },
  { id: '8508469', name: 'Landungssteg SGV Treib' },
  { id: '8508470', name: 'Landungssteg SGV Brunnen' },
  { id: '8508471', name: 'Rütli' },
  { id: '8508472', name: 'Sisikon (See)' },
  { id: '8508473', name: 'Tellsplatte' },
  { id: '8508474', name: 'Landungssteg SGV Bauen' },
  { id: '8508475', name: 'Landungssteg SGV Isleten-Isenthal' },
  { id: '8508476', name: 'Flüelen (See)' },
  { id: '8508478', name: 'Kastanienbaum (See)' },
  { id: '8508480', name: 'Kehrsiten Dorf' },
  { id: '8508481', name: 'Hergiswil (See)' },
  { id: '8508483', name: 'Stansstad (See)' },
  { id: '8508503', name: 'Alpnachstad (See)' },
  { id: '8508504', name: 'Meggenhorn' },
  { id: '8508485', name: 'Hermitage' },
  { id: '8508479', name: 'Tribschen' },
  { id: '8508486', name: 'Merlischachen (See)' },
  { id: '8508487', name: 'Greppen' },
  { id: '8508488', name: 'Küssnacht am Rigi (See)' },
  { id: '8530833', name: 'Landungssteg SGV Seedorf UR' },
  
  // Bodensee
  { id: '8506467', name: 'Lindau (Bodensee)' },
  { id: '8530830', name: 'Staad SG Hafenmole' },
  { id: '8506113', name: 'Rorschach Hafen (See)' },
  { id: '8506111', name: 'Horn (See)' },
  { id: '8506110', name: 'Arbon (See)' },
  { id: '8506112', name: 'Romanshorn (See)' },
  { id: '8530835', name: 'Uttwil (See)' },
  { id: '8595982', name: 'Güttingen (See)' },
  { id: '8530834', name: 'Altnau (See)' },
  { id: '8530720', name: 'Bottighofen (See)' },
  { id: '8506165', name: 'Kreuzlingen Hafen (See)' },
  { id: '8014587', name: 'Konstanz Hafen' },
  { id: '8506163', name: 'Gottlieben (Schifflände)' },
  { id: '8506162', name: 'Ermatingen (See)' },
  { id: '8506160', name: 'Mannenbach (See)' },
  { id: '8506159', name: 'Berlingen (See)' },
  { id: '8506157', name: 'Steckborn (See)' },
  { id: '8506155', name: 'Mammern (See)' },
  { id: '8506154', name: 'Oehningen' },
  { id: '8506153', name: 'Stein am Rhein (Schifflände)' },
  { id: '8506156', name: 'Wangen (Bodensee)' },
  { id: '8506189', name: 'Hemmenhofen' },
  { id: '8506158', name: 'Gaienhofen' },
  
  // Lac Léman
  { id: '8501311', name: 'Genève-Eaux-Vives (lac)' },
  { id: '8530700', name: 'Genève-Quai Gustave Ador (lac)' },
  { id: '8501236', name: 'Genève-Jardin-Anglais (lac)' },
  { id: '8530699', name: 'Genève-Molard (lac)' },
  { id: '8501237', name: 'Genève-Mt-Blanc' },
  { id: '8501238', name: 'Genève-Pâquis (lac)' },
  { id: '8530707', name: 'Genève-Pâquis SMGN' },
  { id: '8530701', name: 'Genève-De-Châteaubriand (lac)' },
  { id: '8501232', name: 'Bellevue GE (lac)' },
  { id: '8501322', name: 'Versoix (lac)' },
  { id: '8501315', name: 'Céligny (lac)' },
  { id: '8501227', name: 'Nyon' },
  { id: '8501320', name: 'Rolle (lac)' },
  { id: '8501321', name: 'Saint-Prex' },
  { id: '8501228', name: 'Morges' },
  { id: '8501075', name: 'Lausanne-Ouchy' },
  { id: '8501319', name: 'Pully' },
  { id: '8501318', name: 'Lutry' },
  { id: '8501317', name: 'Cully' },
  { id: '8501243', name: 'Rivaz-Saint-Saphorin' },
  { id: '8501248', name: 'Vevey-Marché' },
  { id: '8501247', name: 'Vevey-La Tour (la' },
  { id: '8501312', name: 'Clarens' },
  { id: '8501077', name: 'Montreux' },
  { id: '8501313', name: 'Territet' },
  { id: '8501234', name: 'Château-de-Chillon' },
  { id: '8501314', name: 'Villeneuve' },
  { id: '8501079', name: 'Le Bouveret' },
  { id: '8501078', name: 'Saint-Gingolph' },
  { id: '8501074', name: 'Evian-les-Bains (F) (lac)' },
  { id: '8501072', name: 'Thonon-les-Bains (F) (lac)' },
  { id: '8501240', name: 'Margencel-Anthy-Séchex(F)(lac)' },
  { id: '8501244', name: 'Sciez (F) (lac)' },
  { id: '8530763', name: 'Excenevex (F) (lac)' },
  { id: '8501242', name: 'Nernier (F) (lac)' },
  { id: '8501233', name: 'Chens-sur-Léman (F) (lac)' },
  { id: '8501239', name: 'Hermance (lac)' },
  { id: '8501231', name: 'Anières (lac)' },
  { id: '8501235', name: 'Corsier GE (lac)' },
  { id: '8530616', name: 'La Belotte (lac)' },
  
  // Thunersee
  { id: '8507150', name: 'Thun (See)' },
  { id: '8507151', name: 'Hilterfingen (See)' },
  { id: '8507152', name: 'Oberhofen am Thunersee' },
  { id: '8507153', name: 'Gunten' },
  { id: '8507159', name: 'Gwatt Deltapark (See)' },
  { id: '8507154', name: 'Spiez Schiffstation' },
  { id: '8507164', name: 'Einigen (See)' },
  { id: '8507161', name: 'Hünibach (See)' },
  { id: '8507166', name: 'Faulensee (See)' },
  { id: '8507155', name: 'Merligen (See)' },
  { id: '8507156', name: 'Beatenbucht (See)' },
  { id: '8507169', name: 'Interlaken West (See)' },
  { id: '8507158', name: 'Neuhaus (Unterseen) (See)' },
  { id: '8507157', name: 'Beatushöhlen-Sundlauenen' },
  { id: '8507167', name: 'Leissigen (See)' },
  { id: '8507168', name: 'Därligen (See)' },
  
  // Brienzersee
  { id: '8508371', name: 'Bönigen' },
  { id: '8508379', name: 'Iseltwald (See)' },
  { id: '8508378', name: 'Giessbach' },
  { id: '8508374', name: 'Oberried am Brienzersee (See)' },
  { id: '8508373', name: 'Niederried (See)' },
  { id: '8508372', name: 'Ringgenberg (See)' },
  { id: '8508375', name: 'Brienz Dorf' },
  
  // Lago Maggiore
  { id: '8505573', name: 'Ascona' },
  { id: '8505469', name: 'Locarno' },
  { id: '8505519', name: 'Tenero (lago)' },
  { id: '8505570', name: 'Magadino' },
  { id: '8505571', name: 'Vira (Gambarogno) (lago)' },
  { id: '8505518', name: 'S. Nazzaro (lago)' },
  { id: '8505574', name: 'Gerra (Gambarogno) (lago)' },
  { id: '8505575', name: 'Ranzo (lago)' },
  { id: '8505524', name: 'Brissago (lago)' },
  { id: '8505854', name: 'Porto Ronco (lago)' },
  { id: '8505577', name: 'Isole di Brissago' },
  
  // Lago di Lugano
  { id: '8505553', name: 'Paradiso (lago)' },
  { id: '8505650', name: 'Bissone (lago)' },
  { id: '8505550', name: 'Lugano Centrale (lago)' },
  { id: '8587842', name: 'Cassarate (lago)' },
  { id: '8505559', name: 'Castagnola (lago)' },
  { id: '8530717', name: 'Castagnola Heleneum (lago)' },
  { id: '8505551', name: 'Gandria (lago)' },
  { id: '8505656', name: 'Museo doganale svizzero (lago)' },
  { id: '8505545', name: 'Cantine di Gandria (lago)' },
  { id: '8505544', name: 'Grotto Pescatori (lago)' },
  { id: '8505677', name: 'Ponte Tresa (lago)' },
  { id: '8505556', name: 'Brusino Arsizio (lago)' },
  { id: '8505651', name: 'Melide Cantine (lago)' },
  { id: '8505557', name: 'Morcote (lago)' },
  { id: '8531259', name: 'Maroggio (lago)' },
  { id: '8505548', name: 'Melano (lago)' },
  
  // Bielersee
  { id: '8504371', name: 'Biel/Bienne' },
  { id: '8504372', name: 'Tüscherz' },
  { id: '8504369', name: 'Nidau' },
  { id: '8504374', name: 'Twann' },
  { id: '8504375', name: 'Ligerz' },
  { id: '8504377', name: 'La Neuveville' },
  { id: '8504378', name: 'Erlach' },
  { id: '8504565', name: 'Le Landeron débarcadère' },
  { id: '8504567', name: 'Thielle-Wavre' },
  { id: '8504376', name: 'St. Petersinsel Nord' },
  
  // Neuenburgersee
  { id: '8504550', name: 'Neuchâtel' },
  { id: '8504560', name: 'Saint-Blaise' },
  { id: '8504561', name: 'Cudrefin' },
  { id: '8504562', name: 'Portalban' },
  { id: '8504563', name: 'Chevroux' },
  { id: '8504564', name: 'Estavayer-le-Lac' },
  { id: '8504554', name: 'Gorgier - Chez-le-Bart' },
  { id: '8504558', name: 'Yverdon-les-Bains' },
  { id: '8504557', name: 'Grandson' },
  { id: '8504556', name: 'Concise (bateau)' },
  { id: '8504243', name: 'Vaumarcus débarcadère' },
  { id: '8504555', name: 'St-Aubin NE (bateau)' },
  { id: '8504559', name: 'Bevaix (bateau)' },
  { id: '8530793', name: 'Cortaillod (bateau)' },
  { id: '8504552', name: 'Auvernier (bateau)' },
  { id: '8504551', name: 'Neuchâtel-Serrières (bateau)' },
  { id: '8504808', name: 'Hauterive NE débarcadère' },
  { id: '8504571', name: 'La Sauge (bateau)' },
  
  // Murtensee
  { id: '8504577', name: 'Murten/Morat (Schiff/bateau)' },
  { id: '8504573', name: 'Praz (Vully)' },
  { id: '8504575', name: 'Vallamand' },
  { id: '8530821', name: 'Faoug débarcadère' },
  { id: '8504574', name: 'Môtier' },
  { id: '8504499', name: 'Trois-Lacs (camping)' },
  { id: '8504572', name: 'Sugiez (bateau)' },
  
  // Aare
  { id: '8504379', name: 'Solothurn (Schiff)' },
  { id: '8504365', name: 'Altreu' },
  { id: '8504363', name: 'Grenchen (Schiff)' },
  { id: '8504366', name: 'Büren (Schiff)' },
  { id: '8504368', name: 'Brügg (Schiff)' },
  { id: '8504364', name: 'Port' },
  
  // Zugersee
  { id: '8502251', name: 'Zug Bahnhofsteg (See)' },
  { id: '8502246', name: 'Zug Landsgemeindeplatz (See)' },
  { id: '8502252', name: 'Oberwil bei Zug (See)' },
  { id: '8502255', name: 'Lotenbach (See)' },
  { id: '8502258', name: 'Walchwil (See)' },
  { id: '8505060', name: 'Arth am See (Schiff)' },
  { id: '8502257', name: 'Immensee (See)' },
  { id: '8502254', name: 'Risch (See)' },
  { id: '8502253', name: 'Buonas (See)' },
  { id: '8502250', name: 'Cham (See)' },
  
  // Walensee
  { id: '8530665', name: 'Walenstadt (See)' },
  { id: '8530664', name: 'Mols (See)' },
  { id: '8530663', name: 'Unterterzen (See)' },
  { id: '8530856', name: 'Murg Ost (See)' },
  { id: '8530666', name: 'Murg West (See)' },
  { id: '8530660', name: 'Mühlehorn (See)' },
  { id: '8530658', name: 'Weesen (See)' },
  { id: '8530659', name: 'Betlis' },
  { id: '8530661', name: 'Quinten' },
  { id: '8530662', name: 'Quinten Au' },
  
  // Hallwilersee
  { id: '8530627', name: 'Seengen (See)' },
  { id: '8530625', name: 'Meisterschwanden Delphin' },
  { id: '8530626', name: 'Meisterschwanden Seerose' },
  { id: '8530630', name: 'Aesch LU (See)' },
  { id: '8530631', name: 'Mosen (See)' },
  { id: '8530629', name: 'Beinwil am See (See)' },
  { id: '8530628', name: 'Birrwil (See)' },
  { id: '8530632', name: 'Boniswil (See)' },
  
  // Ägerisee
  { id: '8530742', name: 'Unterägeri (See)' },
  { id: '8530743', name: 'Oberägeri (See)' },
  { id: '8530857', name: 'Oberägeri Ländli (See)' },
  { id: '8530633', name: 'Eierhals (See)' },
  { id: '8530634', name: 'Morgarten Denkmal (See)' },
  { id: '8530635', name: 'Morgarten Hotel (See)' },
  { id: '8530636', name: 'Naas (See)' },
];

// Limit for each API call (smaller = faster response)
const LIMIT = 30;

/**
 * Warm up the cache for a single station
 */
async function warmUpStation(stationId: string, stationName: string): Promise<boolean> {
  const today = new Date();
  const dateString = today.toISOString().split('T')[0]; // YYYY-MM-DD
  
  const url = `https://transport.opendata.ch/v1/stationboard?id=${stationId}&limit=${LIMIT}&date=${dateString}`;
  
  try {
    console.log(`🌅 Warming up cache for: ${stationName} (${stationId})`);
    
    const response = await fetch(url);
    
    if (!response.ok) {
      console.error(`❌ Failed to warm up ${stationName}: HTTP ${response.status}`);
      return false;
    }
    
    const data = await response.json();
    const departuresCount = data.stationboard?.length || 0;
    
    console.log(`✅ Warmed up ${stationName}: ${departuresCount} departures`);
    return true;
    
  } catch (error) {
    console.error(`❌ Error warming up ${stationName}:`, error);
    return false;
  }
}

/**
 * Add delay between requests to avoid overwhelming the API
 */
function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export default async function handler(
  req: VercelRequest,
  res: VercelResponse
) {
  // Security: Only allow requests from Vercel Cron Job
  const authHeader = req.headers['authorization'];
  const cronSecret = process.env.CRON_SECRET;
  
  // If CRON_SECRET is set, verify it
  if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
    console.error('❌ Unauthorized cache warm-up attempt');
    return res.status(401).json({ 
      error: 'Unauthorized',
      message: 'Invalid or missing authorization token'
    });
  }
  
  console.log('🌅 Starting morning cache warm-up...');
  console.log(`🌅 Warming up ${ALL_STATIONS.length} stations`);
  
  const startTime = Date.now();
  let successCount = 0;
  let failureCount = 0;
  
  // Warm up all stations sequentially with delays
  for (const station of ALL_STATIONS) {
    const success = await warmUpStation(station.id, station.name);
    
    if (success) {
      successCount++;
    } else {
      failureCount++;
    }
    
    // Add 200ms delay between requests to avoid overwhelming the API
    await delay(200);
  }
  
  const duration = Date.now() - startTime;
  
  console.log('🌅 Cache warm-up completed!');
  console.log(`✅ Success: ${successCount} stations`);
  console.log(`❌ Failed: ${failureCount} stations`);
  console.log(`⏱️ Duration: ${duration}ms`);
  
  return res.status(200).json({
    success: true,
    stats: {
      total: ALL_STATIONS.length,
      success: successCount,
      failed: failureCount,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString()
    }
  });
}

