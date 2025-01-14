import requests
from bs4 import BeautifulSoup
import csv
import time
from typing import Dict, List, Optional
import logging
from urllib.parse import urljoin
import math

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class WaveCalculator:
    """Klasse zur Berechnung von Schiffswellen."""
    
    def __init__(self):
        self.g = 9.81  # Erdbeschleunigung in m/s²
        self.rho = 1000  # Wasserdichte in kg/m³
        self.kinematic_viscosity = 1.0e-6  # Kinematische Viskosität von Wasser
        
        # Schwellenwerte für Wellenbewertung
        self.wave_thresholds = {
            'energy': {  # Schwellenwerte für Wellenenergie in J/m²
                'low': 150,     # Grenze für 1 Welle (kleiner als MS Säntis)
                'medium': 250   # Grenze für 2 Wellen (zwischen MS Helvetia und MS Albis)
            },
            'force': {   # Schwellenwerte für Aufprallkraft in N/m²
                'low': 45000,     # Grenze für 1 Welle (kleiner als MS Wädenswil)
                'medium': 55000   # Grenze für 2 Wellen (zwischen MS Linth und MS Albis)
            }
        }

    def convert_to_float(self, value: str) -> Optional[float]:
        """Konvertiert einen String in eine Zahl, entfernt Einheiten."""
        try:
            # Entferne alle nicht-numerischen Zeichen außer Punkt und Komma
            cleaned = ''.join(c for c in value if c.isdigit() or c in '.,')
            cleaned = cleaned.replace(',', '.')
            return float(cleaned)
        except:
            return None

    def calculate_kelvin_wake_angle(self) -> float:
        """Berechnet den Kelvin-Winkel der Schiffswellen."""
        return math.degrees(math.asin(1/3))  # ≈ 19.47 Grad

    def calculate_wave_rating(self, energy: float, force: float) -> int:
        """
        Berechnet die Wellenbewertung (1-3) basierend auf Energie und Kraft.
        
        Args:
            energy: Wellenenergie in J/m²
            force: Aufprallkraft in N/m²
            
        Returns:
            int: Wellenbewertung (1, 2 oder 3)
        """
        # Einzelbewertungen für Energie und Kraft
        energy_rating = 1
        if energy > self.wave_thresholds['energy']['medium']:
            energy_rating = 3
        elif energy > self.wave_thresholds['energy']['low']:
            energy_rating = 2

        force_rating = 1
        if force > self.wave_thresholds['force']['medium']:
            force_rating = 3
        elif force > self.wave_thresholds['force']['low']:
            force_rating = 2

        # Gesamtbewertung ist der höhere der beiden Werte
        return max(energy_rating, force_rating)

    def calculate_wave_parameters(self, length: float, beam: float, speed: float, 
                                displacement: float, depth: float = 10.0) -> Dict[str, float]:
        """
        Berechnet alle Wellenparameter basierend auf Schiffsparametern.
        
        Args:
            length: Schiffslänge in Metern
            beam: Schiffsbreite in Metern
            speed: Geschwindigkeit in km/h
            displacement: Verdrängung in Tonnen
            depth: Wassertiefe in Metern (Standardwert für Zürichsee)
            
        Returns:
            Dictionary mit Wellenparametern
        """
        # Konvertiere Geschwindigkeit von km/h in m/s
        speed_ms = speed / 3.6
        
        # Froude-Zahl basierend auf Länge
        froude_length = speed_ms / math.sqrt(self.g * length)
        
        # Froude-Zahl basierend auf Wassertiefe
        froude_depth = speed_ms / math.sqrt(self.g * depth)
        
        # Reynolds-Zahl
        reynolds = (length * speed_ms) / self.kinematic_viscosity
        
        # Maximale Wellenhöhe nach Kelvin-Theorie
        max_wave_height = 0.0
        if froude_length < 0.4:  # Verdrängungsfahrt
            max_wave_height = 0.04 * displacement * (speed_ms ** 2) / (length * beam)
        else:  # Gleitfahrt
            max_wave_height = 0.02 * displacement * (speed_ms ** 2) / (length * beam)
        
        # Korrektur für flaches Wasser
        if froude_depth > 0.7:
            shallow_water_factor = 1 + (froude_depth - 0.7)
            max_wave_height *= shallow_water_factor

        # Wellenlänge (nach der Dispersionsrelation für Tiefwasser)
        wavelength = (2 * math.pi * speed_ms**2) / self.g
        
        # Wellenperiode
        wave_period = math.sqrt((2 * math.pi * wavelength) / self.g)
        
        # Wellengeschwindigkeit (Phasengeschwindigkeit)
        wave_velocity = wavelength / wave_period
        
        # Wellenenergie pro Quadratmeter Wasseroberfläche (J/m²)
        wave_energy_density = (1/8) * self.rho * self.g * max_wave_height**2
        
        # Wellenleistung pro Meter Wellenfront (W/m)
        wave_power = wave_energy_density * wave_velocity
        
        # Aufprallkraft pro Quadratmeter (N/m²)
        impact_force = self.rho * self.g * max_wave_height * (wave_velocity**2 / 2)
        
        # Berechne Wellenbewertung
        wave_rating = self.calculate_wave_rating(
            energy=wave_energy_density,
            force=impact_force
        )
        
        return {
            "max_wave_height": max_wave_height,
            "froude_length": froude_length,
            "froude_depth": froude_depth,
            "reynolds": reynolds,
            "kelvin_angle": self.calculate_kelvin_wake_angle(),
            "wavelength": wavelength,
            "wave_period": wave_period,
            "wave_velocity": wave_velocity,
            "wave_energy_density": wave_energy_density,
            "wave_power": wave_power,
            "impact_force": impact_force,
            "wave_rating": wave_rating
        }

class ShipScraper:
    BASE_URL = "https://www.zsg.ch"
    FLEET_URL = "https://www.zsg.ch/de/gruppen-firmen/eventlocation-mieten/schiff-mieten"
    
    def __init__(self):
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }
        self.wave_calculator = WaveCalculator()
        # Define expected technical fields to ensure consistent data
        self.expected_fields = [
            "Baujahr", "Bauwerft", "Verdrängung leer", "Maschine", "Antrieb",
            "KW / PS", "Länge", "Breite", "Besatzung", "Personenkapazität"
        ]

    def extract_technical_info(self, url: str) -> Optional[Dict]:
        """Extract technical information from a ship's page."""
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            soup = BeautifulSoup(response.content, "html.parser")

            # Extract ship name from the headline
            ship_name = None
            headline = soup.find("div", class_="ce_headline")
            if headline and headline.find("h1"):
                ship_name = headline.find("h1").text.strip()
            if not ship_name:
                ship_name = "Unbekannt"

            # Find technical information section
            tech_info = {}
            for section in soup.find_all("section", class_="ce_accordion"):
                toggler = section.find("div", class_="toggler")
                if toggler and "Technische Informationen" in toggler.text:
                    # Find the accordion content
                    accordion = section.find("div", class_="accordion")
                    if accordion:
                        table = accordion.find("table")
                        if table:
                            for row in table.find_all("tr"):
    cols = row.find_all("td")
                                if len(cols) == 2:
        key = cols[0].text.strip()
        value = cols[1].text.strip()
                                    tech_info[key] = value

            # Add ship name and URL to the data
            tech_info["Schiffname"] = ship_name
            tech_info["URL"] = url

            # Berechne Wellendaten wenn möglich
            try:
                length = self.wave_calculator.convert_to_float(tech_info.get("Länge", "0"))
                beam = self.wave_calculator.convert_to_float(tech_info.get("Breite", "0"))
                displacement = self.wave_calculator.convert_to_float(tech_info.get("Verdrängung leer", "0"))
                
                if length and beam and displacement:
                    wave_data = self.wave_calculator.calculate_wave_parameters(
                        length=length,
                        beam=beam,
                        speed=18.0,  # Realistischere Geschwindigkeit für Zürichsee
                        displacement=displacement
                    )
                    
                    # Füge Wellendaten zu den technischen Informationen hinzu
                    tech_info["Maximale Wellenhöhe (m)"] = f"{wave_data['max_wave_height']:.2f}"
                    tech_info["Wellenlänge (m)"] = f"{wave_data['wavelength']:.1f}"
                    tech_info["Wellenperiode (s)"] = f"{wave_data['wave_period']:.1f}"
                    tech_info["Wellengeschwindigkeit (m/s)"] = f"{wave_data['wave_velocity']:.1f}"
                    tech_info["Wellenenergie (J/m²)"] = f"{wave_data['wave_energy_density']:.0f}"
                    tech_info["Wellenleistung (W/m)"] = f"{wave_data['wave_power']:.0f}"
                    tech_info["Aufprallkraft (N/m²)"] = f"{wave_data['impact_force']:.0f}"
                    tech_info["Froude-Längenzahl"] = f"{wave_data['froude_length']:.3f}"
                    tech_info["Froude-Tiefenzahl"] = f"{wave_data['froude_depth']:.3f}"
                    tech_info["Kelvin-Winkel (Grad)"] = f"{wave_data['kelvin_angle']:.1f}"
                    tech_info["Wellenbewertung"] = str(wave_data['wave_rating'])
            except Exception as e:
                logging.warning(f"Konnte Wellendaten für {ship_name} nicht berechnen: {e}")

            # Log the extracted data for debugging
            logging.info(f"Extracted data for {ship_name}:")
            for key, value in tech_info.items():
                logging.info(f"  {key}: {value}")

            return tech_info
        except Exception as e:
            logging.error(f"Error extracting data from {url}: {e}")
            return None

    def get_ship_urls(self) -> List[str]:
        """Get URLs of all ships from the fleet page."""
        try:
            response = requests.get(self.FLEET_URL, headers=self.headers)
            response.raise_for_status()
            soup = BeautifulSoup(response.content, "html.parser")
            
            ship_urls = []
            # Find all ship links in the submenu
            submenu = soup.find("ul", class_="vlist level_3")
            if submenu:
                for link in submenu.find_all("a", href=True):
                    href = link["href"]
                    if any(ship_type in href.lower() for ship_type in ["ms-", "ds-"]):
                        full_url = urljoin(self.BASE_URL, href)
                        ship_urls.append(full_url)
            
            return list(set(ship_urls))  # Remove duplicates
        except Exception as e:
            logging.error(f"Error getting ship URLs: {e}")
            return []

    def save_to_csv(self, all_data: List[Dict], filename: str = "schiffsdaten.csv"):
        """Save all ship data to a CSV file with consistent columns."""
        try:
            # Prepare headers: start with fixed fields, then add any additional fields found
            base_headers = ["Schiffname", "URL"] + self.expected_fields
            wave_headers = [
                "Maximale Wellenhöhe (m)",
                "Wellenlänge (m)",
                "Wellenperiode (s)",
                "Wellengeschwindigkeit (m/s)",
                "Wellenenergie (J/m²)",
                "Wellenleistung (W/m)",
                "Aufprallkraft (N/m²)",
                "Froude-Längenzahl",
                "Froude-Tiefenzahl",
                "Kelvin-Winkel (Grad)",
                "Wellenbewertung"
            ]
            headers = base_headers + wave_headers
            
            # Add any additional fields found in the data
            all_fields = set()
            for data in all_data:
                all_fields.update(data.keys())
            headers.extend(sorted(field for field in all_fields if field not in headers))

            with open(filename, mode="w", newline="", encoding="utf-8") as file:
                writer = csv.DictWriter(file, fieldnames=headers)
                writer.writeheader()
                for data in all_data:
                    writer.writerow(data)

            logging.info(f"Data successfully saved to {filename}")
        except Exception as e:
            logging.error(f"Error saving data to CSV: {e}")

    def run(self):
        """Run the complete scraping process."""
        logging.info("Starting ship data collection...")
        
        # Get all ship URLs
        ship_urls = self.get_ship_urls()
        logging.info(f"Found {len(ship_urls)} ships to process")
        for url in ship_urls:
            logging.info(f"Found ship URL: {url}")

        # Collect data for all ships
        all_data = []
        for i, url in enumerate(ship_urls, 1):
            logging.info(f"Processing ship {i}/{len(ship_urls)}: {url}")
            ship_data = self.extract_technical_info(url)
            if ship_data:
                all_data.append(ship_data)
            time.sleep(1)  # Be nice to the server

        # Save all data
        if all_data:
            self.save_to_csv(all_data)
            logging.info(f"Successfully collected data for {len(all_data)} ships")
        else:
            logging.error("No data collected")

if __name__ == "__main__":
    scraper = ShipScraper()
    scraper.run()