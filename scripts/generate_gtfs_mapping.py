#!/usr/bin/env python3
"""
generate_gtfs_mapping.py
------------------------
Generates GTFS stop IDs, coordinates, and complex IDs for every station in
Shared/stations.json by cross-referencing the MTA's official data sources.

Usage
-----
1.  Download the MTA subway GTFS static feed:
        curl -L -o scripts/gtfs.zip "https://api.mta.info/GTFS.zip"
        unzip -j scripts/gtfs.zip stops.txt -d scripts/

2.  Download the MTA Stations.csv open-data file:
        curl -L -o scripts/Stations.csv \
            "http://web.mta.info/developers/data/nyct/subway/Stations.csv"

3.  Run this script from the repo root:
        python3 scripts/generate_gtfs_mapping.py \
            --stops   scripts/stops.txt \
            --stations-csv scripts/Stations.csv \
            --stations Shared/stations.json \
            --output   Shared/stations.json

    The script overwrites Shared/stations.json in-place with three new optional
    fields added to each station entry:
        "gtfsStopId"  – GTFS parent stop ID (string), e.g. "A44"
        "latitude"    – WGS-84 latitude  (float)
        "longitude"   – WGS-84 longitude (float)
        "complexId"   – MTA complex ID grouping underground-connected platforms

Matching strategy
-----------------
Primary: Stations.csv is indexed by (normalised_name, route_id).  For each
station entry in stations.json (which is keyed by subway line), the script
looks up the correct platform for that specific line, resolving ambiguous
station names like "Clinton-Washington Avs" (C→A44, G→G35) or "125 St"
(A/C/B/D→A15, 1→116, 2/3→225, 4/5/6→621).

Fallback: stations not found in Stations.csv fall back to name-only matching
against GTFS stops.txt (the old behaviour).

Requirements
------------
    pip install rapidfuzz   # for fuzzy name matching
"""

import argparse
import csv
import json
import sys
from collections import defaultdict
from difflib import get_close_matches
from pathlib import Path
from typing import Optional


try:
    from rapidfuzz import process as fuzz_process, fuzz
    USE_RAPIDFUZZ = True
except ImportError:
    USE_RAPIDFUZZ = False
    print("⚠  rapidfuzz not installed – falling back to difflib (less accurate).")
    print("   Install with: pip install rapidfuzz\n")


def normalise(name: str) -> str:
    """Lower-case and collapse whitespace/punctuation for fuzzy matching."""
    return " ".join(name.lower().replace("-", " ").replace("/", " ").split())


# ---------------------------------------------------------------------------
# Index builders
# ---------------------------------------------------------------------------

def load_stations_csv(stations_csv_path: str) -> tuple[dict, dict]:
    """
    Build two indexes from MTA Stations.csv:

    route_index:  (normalised_name, route_id) -> {stop_id, complex_id, lat, lon}
        Used as the primary lookup: matches each line's station to the correct
        physical platform even when multiple platforms share a name.

    name_index:   normalised_name -> list of {stop_id, complex_id, lat, lon}
        Fallback when the route-aware lookup finds nothing (e.g. because
        Stations.csv uses a slightly different name than stations.json).

    Returns (route_index, name_index).
    """
    route_index = {}   # (norm_name, route) -> entry
    name_index  = defaultdict(list)  # norm_name -> [entry, ...]

    try:
        with open(stations_csv_path, newline="", encoding="utf-8-sig") as f:
            for row in csv.DictReader(f):
                stop_id    = row.get("GTFS Stop ID", "").strip()
                complex_id = row.get("Complex ID",   "").strip()
                stop_name  = row.get("Stop Name",    "").strip()
                lat_str    = row.get("GTFS Latitude", "").strip()
                lon_str    = row.get("GTFS Longitude","").strip()
                routes_str = row.get("Daytime Routes","").strip()

                if not stop_id or not stop_name:
                    continue
                try:
                    lat = float(lat_str)
                    lon = float(lon_str)
                except ValueError:
                    continue

                entry = {
                    "stop_id":    stop_id,
                    "complex_id": complex_id,
                    "lat": lat,
                    "lon": lon,
                }

                norm = normalise(stop_name)
                name_index[norm].append(entry)

                for route in routes_str.split():
                    key = (norm, route.upper())
                    # First occurrence wins (stable ordering from CSV)
                    route_index.setdefault(key, entry)

    except FileNotFoundError:
        print(f"⚠  Stations.csv not found at {stations_csv_path}")
        print("   Download from: http://web.mta.info/developers/data/nyct/subway/Stations.csv\n")

    return route_index, dict(name_index)


def load_gtfs_stops(stops_path: str) -> dict:
    """
    Fallback index: normalised_name -> {stop_id, lat, lon}
    Only parent stations (location_type == 1).
    When a name appears more than once the last row wins (same as before),
    but this index is only consulted when Stations.csv has no match.
    """
    parents = {}
    with open(stops_path, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            if row.get("location_type", "0").strip() == "1":
                name = row["stop_name"].strip()
                parents[normalise(name)] = {
                    "stop_id": row["stop_id"].strip(),
                    "lat": float(row["stop_lat"]),
                    "lon": float(row["stop_lon"]),
                }
    return parents


# ---------------------------------------------------------------------------
# Lookup helpers
# ---------------------------------------------------------------------------

def fuzzy_lookup(norm_key: str, index: dict) -> Optional[str]:
    """Return the best matching key in *index*, or None."""
    if norm_key in index:
        return norm_key
    candidates = list(index.keys())
    if USE_RAPIDFUZZ:
        result = fuzz_process.extractOne(norm_key, candidates, scorer=fuzz.token_sort_ratio)
        if result and result[1] >= 80:
            return result[0]
    else:
        matches = get_close_matches(norm_key, candidates, n=1, cutoff=0.75)
        if matches:
            return matches[0]
    return None


# The Z train interlines with J but Stations.csv often only lists "J" or "J M".
# Map Z to J so Z-train stops resolve correctly.
ROUTE_ALIASES = {"Z": "J"}


def find_entry(station_name: str, line_id: str,
               route_index: dict, name_index: dict,
               gtfs_fallback: dict) -> Optional[dict]:
    """
    Return a match dict with keys: stop_id, complex_id (may be ""), lat, lon.

    Priority:
      1. Exact (name, route) in route_index, also trying route aliases
      2. Fuzzy (name, route) in route_index
      3. For compound names ("A / B"), try each component separately
      4. Exact name in name_index  (only when there is exactly one platform)
      5. Fuzzy name in name_index  (only when unambiguous)
      6. Exact/fuzzy name in gtfs_fallback (stops.txt only)
    """
    norm  = normalise(station_name)
    route = line_id.upper()
    routes_to_try = [route] + ([ROUTE_ALIASES[route]] if route in ROUTE_ALIASES else [])

    # 1. Exact (name, route) — also try aliases
    for r in routes_to_try:
        key = (norm, r)
        if key in route_index:
            return route_index[key]

    # 2. Fuzzy name, exact route (handles abbreviation differences)
    for r in routes_to_try:
        route_names = {k[0]: True for k in route_index if k[1] == r}
        fuzzy_norm = fuzzy_lookup(norm, route_names)
        if fuzzy_norm:
            key = (fuzzy_norm, r)
            if key in route_index:
                return route_index[key]

    # 3. Compound names: "Bleecker St / Broadway-Lafayette St" → try each part,
    #    but prefer a route-aware match over a name-only fallback.
    if " / " in station_name:
        parts = [p.strip() for p in station_name.split(" / ")]
        # First pass: route-aware only (steps 1–2 of find_entry, no name fallback)
        for part in parts:
            part_norm  = normalise(part)
            for r in routes_to_try:
                key = (part_norm, r)
                if key in route_index:
                    return route_index[key]
            for r in routes_to_try:
                route_names = {k[0]: True for k in route_index if k[1] == r}
                fn = fuzzy_lookup(part_norm, route_names)
                if fn and (fn, r) in route_index:
                    return route_index[(fn, r)]
        # Second pass: allow name-only fallback
        for part in parts:
            hit = find_entry(part, line_id, route_index, name_index, gtfs_fallback)
            if hit:
                return hit

    # 4 & 5. Name-only fallback from Stations.csv (unambiguous only)
    fuzzy_norm2 = fuzzy_lookup(norm, name_index)
    if fuzzy_norm2:
        entries = name_index[fuzzy_norm2]
        if len(entries) == 1:
            return entries[0]
        # Multiple platforms share this name but none matched by route – caller
        # will flag it for manual review.
        return None

    # 6. stops.txt fallback (no complex_id)
    fuzzy_norm3 = fuzzy_lookup(norm, gtfs_fallback)
    if fuzzy_norm3:
        hit = gtfs_fallback[fuzzy_norm3]
        return {"stop_id": hit["stop_id"], "complex_id": "", "lat": hit["lat"], "lon": hit["lon"]}

    return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Add GTFS stop IDs to stations.json")
    parser.add_argument("--stops",        required=True, help="Path to GTFS stops.txt")
    parser.add_argument("--stations",     required=True, help="Path to stations.json (input)")
    parser.add_argument("--output",       required=True, help="Path to write updated stations.json")
    parser.add_argument("--stations-csv", default=None,
                        help="Path to MTA Stations.csv "
                             "(default: Stations.csv in the same dir as --stops)")
    args = parser.parse_args()

    stations_csv_path = args.stations_csv or str(Path(args.stops).parent / "Stations.csv")

    print(f"Loading Stations.csv from {stations_csv_path} …")
    route_index, name_index = load_stations_csv(stations_csv_path)
    print(f"  {len(route_index)} (name, route) entries, "
          f"{len(name_index)} unique names.\n")

    print(f"Loading GTFS stops fallback from {args.stops} …")
    gtfs_fallback = load_gtfs_stops(args.stops)
    print(f"  {len(gtfs_fallback)} parent stations.\n")

    print(f"Loading stations from {args.stations} …")
    with open(args.stations, encoding="utf-8") as f:
        stations_by_line: dict = json.load(f)

    total = matched = 0
    unmatched: list[tuple[str, str]] = []   # (line_id, station_name)

    for line_id, stations in stations_by_line.items():
        for station in stations:
            total += 1
            name = station["name"]
            hit  = find_entry(name, line_id, route_index, name_index, gtfs_fallback)
            if hit:
                station["gtfsStopId"] = hit["stop_id"]
                station["latitude"]   = hit["lat"]
                station["longitude"]  = hit["lon"]
                if hit.get("complex_id"):
                    station["complexId"] = hit["complex_id"]
                matched += 1
            else:
                unmatched.append((line_id, name))

    print(f"Matched {matched}/{total} stations.")

    if unmatched:
        print(f"\nUNMATCHED ({len(unmatched)}) – review and patch manually:")
        for line_id, name in sorted(unmatched):
            print(f"  • Line {line_id}: {name!r}")

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(stations_by_line, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"\nWrote updated stations.json to {args.output}")
    if unmatched:
        sys.exit(1)


if __name__ == "__main__":
    main()
