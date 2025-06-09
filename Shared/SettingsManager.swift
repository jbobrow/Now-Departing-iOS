//
//  SettingsManager.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 1/20/25.
//

import SwiftUI

// Settings Manager to store user preferences
class SettingsManager: ObservableObject {
    @Published var showPreciseMode: Bool {
        didSet {
            UserDefaults.standard.set(showPreciseMode, forKey: "showPreciseMode")
        }
    }
    
    init() {
        // Load saved preferences
        self.showPreciseMode = UserDefaults.standard.bool(forKey: "showPreciseMode")
    }
}

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    // Get the version and build number from the main bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        List {
            // App Info
            Section {
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
            }
            
            // Display Options
            Section {
                Toggle("Precise Mode (show seconds)", isOn: $settingsManager.showPreciseMode)
                    .toggleStyle(SwitchToggleStyle())
            }
            
        }
        .listStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SettingsManager())
    }
}
