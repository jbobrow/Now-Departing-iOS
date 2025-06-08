//
//  SubwayConfiguration.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 1/30/25.
//


//
//  SubwayConfiguration.swift
//  Now Departing WatchOS App
//

import SwiftUI

struct SubwayConfiguration {
    static let lineColors: [String: (background: Color, foreground: Color)] = [
        "1": (Color(red: 0.92, green: 0.22, blue: 0.21), .white),
        "2": (Color(red: 0.92, green: 0.22, blue: 0.21), .white),
        "3": (Color(red: 0.92, green: 0.22, blue: 0.21), .white),
        "X": (Color(red: 0.0, green: 0.0, blue: 0.0), .black),       // For settings button
        "4": (Color(red: 0.07, green: 0.57, blue: 0.25), .white),
        "5": (Color(red: 0.07, green: 0.57, blue: 0.25), .white),
        "6": (Color(red: 0.07, green: 0.57, blue: 0.25), .white),
        "7": (Color(red: 0.72, green: 0.23, blue: 0.67), .white),
        "A": (Color(red: 0.03, green: 0.24, blue: 0.64), .white),
        "C": (Color(red: 0.03, green: 0.24, blue: 0.64), .white),
        "E": (Color(red: 0.03, green: 0.24, blue: 0.64), .white),
        "G": (Color(red: 0.44, green: 0.74, blue: 0.30), .white),
        "B": (Color(red: 0.98, green: 0.39, blue: 0.17), .white),
        "D": (Color(red: 0.98, green: 0.39, blue: 0.17), .white),
        "F": (Color(red: 0.98, green: 0.39, blue: 0.17), .white),
        "M": (Color(red: 0.98, green: 0.39, blue: 0.17), .white),
        "N": (Color(red: 0.98, green: 0.80, blue: 0.19), .black),
        "Q": (Color(red: 0.98, green: 0.80, blue: 0.19), .black),
        "R": (Color(red: 0.98, green: 0.80, blue: 0.19), .black),
        "W": (Color(red: 0.98, green: 0.80, blue: 0.19), .black),
        "J": (Color(red: 0.60, green: 0.40, blue: 0.22), .white),
        "Z": (Color(red: 0.60, green: 0.40, blue: 0.22), .white),
        "L": (Color(red: 0.65, green: 0.66, blue: 0.67), .white)
    ]
}
