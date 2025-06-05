#!/usr/bin/env python3
"""
Script to check consistency between stations.json and any hardcoded stations in the codebase.
"""

import json
import re
import os
from pathlib import Path

def load_stations_from_json(json_path):
    """Load all stations from the JSON file."""
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    stations = []
    for lake in data['lakes']:
        for station in lake['stations']:
            if isinstance(station, str):
                # Handle string-only stations (no coordinates)
                stations.append({
                    'name': station,
                    'uic_ref': None,
                    'coordinates': None,
                    'lake': lake['name']
                })
            else:
                # Handle full station objects
                stations.append({
                    'name': station['name'],
                    'uic_ref': station.get('uic_ref'),
                    'coordinates': station.get('coordinates'),
                    'lake': lake['name']
                })
    
    return stations

def find_hardcoded_stations_in_code(directory):
    """Find hardcoded stations in Swift files."""
    hardcoded_stations = []
    swift_files = list(Path(directory).rglob("*.swift"))
    
    for file_path in swift_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Look for StationData patterns
            station_pattern = r'StationData\s*\(\s*id:\s*"([^"]+)",\s*name:\s*"([^"]+)",\s*latitude:\s*([\d.-]+),\s*longitude:\s*([\d.-]+),\s*uic_ref:\s*"([^"]*)"?\s*\)'
            matches = re.findall(station_pattern, content, re.MULTILINE)
            
            for match in matches:
                hardcoded_stations.append({
                    'id': match[0],
                    'name': match[1],
                    'latitude': float(match[2]),
                    'longitude': float(match[3]),
                    'uic_ref': match[4] if match[4] else None,
                    'file': str(file_path)
                })
                
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
    
    return hardcoded_stations

def compare_stations(json_stations, hardcoded_stations):
    """Compare JSON stations with hardcoded stations."""
    print("=== STATION CONSISTENCY CHECK ===\n")
    
    # Create lookup dictionaries
    json_by_name = {s['name']: s for s in json_stations}
    json_by_uic = {s['uic_ref']: s for s in json_stations if s['uic_ref']}
    
    print(f"📊 Total stations in JSON: {len(json_stations)}")
    print(f"📊 Total hardcoded stations found: {len(hardcoded_stations)}")
    print()
    
    # Check consistency
    consistent = True
    missing_in_json = []
    coordinate_mismatches = []
    
    for hardcoded in hardcoded_stations:
        name = hardcoded['name']
        uic_ref = hardcoded['uic_ref']
        
        # Try to find matching station in JSON
        json_station = None
        if name in json_by_name:
            json_station = json_by_name[name]
        elif uic_ref and uic_ref in json_by_uic:
            json_station = json_by_uic[uic_ref]
        
        if not json_station:
            missing_in_json.append(hardcoded)
            consistent = False
            continue
        
        # Check coordinates if available
        if json_station['coordinates']:
            json_lat = json_station['coordinates']['latitude']
            json_lon = json_station['coordinates']['longitude']
            
            lat_diff = abs(json_lat - hardcoded['latitude'])
            lon_diff = abs(json_lon - hardcoded['longitude'])
            
            # Allow small differences due to floating point precision
            if lat_diff > 0.001 or lon_diff > 0.001:
                coordinate_mismatches.append({
                    'name': name,
                    'hardcoded': f"{hardcoded['latitude']}, {hardcoded['longitude']}",
                    'json': f"{json_lat}, {json_lon}",
                    'file': hardcoded['file']
                })
                consistent = False
    
    # Print results
    if missing_in_json:
        print("❌ Stations hardcoded but not found in JSON:")
        for station in missing_in_json:
            print(f"   • {station['name']} (UIC: {station['uic_ref']}) in {station['file']}")
        print()
    
    if coordinate_mismatches:
        print("⚠️  Coordinate mismatches:")
        for mismatch in coordinate_mismatches:
            print(f"   • {mismatch['name']}")
            print(f"     Hardcoded: {mismatch['hardcoded']}")
            print(f"     JSON:      {mismatch['json']}")
            print(f"     File:      {mismatch['file']}")
        print()
    
    if consistent:
        print("✅ All hardcoded stations are consistent with JSON!")
    else:
        print("❌ Found inconsistencies between hardcoded stations and JSON")
    
    # Show some statistics
    stations_with_coords = sum(1 for s in json_stations if s['coordinates'])
    print(f"\n📍 Stations with coordinates in JSON: {stations_with_coords}")
    
    lakes = set(s['lake'] for s in json_stations)
    print(f"🏞️  Lakes covered: {len(lakes)}")
    for lake in sorted(lakes):
        lake_stations = [s for s in json_stations if s['lake'] == lake]
        print(f"   • {lake}: {len(lake_stations)} stations")
    
    return consistent

def main():
    # Get the project root directory
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    # Paths
    json_path = project_root / "Next Wave" / "Data" / "stations.json"
    code_directories = [
        project_root / "Next Wave",
        project_root / "Next Wave Watch Watch App",
    ]
    
    if not json_path.exists():
        print(f"❌ stations.json not found at {json_path}")
        return False
    
    # Load stations from JSON
    json_stations = load_stations_from_json(json_path)
    
    # Find hardcoded stations in code
    all_hardcoded = []
    for directory in code_directories:
        if directory.exists():
            hardcoded = find_hardcoded_stations_in_code(directory)
            all_hardcoded.extend(hardcoded)
    
    # Compare
    return compare_stations(json_stations, all_hardcoded)

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1) 