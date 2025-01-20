//
//  SettingsManager.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 1/20/25.
//

import SwiftUI

struct SettingsView: View {
    // Get the version and build number from the main bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 8) {
                Text("Now Departing")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Version \(appVersion)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Created by Jonathan Bobrow")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
