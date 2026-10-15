#!/usr/bin/env python3
"""
refresh_schedule.py
-------------------
Brings the station hours in Shared/stations.json up to date with a newly
downloaded MTA schedule. Run weekly by .github/workflows/refresh-schedule.yml,
which commits the result to main, where every installed app picks it up.

Usage (from the repo root):
    curl -fsSL -o scripts/gtfs.zip "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_subway.zip"
    python3 scripts/refresh_schedule.py [--force] [--report coverage.md]

When the schedule's feed version differs from scripts/gtfs_snapshot.json's (or
with --force), it:
1. Refreshes scripts/stops.txt from the download.
2. Regenerates serviceHours and terminalHours (generate_service_hours.py).
3. Validates the result (validate_stations.py) against the file as it was, so
   nothing but those hours may change. On any problem it exits 1 having written
   nothing, and the workflow fails instead of committing.
4. Compares which stops each line serves (at least MIN_TRAINS a week) with the
   last schedule's. The station lists themselves need a person, so changes that
   matter are written to --report, which the workflow opens as an issue: stops
   a line now serves that aren't in its list, and listed stops it no longer does.
5. Records the feed version and that coverage in scripts/gtfs_snapshot.json.
"""

import argparse
import copy
import io
import json
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_service_hours  # noqa: E402
import validate_stations  # noqa: E402

MIN_TRAINS = 40  # a week; fewer is a stray trip or two, like the W's few to Brooklyn


def feed_version(archive):
    rows = io.TextIOWrapper(archive.open("feed_info.txt"), encoding="utf-8-sig").read().splitlines()
    header, values = rows[0].split(","), rows[1].split(",")
    return values[header.index("feed_version")]


def coverage(trains, lines):
    """{line: sorted stop IDs it serves at least MIN_TRAINS times a week}."""
    served = {line: set() for line in lines}
    for (line, stop), count in trains.items():
        if line in served and count >= MIN_TRAINS:
            served[line].add(stop)
    return {line: sorted(stops) for line, stops in sorted(served.items())}


def coverage_report(old, new, stations_by_line, version):
    """Markdown listing what changed in what the lines serve, or None if nothing that matters."""
    names = {}
    for stations in stations_by_line.values():
        for s in stations:
            names.setdefault(s["gtfsStopId"], s["display"])
    sections = []
    for line in sorted(new):
        listed = {s["gtfsStopId"] for s in stations_by_line[line]}
        before, after = set(old.get(line, [])), set(new[line])
        unlisted = sorted((after - before) - listed)
        dropped = sorted((before - after) & listed)
        if not unlisted and not dropped:
            continue
        lines = [f"### {line}"]
        lines += [f"- Now served but not listed: `{s}` {names.get(s, '')}".rstrip() for s in unlisted]
        lines += [f"- Listed but no longer served (under {MIN_TRAINS} trains a week): `{s}` {names[s]}" for s in dropped]
        sections.append("\n".join(lines))
    if not sections:
        return None
    return (f"The MTA schedule `{version}` changes which stops these lines serve. The station "
            f"hours have been refreshed on main, but the lists in `Shared/stations.json` need "
            f"updating by hand: where new stops go, and whether dropped ones should stay.\n\n"
            + "\n\n".join(sections)
            + "\n\nRun `python3 scripts/generate_service_hours.py` and "
              "`python3 scripts/validate_stations.py` after editing the lists.")


def set_output(name, value):
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a") as f:
            f.write(f"{name}={value}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--gtfs", default="scripts/gtfs.zip")
    parser.add_argument("--stations", default="Shared/stations.json")
    parser.add_argument("--stops", default="scripts/stops.txt")
    parser.add_argument("--snapshot", default="scripts/gtfs_snapshot.json")
    parser.add_argument("--report", help="where to write coverage changes, if any")
    parser.add_argument("--force", action="store_true", help="refresh even if the feed version hasn't changed")
    args = parser.parse_args()

    with zipfile.ZipFile(args.gtfs) as archive:
        version = feed_version(archive)
        stops_txt = archive.read("stops.txt")
    snapshot = {}
    if os.path.exists(args.snapshot):
        with open(args.snapshot, encoding="utf-8") as f:
            snapshot = json.load(f)
    if snapshot.get("feedVersion") == version and not args.force:
        print(f"Schedule {version} is already applied")
        set_output("updated", "false")
        return

    with open(args.stations, encoding="utf-8") as f:
        baseline = json.load(f)
    stations_by_line = copy.deepcopy(baseline)
    served, ends, trains = generate_service_hours.read_schedule(args.gtfs)
    tagged, terminals = generate_service_hours.annotate(stations_by_line, served, ends)

    stops_path = args.stops + ".new"
    with open(stops_path, "wb") as f:
        f.write(stops_txt)
    problems = validate_stations.validate(stations_by_line, validate_stations.read_stops(stops_path), baseline)
    if problems:
        os.remove(stops_path)
        for problem in problems:
            print(f"error: {problem}")
        print(f"Schedule {version} not applied: {len(problems)} problems")
        sys.exit(1)

    os.replace(stops_path, args.stops)
    generate_service_hours.write_stations(stations_by_line, args.stations)
    new_coverage = coverage(trains, stations_by_line)
    report = None
    if "coverage" in snapshot:
        report = coverage_report(snapshot["coverage"], new_coverage, stations_by_line, version)
    with open(args.snapshot, "w", encoding="utf-8") as f:
        f.write(json.dumps({"feedVersion": version, "coverage": new_coverage}, indent=2) + "\n")

    print(f"Applied schedule {version}: {tagged} part-time stations, {terminals} part-time terminals")
    set_output("updated", "true")
    set_output("version", version)
    if report:
        print(report)
        if args.report:
            with open(args.report, "w", encoding="utf-8") as f:
                f.write(report + "\n")
        set_output("coverage_changed", "true")


if __name__ == "__main__":
    main()
