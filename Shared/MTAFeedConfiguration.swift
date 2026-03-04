//
//  MTAFeedConfiguration.swift
//  Now Departing
//
//  MTA GTFS-RT feed URL configuration and route-to-feed mapping.
//
//  The MTA publishes separate GTFS-RT feeds for each group of subway lines.
//  A free API key is required — register at https://api.mta.info
//

import Foundation

struct MTAFeedConfiguration {

    // MARK: - Base URL

    static let apiBaseURL = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds"

    // MARK: - API Key
    //
    // Obtain a free key at https://api.mta.info and set it here,
    // or (better) load it from a Secrets.plist / Info.plist that is
    // excluded from source control.
    //
    // The key is sent as the HTTP header  x-api-key: <value>
    //
    static var apiKey: String {
        // Look for an "MTA_API_KEY" entry in the main bundle's Info.plist first.
        if let key = Bundle.main.infoDictionary?["MTA_API_KEY"] as? String,
           !key.isEmpty {
            return key
        }
        // Fall back to a compile-time constant for local development.
        return ""   // ← Paste your key here for local testing only; do NOT commit it.
    }

    // MARK: - Feed Paths (URL-encoded endpoint paths)
    //
    // Each value is the percent-encoded path component appended to apiBaseURL.
    // Multiple routes share a single feed file; fetching any route from the group
    // retrieves real-time data for every route in that group simultaneously.
    //
    // Feed groups (as of 2025):
    //   nyct%2Fgtfs          → 1 2 3 4 5 6 GS (42nd St Shuttle)
    //   nyct%2Fgtfs-ace      → A C E FS (Franklin Ave Shuttle) H (Rockaway Park)
    //   nyct%2Fgtfs-bdfm     → B D F M
    //   nyct%2Fgtfs-g        → G
    //   nyct%2Fgtfs-jz       → J Z
    //   nyct%2Fgtfs-nqrw     → N Q R W
    //   nyct%2Fgtfs-l        → L
    //   nyct%2Fgtfs-7        → 7
    //   nyct%2Fgtfs-si       → SIR (Staten Island Railway)

    static let feedPathByRoute: [String: String] = [
        "1":  "nyct%2Fgtfs",
        "2":  "nyct%2Fgtfs",
        "3":  "nyct%2Fgtfs",
        "4":  "nyct%2Fgtfs",
        "5":  "nyct%2Fgtfs",
        "6":  "nyct%2Fgtfs",
        "GS": "nyct%2Fgtfs",
        "A":  "nyct%2Fgtfs-ace",
        "C":  "nyct%2Fgtfs-ace",
        "E":  "nyct%2Fgtfs-ace",
        "FS": "nyct%2Fgtfs-ace",
        "H":  "nyct%2Fgtfs-ace",
        "B":  "nyct%2Fgtfs-bdfm",
        "D":  "nyct%2Fgtfs-bdfm",
        "F":  "nyct%2Fgtfs-bdfm",
        "M":  "nyct%2Fgtfs-bdfm",
        "G":  "nyct%2Fgtfs-g",
        "J":  "nyct%2Fgtfs-jz",
        "Z":  "nyct%2Fgtfs-jz",
        "N":  "nyct%2Fgtfs-nqrw",
        "Q":  "nyct%2Fgtfs-nqrw",
        "R":  "nyct%2Fgtfs-nqrw",
        "W":  "nyct%2Fgtfs-nqrw",
        "L":  "nyct%2Fgtfs-l",
        "7":  "nyct%2Fgtfs-7",
        "SI": "nyct%2Fgtfs-si",
    ]

    // MARK: - URL Helpers

    /// Returns the GTFS-RT feed URL for a given route ID, or nil if the route is unknown.
    static func feedURL(for routeId: String) -> URL? {
        guard let path = feedPathByRoute[routeId] else { return nil }
        return URL(string: "\(apiBaseURL)/\(path)")
    }

    /// Returns the deduplicated set of GTFS-RT feed URLs needed to serve all
    /// of the supplied route IDs.  Useful when fetching data for multiple lines
    /// (e.g., for the nearby-trains feature) because routes that share a feed
    /// only need to be fetched once.
    static func feedURLs(for routeIds: [String]) -> [URL] {
        var seenPaths = Set<String>()
        var urls: [URL] = []
        for route in routeIds {
            guard let path = feedPathByRoute[route], !seenPaths.contains(path) else { continue }
            seenPaths.insert(path)
            if let url = URL(string: "\(apiBaseURL)/\(path)") {
                urls.append(url)
            }
        }
        return urls
    }

    // MARK: - Request Builder

    /// Builds a URLRequest for the given feed URL, injecting the MTA API key header.
    static func request(for url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.timeoutInterval = 30
        return req
    }
}
