const axios = require("axios");
const cheerio = require("cheerio");

export default async function handler(req, res) {
    const { url } = req.query;
    if (!url) {
        return res.status(400).json({ error: "URL parameter is required" });
    }

    try {
        const response = await axios.get(url);
        const $ = cheerio.load(response.data);
        
        // Beispiel: Titel der Seite auslesen
        const title = $("title").text();
        
        res.status(200).json({ title });
    } catch (error) {
        res.status(500).json({ error: "Error fetching data" });
    }
}
