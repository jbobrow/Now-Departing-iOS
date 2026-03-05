//
//  Configuration.swift
//  Now Departing
//

import Foundation

struct Configuration {
    // MARK: - MTA GTFS-RT API
    //
    // Direct feed access replaces the former third-party JSON wrapper.
    // Feed URLs and route→feed mapping live in MTAFeedConfiguration.swift.
    // The API key is configured there as well (via Info.plist or a local constant).

    static let apiTimeout: TimeInterval = 30
    static let apiRetryCount = 3
    static let apiRetryDelay: TimeInterval = 2

    // MARK: - Cache Configuration
    static let cacheDuration: TimeInterval = 3600 // 1 hour

    // MARK: - Background Refresh Configuration
    static let backgroundRefreshInterval: TimeInterval = 15 * 60 // 15 minutes

    // MARK: - UI Configuration
    static let smallScreenThreshold: CGFloat = 165
    static let minimumColumnWidth: CGFloat = 32
    static let maximumColumnWidth: CGFloat = 38

    // MARK: - Update Frequencies
    static let activeUpdateInterval: TimeInterval = 1
    static let backgroundUpdateInterval: TimeInterval = 30
    static let apiRefreshInterval: TimeInterval = 60
}
