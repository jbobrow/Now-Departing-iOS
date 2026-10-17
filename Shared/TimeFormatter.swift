//
//  TimeFormatter.swift
//  Now Departing
//
//  Centralized time formatting utilities for train arrival times
//

import Foundation

struct TimeFormatter {
    // MARK: - Primary Time Formatting

    /// Format arrival time as "Now", "X min", etc.
    /// - Parameters:
    ///   - arrivalTime: The train arrival time
    ///   - currentTime: The current time (defaults to now)
    ///   - fullText: If true, uses "X min" instead of "Xm"
    /// - Returns: Formatted time string
    static func formatArrivalTime(_ arrivalTime: Date, currentTime: Date = Date(), fullText: Bool = false) -> String {
        let interval = arrivalTime.timeIntervalSince(currentTime)
        let totalSeconds = Int(interval)

        if totalSeconds < -60 {
            return "—"
        }

        let minutes = max(0, totalSeconds) / 60

        if totalSeconds <= 30 {
            return "Now"
        } else if totalSeconds < 60 {
            return fullText ? "Arriving" : "Soon"
        } else {
            return fullText ? "\(minutes) min" : "\(minutes)m"
        }
    }

    /// Format arrival time with tuple input (minutes, seconds)
    /// - Parameters:
    ///   - minutes: Minutes until arrival
    ///   - seconds: Seconds component
    ///   - fullText: If true, uses "X min" instead of "Xm"
    /// - Returns: Formatted time string
    static func formatArrivalTime(minutes: Int, seconds: Int, fullText: Bool = false) -> String {
        let totalSeconds = minutes * 60 + seconds

        if totalSeconds < 60 {
            return "Now"
        } else {
            return fullText ? "\(minutes) min" : "\(minutes)m"
        }
    }

    // MARK: - Additional Time Formatting (for subsequent trains)

    /// Format additional train times (shorter format)
    /// - Parameters:
    ///   - arrivalTime: The train arrival time
    ///   - currentTime: The current time (defaults to now)
    /// - Returns: Formatted time string (e.g., "5m", "12m")
    static func formatAdditionalTime(_ arrivalTime: Date, currentTime: Date = Date()) -> String {
        let interval = arrivalTime.timeIntervalSince(currentTime)
        let totalSeconds = Int(interval)

        if totalSeconds < -60 {
            return "—"
        }

        let minutes = max(1, totalSeconds / 60)
        return "\(minutes)m"
    }

    /// Format additional time with tuple input
    /// - Parameters:
    ///   - minutes: Minutes until arrival
    ///   - seconds: Seconds component
    /// - Returns: Formatted time string
    static func formatAdditionalTime(minutes: Int, seconds: Int) -> String {
        let totalSeconds = minutes * 60 + seconds
        let displayMinutes = max(1, totalSeconds / 60)

        return "\(displayMinutes)m"
    }

    // MARK: - Live Time Formatting (with stale data handling)

    /// Format time with enhanced states (Now, Soon, Arriving, X min)
    /// - Parameters:
    ///   - arrivalTime: The train arrival time
    ///   - currentTime: The current time
    ///   - fullText: If true, uses full text descriptions
    /// - Returns: Formatted time string or "—" if stale
    static func formatLiveTime(_ arrivalTime: Date, currentTime: Date, fullText: Bool = false) -> String {
        let timeInterval = arrivalTime.timeIntervalSince(currentTime)
        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60

        // Handle stale/past data - if time is in the past by more than 60 seconds, show as stale
        if totalSeconds < -60 {
            return "—" // Em dash indicates stale data
        }

        if fullText {
            if totalSeconds <= 30 {
                return "Now"
            } else if totalSeconds < 60 {
                return "Arriving"
            } else {
                return "\(minutes) min"
            }
        } else {
            if totalSeconds <= 30 {
                return "Now"
            } else if totalSeconds < 60 {
                return "Soon"
            } else {
                return "\(minutes)m"
            }
        }
    }

    // MARK: - Compact Time Formatting (for widgets/complications)

    /// Format time in compact form for widgets
    /// - Parameters:
    ///   - minutes: Minutes until arrival
    ///   - seconds: Seconds component
    /// - Returns: Compact formatted string ("Now", "Xm")
    static func formatCompactTime(minutes: Int, seconds: Int) -> String {
        let totalSeconds = minutes * 60 + seconds

        if totalSeconds < 60 {
            return "Now"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Offline Note

    /// Note shown with train times: how fresh they are, "Updated 12s ago", or while a refresh
    /// can't get through, the offline note. Nil before the first fetch.
    static func updatedNote(lastUpdated: Date?, isOffline: Bool = false, currentTime: Date = Date()) -> String? {
        if isOffline { return offlineNote(lastUpdated: lastUpdated, currentTime: currentTime) }
        guard let lastUpdated else { return nil }
        let seconds = max(0, Int(currentTime.timeIntervalSince(lastUpdated)))
        return seconds < 60 ? "Updated \(seconds)s ago" : "Updated \(seconds / 60)m ago"
    }

    /// Note shown under times kept from an earlier fetch while a refresh can't get
    /// through, e.g. "Offline · updated 4m ago".
    static func offlineNote(lastUpdated: Date?, currentTime: Date = Date()) -> String {
        guard let lastUpdated else { return "Offline" }
        let minutes = Int(currentTime.timeIntervalSince(lastUpdated) / 60)
        return minutes < 1 ? "Offline · updated just now" : "Offline · updated \(minutes)m ago"
    }
}
