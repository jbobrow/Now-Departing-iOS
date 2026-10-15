#!/usr/bin/env python3
"""
generate_service_hours.py
-------------------------
Adds a "serviceHours" field to every station in Shared/stations.json that its
line doesn't serve around the clock, using the MTA's GTFS static schedule.

Usage (from the repo root):
    curl -fsSL -o scripts/gtfs.zip "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_subway.zip"
    python3 scripts/generate_service_hours.py
    python3 scripts/validate_stations.py

A workflow does this weekly (scripts/refresh_schedule.py), so it's only needed
by hand after editing the station lists. gtfs.zip isn't committed.

The app hides a station from its line's list when the line isn't scheduled
there at the current New York hour (unless live data shows trains there), so
part-time branches and stops — the F's two Manhattan tunnels, the A's
Brooklyn locals at night, the B on weekends — drop out of the list when they
don't apply.

Format
------
    "serviceHours": {"mon": "0-6,19-23", "tue": "0-6,19-23", ..., "sat": "0-23"}

Keys are mon..sun; values are inclusive New York-local hour ranges. A day with
no service is left out. Stations served every hour of the week get no field.

    "terminalHours": {"S": {"mon": "5-20", ...}}

On a station that's sometimes where a line's trains end, though not the end of
its list: the hours, by direction ("N" or "S"), when at least two thirds of
the trips setting out that hour end there. The app names it as the terminal
then, e.g. Crown Heights-Utica Av for the 4 by day, while the list runs on to
New Lots Av for the 4's late-night trips. The hour is the one a trip leaves
its first stop.

A train scheduled at 25:30 on Friday's schedule counts as Saturday 1am. Each
served hour is widened by one hour either side, so a stop doesn't drop out of
the list just before its first train or just after its last, and stops along
a line don't flicker in and out as trains make their way down it. Weekday
schedules apply Monday to Friday; holidays are ignored (the app's live check
shows a stop that has trains anyway).
"""

import argparse
import csv
import io
import json
import zipfile
from collections import Counter, defaultdict

DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
SERVICE_DAYS = {"Weekday": [0, 1, 2, 3, 4], "Saturday": [5], "Sunday": [6]}
WEEK_HOURS = 7 * 24


def base_line(route_id):
    """Diamond-express route IDs ("6X", "7X", "FX") belong to their base line."""
    return route_id[:-1] if len(route_id) == 2 and route_id.endswith("X") else route_id


def read_csv(archive, name):
    return csv.DictReader(io.TextIOWrapper(archive.open(name), encoding="utf-8-sig"))


def read_schedule(gtfs_zip):
    """Which week hours (0 = Monday midnight) each line serves each stop, and where its trips end.

    Returns ({(line, parent stop ID): set of week hours},
             {(line, direction, week hour the trip sets out): Counter of the parent stops trips end at},
             {(line, parent stop ID): trains a week}).
    """
    served = defaultdict(set)
    trains = Counter()
    first_stop = {}  # trip → (stop_sequence, hour)
    last_stop = {}   # trip → (stop_sequence, stop ID with its direction)
    with zipfile.ZipFile(gtfs_zip) as archive:
        trips = {}
        for row in read_csv(archive, "trips.txt"):
            # Service IDs look like "Weekday", "Saturday", "Sunday-H-20260908-20261031"
            service = row["service_id"].split("-")[0]
            if service in SERVICE_DAYS:
                trips[row["trip_id"]] = (base_line(row["route_id"]), SERVICE_DAYS[service])
        for row in read_csv(archive, "stop_times.txt"):
            trip = trips.get(row["trip_id"])
            if not trip:
                continue
            line, days = trip
            hour = int((row["arrival_time"] or row["departure_time"]).split(":")[0])
            stop = row["stop_id"][:-1]  # "F16N" → "F16"
            for day in days:
                served[(line, stop)].add((day * 24 + hour) % WEEK_HOURS)
            trains[(line, stop)] += len(days)
            trip_id, sequence = row["trip_id"], int(row["stop_sequence"])
            if trip_id not in first_stop or sequence < first_stop[trip_id][0]:
                first_stop[trip_id] = (sequence, int((row["departure_time"] or row["arrival_time"]).split(":")[0]))
            if trip_id not in last_stop or sequence > last_stop[trip_id][0]:
                last_stop[trip_id] = (sequence, row["stop_id"])

    ends = defaultdict(Counter)
    for trip_id, (_, hour) in first_stop.items():
        line, days = trips[trip_id]
        stop_id = last_stop[trip_id][1]
        for day in days:
            ends[(line, stop_id[-1], (day * 24 + hour) % WEEK_HOURS)][stop_id[:-1]] += 1
    return served, ends, trains


def terminal_hours(line, stops, ends):
    """{parent stop: {direction: week hours}} for stops other than the list's ends where most of
    the line's trips setting out in an hour end."""
    defaults = {"N": stops[0], "S": stops[-1]}
    result = defaultdict(lambda: defaultdict(set))
    for direction, default in defaults.items():
        for hour in range(WEEK_HOURS):
            counts = ends.get((line, direction, hour))
            if not counts:
                continue
            terminus, trips = counts.most_common(1)[0]
            if terminus != default and terminus in stops and trips >= 2 / 3 * sum(counts.values()):
                result[terminus][direction].add(hour)
    return result


def widen(hours):
    return {(h + d) % WEEK_HOURS for h in hours for d in (-1, 0, 1)}


def format_ranges(hours):
    ranges = []
    for h in sorted(hours):
        if ranges and h == ranges[-1][1] + 1:
            ranges[-1][1] = h
        else:
            ranges.append([h, h])
    return ",".join(str(a) if a == b else f"{a}-{b}" for a, b in ranges)


def service_hours(hours):
    by_day = defaultdict(set)
    for h in hours:
        by_day[h // 24].add(h % 24)
    return {DAYS[d]: format_ranges(by_day[d]) for d in range(7) if by_day[d]}


def annotate(stations_by_line, served, ends):
    """Sets serviceHours and terminalHours on every station, in place, from read_schedule's
    results. Returns (part-time stations, part-time terminals)."""
    tagged = terminals = 0
    for line, stations in stations_by_line.items():
        alternates = terminal_hours(line, [s.get("gtfsStopId") for s in stations], ends)
        for station in stations:
            station.pop("serviceHours", None)
            station.pop("terminalHours", None)
            hours = widen(served.get((line, station.get("gtfsStopId")), set()))
            if not hours:
                # Leave it visible rather than hide it forever
                print(f"warning: no scheduled {line} trains at {station['display']} ({station.get('gtfsStopId')})")
            elif len(hours) < WEEK_HOURS:
                station["serviceHours"] = service_hours(hours)
                tagged += 1
            by_direction = alternates.get(station.get("gtfsStopId"))
            if by_direction:
                station["terminalHours"] = {d: service_hours(h) for d, h in sorted(by_direction.items())}
                terminals += 1
    return tagged, terminals


def write_stations(stations_by_line, path):
    """In the file's existing form: two-space indents, no trailing newline."""
    with open(path, "w", encoding="utf-8") as f:
        f.write(json.dumps(stations_by_line, indent=2, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--gtfs", default="scripts/gtfs.zip")
    parser.add_argument("--stations", default="Shared/stations.json")
    args = parser.parse_args()

    served, ends, _ = read_schedule(args.gtfs)
    with open(args.stations, encoding="utf-8") as f:
        stations_by_line = json.load(f)
    tagged, terminals = annotate(stations_by_line, served, ends)
    write_stations(stations_by_line, args.stations)
    print(f"{tagged} part-time stations tagged, {terminals} part-time terminals")


if __name__ == "__main__":
    main()
