//
//  MTAFeedConfiguration.swift
//  Now Departing
//
//  MTA GTFS-RT feed URL configuration and route-to-feed mapping.
//
//  The MTA publishes separate GTFS-RT feeds for each group of subway lines.
//  No API key or authentication is required — feeds are freely accessible.
//  Details: https://api.mta.info/#/subwayRealTimeFeeds
//

import Foundation

struct MTAFeedConfiguration {

    // MARK: - Base URL

    static let baseURL = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct"

    // MARK: - Feed Paths
    //
    // Multiple routes share a single feed file; fetching any route from the
    // group retrieves real-time data for every route in that group.
    //
    // Feed groups:
    //   gtfs      → 1 2 3 4 5 6 GS (42nd St Shuttle)
    //   gtfs-ace  → A C E FS (Franklin Ave Shuttle) H (Rockaway Park)
    //   gtfs-bdfm → B D F M
    //   gtfs-g    → G
    //   gtfs-jz   → J Z
    //   gtfs-nqrw → N Q R W
    //   gtfs-l    → L
    //   gtfs-7    → 7
    //   gtfs-si   → SIR (Staten Island Railway)

    static let feedPathByRoute: [String: String] = [
        "1":  "gtfs",
        "2":  "gtfs",
        "3":  "gtfs",
        "4":  "gtfs",
        "5":  "gtfs",
        "6":  "gtfs",
        "GS": "gtfs",
        "A":  "gtfs-ace",
        "C":  "gtfs-ace",
        "E":  "gtfs-ace",
        "FS": "gtfs-ace",
        "H":  "gtfs-ace",
        "B":  "gtfs-bdfm",
        "D":  "gtfs-bdfm",
        "F":  "gtfs-bdfm",
        "M":  "gtfs-bdfm",
        "G":  "gtfs-g",
        "J":  "gtfs-jz",
        "Z":  "gtfs-jz",
        "N":  "gtfs-nqrw",
        "Q":  "gtfs-nqrw",
        "R":  "gtfs-nqrw",
        "W":  "gtfs-nqrw",
        "L":  "gtfs-l",
        "7":  "gtfs-7",
        "SI": "gtfs-si",
    ]

    // MARK: - URL Helpers

    /// Returns the GTFS-RT feed URL for a given route ID, or nil if unknown.
    static func feedURL(for routeId: String) -> URL? {
        guard let path = feedPathByRoute[routeId] else { return nil }
        return URL(string: "\(baseURL)/\(path)")
    }

    /// Returns the deduplicated list of feed URLs for a set of route IDs.
    /// Routes that share a feed file are collapsed to a single URL.
    static func feedURLs(for routeIds: [String]) -> [URL] {
        var seenPaths = Set<String>()
        var urls: [URL] = []
        for route in routeIds {
            guard let path = feedPathByRoute[route], !seenPaths.contains(path) else { continue }
            seenPaths.insert(path)
            if let url = URL(string: "\(baseURL)/\(path)") {
                urls.append(url)
            }
        }
        return urls
    }

    // MARK: - Request Builder

    /// Returns a plain URLRequest for a feed URL.  No authentication headers needed.
    static func request(for url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        return req
    }
}
