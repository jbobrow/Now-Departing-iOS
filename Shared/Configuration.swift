//
//  Configuration.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 1/30/25.
//


//
//  Configuration.swift
//  Now Departing WatchOS App
//

import Foundation

struct Configuration {
    // API Configuration
    static let apiBaseURL = "https://api.wheresthefuckingtrain.com"
    static let apiTimeout: TimeInterval = 30
    static let apiRetryCount = 3
    static let apiRetryDelay: TimeInterval = 2
    
    // Cache Configuration
    static let cacheDuration: TimeInterval = 3600 // 1 hour
    
    // Background Refresh Configuration
    static let backgroundRefreshInterval: TimeInterval = 15 * 60 // 15 minutes
    
    // UI Configuration
    static let smallScreenThreshold: CGFloat = 165
    static let minimumColumnWidth: CGFloat = 32
    static let maximumColumnWidth: CGFloat = 38
    
    // Update Frequencies
    static let activeUpdateInterval: TimeInterval = 1
    static let backgroundUpdateInterval: TimeInterval = 30
    static let apiRefreshInterval: TimeInterval = 60
}
