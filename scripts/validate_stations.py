#!/usr/bin/env python3
"""
validate_stations.py
--------------------
Checks Shared/stations.json for the mistakes that have shipped before, such as
a station labeled Jackson Heights carrying East Broadway's stop ID. Every
installed copy of the app downloads this file from main, so it runs on each
pull request that touches it and before each automatic schedule refresh.

Usage (from the repo root):
    python3 scripts/validate_stations.py
    python3 scripts/validate_stations.py --baseline old_stations.json

Exits 1, listing each problem, if:
- the file isn't the {line: [station, ...]} shape the app decodes
- a line lists the same stop twice
- a stop ID has different labels on different lines
- a stop ID isn't in the MTA's stops.txt, or the station is over 500 m from it
- serviceHours or terminalHours aren't the form the app reads
- with --baseline: anything other than serviceHours and terminalHours changed
  (what an automatic schedule refresh may change)
"""

import argparse
import csv
import json
import math
import re
import sys
from collections import defaultdict

DAYS = {"mon", "tue", "wed", "thu", "fri", "sat", "sun"}
HOURS_FIELDS = ("serviceHours", "terminalHours")
MAX_METERS_FROM_STOP = 500
RANGES = re.compile(r"^\d{1,2}(-\d{1,2})?(,\d{1,2}(-\d{1,2})?)*$")


def meters_between(lat1, lon1, lat2, lon2):
    dy = (lat1 - lat2) * 111_320
    dx = (lon1 - lon2) * 111_320 * math.cos(math.radians((lat1 + lat2) / 2))
    return math.hypot(dx, dy)


def hours_problems(hours):
    """Problems with a {"mon": "0-6,19-23", ...} value, as the app parses it."""
    if not isinstance(hours, dict) or not hours:
        return ["isn't a non-empty object of days"]
    problems = []
    for day, ranges in hours.items():
        if day not in DAYS:
            problems.append(f"has unknown day {day!r}")
        elif not isinstance(ranges, str) or not RANGES.match(ranges):
            problems.append(f"{day}: {ranges!r} isn't hour ranges like \"0-6,19-23\"")
        else:
            for part in ranges.split(","):
                bounds = [int(b) for b in part.split("-")]
                if bounds[0] > bounds[-1] or bounds[-1] > 23:
                    problems.append(f"{day}: {part!r} isn't a range of hours 0-23")
    return problems


def validate(stations_by_line, stops, baseline=None):
    """A list of problems, empty when the file is good."""
    problems = []
    if not isinstance(stations_by_line, dict) or not stations_by_line:
        return ["the file isn't an object of lines"]

    labels = defaultdict(set)
    for line, stations in stations_by_line.items():
        if not isinstance(stations, list) or not stations:
            problems.append(f"{line}: isn't a non-empty list of stations")
            continue
        seen = set()
        for station in stations:
            where = f"{line} {station.get('gtfsStopId', '?')} {station.get('display', '?')}"
            if not isinstance(station.get("display"), str) or not isinstance(station.get("name"), str):
                problems.append(f"{where}: needs display and name strings")
                continue
            stop_id = station.get("gtfsStopId")
            if not stop_id:
                problems.append(f"{where}: has no gtfsStopId")
                continue
            if stop_id in seen:
                problems.append(f"{where}: is listed twice on the {line}")
            seen.add(stop_id)
            labels[stop_id].add(station["display"])

            stop = stops.get(stop_id)
            if stop is None:
                problems.append(f"{where}: {stop_id} isn't a stop in stops.txt")
            else:
                lat, lon = station.get("latitude"), station.get("longitude")
                if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
                    problems.append(f"{where}: needs latitude and longitude")
                else:
                    off = meters_between(lat, lon, *stop["position"])
                    if off > MAX_METERS_FROM_STOP:
                        problems.append(f"{where}: is {off:.0f} m from {stop_id} ({stop['name']}) in stops.txt")

            if "serviceHours" in station:
                problems += [f"{where}: serviceHours {p}" for p in hours_problems(station["serviceHours"])]
            if "terminalHours" in station:
                terminal = station["terminalHours"]
                if not isinstance(terminal, dict) or not terminal or set(terminal) - {"N", "S"}:
                    problems.append(f"{where}: terminalHours needs \"N\" and/or \"S\" keys")
                else:
                    for direction, hours in terminal.items():
                        problems += [f"{where}: terminalHours {direction} {p}" for p in hours_problems(hours)]

    for stop_id, names in sorted(labels.items()):
        if len(names) > 1:
            problems.append(f"{stop_id}: has different labels on different lines: {sorted(names)}")

    if baseline is not None:
        def without_hours(data):
            return {line: [{k: v for k, v in s.items() if k not in HOURS_FIELDS} for s in stations]
                    for line, stations in data.items()}
        if without_hours(stations_by_line) != without_hours(baseline):
            problems.append("something other than serviceHours and terminalHours changed from the baseline")

    return problems


def read_stops(path):
    """{parent stop ID: {"name", "position"}} from GTFS stops.txt."""
    with open(path, encoding="utf-8-sig") as f:
        return {row["stop_id"]: {"name": row["stop_name"],
                                 "position": (float(row["stop_lat"]), float(row["stop_lon"]))}
                for row in csv.DictReader(f) if not row.get("parent_station")}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--stations", default="Shared/stations.json")
    parser.add_argument("--stops", default="scripts/stops.txt")
    parser.add_argument("--baseline", help="stations.json from before an automatic refresh")
    args = parser.parse_args()

    with open(args.stations, encoding="utf-8") as f:
        stations_by_line = json.load(f)
    baseline = None
    if args.baseline:
        with open(args.baseline, encoding="utf-8") as f:
            baseline = json.load(f)

    problems = validate(stations_by_line, read_stops(args.stops), baseline)
    for problem in problems:
        print(f"error: {problem}")
    count = sum(len(s) for s in stations_by_line.values()) if isinstance(stations_by_line, dict) else 0
    print(f"{len(problems)} problems in {count} station entries")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
