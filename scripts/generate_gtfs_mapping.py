#!/usr/bin/env python3
"""
generate_gtfs_mapping.py
------------------------
Generates GTFS stop IDs and coordinates for every station in Shared/stations.json
by cross-referencing the MTA's official GTFS static data (stops.txt).

Usage
-----
1.  Download the MTA subway GTFS static feed:
        curl -L -o gtfs.zip "https://api.mta.info/GTFS.zip"
    (No API key is required for the static feed.)

2.  Extract stops.txt from the zip:
        unzip -j gtfs.zip stops.txt

3.  Run this script from the repo root:
        python3 scripts/generate_gtfs_mapping.py \
            --stops stops.txt \
            --stations Shared/stations.json \
            --output Shared/stations.json

    The script overwrites Shared/stations.json in-place with two new optional
    fields added to each station entry:
        "gtfsStopId"  – GTFS parent stop ID (string), e.g. "127"
        "latitude"    – WGS-84 latitude  (float)
        "longitude"   – WGS-84 longitude (float)

Notes
-----
•   The MTA GTFS parent station entries have location_type = 1.
    Child platform stops (location_type = 0) carry the N/S suffix.
    This script records only the *parent* ID; the app appends "N" or "S"
    at runtime when querying the GTFS-RT feed.

•   Name matching uses a fuzzy comparison because the GTFS stop_name values
    and the names in stations.json sometimes differ slightly (e.g. spacing,
    punctuation, abbreviations).  Review the "UNMATCHED" lines printed to
    stdout and fix them manually if needed.

•   Stations that serve multiple physical platforms (e.g. Times Square, where
    the 1/2/3 and N/Q/R/W trains use different stop IDs) will have only one
    gtfsStopId recorded — the closest name match.  The app uses the route-to-
    feed mapping in MTAFeedConfiguration.swift to fetch the correct feed, so
    arrivals for the specific route will still be returned correctly as long as
    the stop ID belongs to the same feed group as the route.  If a station has
    platforms in multiple feed groups (rare), you may need to store multiple
    stop IDs; the Station model and MTAFeedService will need minor updates for
    that edge case.

Requirements
------------
    pip install rapidfuzz   # for fuzzy name matching
"""

import argparse
import csv
import json
import sys
from difflib import get_close_matches
from typing import Optional


try:
    from rapidfuzz import process as fuzz_process, fuzz
    USE_RAPIDFUZZ = True
except ImportError:
    USE_RAPIDFUZZ = False
    print("⚠  rapidfuzz not installed – falling back to difflib (less accurate).")
    print("   Install with: pip install rapidfuzz\n")


def normalise(name: str) -> str:
    """Lower-case and strip extra whitespace/punctuation for fuzzy matching."""
    return " ".join(name.lower().replace("-", " ").replace("/", " ").split())


def load_gtfs_stops(stops_path: str) -> dict:
    """
    Returns a dict:  normalised_name -> {stop_id, stop_name, lat, lon}
    Only includes parent station entries (location_type == 1).
    """
    parents = {}
    with open(stops_path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row.get("location_type", "0").strip() == "1":
                name = row["stop_name"].strip()
                key = normalise(name)
                parents[key] = {
                    "stop_id": row["stop_id"].strip(),
                    "stop_name": name,
                    "lat": float(row["stop_lat"]),
                    "lon": float(row["stop_lon"]),
                }
    return parents


def load_complex_ids(stations_csv_path: str) -> dict:
    """
    Returns a dict:  gtfs_stop_id -> complex_id (string)
    Derived from the MTA's Stations.csv (open data), which has a 'Complex ID'
    column that groups platforms sharing an underground complex.
    Download: http://web.mta.info/developers/data/nyct/subway/Stations.csv
    """
    mapping = {}
    try:
        with open(stations_csv_path, newline="", encoding="utf-8-sig") as f:
            for row in csv.DictReader(f):
                stop_id = row.get("GTFS Stop ID", "").strip()
                complex_id = row.get("Complex ID", "").strip()
                if stop_id and complex_id:
                    mapping[stop_id] = complex_id
    except FileNotFoundError:
        print(f"⚠  Stations.csv not found at {stations_csv_path} – complexId will not be set.")
        print("   Download from: http://web.mta.info/developers/data/nyct/subway/Stations.csv\n")
    return mapping


def find_match(station_name: str, gtfs_index: dict) -> Optional[dict]:
    """
    Attempts to find the best matching GTFS parent station for a given
    station name.  Returns the matching entry or None.
    """
    key = normalise(station_name)

    # Exact match first.
    if key in gtfs_index:
        return gtfs_index[key]

    all_keys = list(gtfs_index.keys())

    if USE_RAPIDFUZZ:
        result = fuzz_process.extractOne(key, all_keys, scorer=fuzz.token_sort_ratio)
        if result and result[1] >= 80:
            return gtfs_index[result[0]]
    else:
        matches = get_close_matches(key, all_keys, n=1, cutoff=0.75)
        if matches:
            return gtfs_index[matches[0]]

    return None


def main():
    parser = argparse.ArgumentParser(description="Add GTFS stop IDs to stations.json")
    parser.add_argument("--stops", required=True, help="Path to GTFS stops.txt")
    parser.add_argument("--stations", required=True, help="Path to stations.json (input)")
    parser.add_argument("--output", required=True, help="Path to write updated stations.json")
    parser.add_argument("--stations-csv", default=None,
                        help="Path to MTA Stations.csv for complex ID mapping "
                             "(download from http://web.mta.info/developers/data/nyct/subway/Stations.csv)")
    args = parser.parse_args()

    print(f"Loading GTFS stops from {args.stops} …")
    gtfs_index = load_gtfs_stops(args.stops)
    print(f"  {len(gtfs_index)} parent stations loaded.\n")

    stations_csv = args.stations_csv or str(
        __import__("pathlib").Path(args.stops).parent / "Stations.csv"
    )
    print(f"Loading complex IDs from {stations_csv} …")
    complex_map = load_complex_ids(stations_csv)
    print(f"  {len(complex_map)} stop→complex mappings loaded.\n")

    print(f"Loading stations from {args.stations} …")
    with open(args.stations, encoding="utf-8") as f:
        stations_by_line: dict = json.load(f)

    total = matched = 0
    unmatched_names = set()

    for line_id, stations in stations_by_line.items():
        for station in stations:
            total += 1
            name = station["name"]
            hit = find_match(name, gtfs_index)
            if hit:
                stop_id = hit["stop_id"]
                station["gtfsStopId"] = stop_id
                station["latitude"]   = hit["lat"]
                station["longitude"]  = hit["lon"]
                if stop_id in complex_map:
                    station["complexId"] = complex_map[stop_id]
                matched += 1
            else:
                unmatched_names.add(name)

    print(f"Matched {matched}/{total} stations.")

    if unmatched_names:
        print(f"\nUNMATCHED ({len(unmatched_names)}) – review and add manually:")
        for n in sorted(unmatched_names):
            print(f"  • {n}")

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(stations_by_line, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"\nWrote updated stations.json to {args.output}")
    if unmatched_names:
        sys.exit(1)


if __name__ == "__main__":
    main()
