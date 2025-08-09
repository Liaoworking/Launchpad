//
//  SettingsView.swift
//  Launchpad
//
//  Created by liao on 2025/8/9.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("gridColumns") private var gridColumns = 8
    @AppStorage("showAppNames") private var showAppNames = true
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("darkMode") private var darkMode = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Display") {
                    HStack {
                        Text("Grid Columns")
                        Spacer()
                        Picker("Grid Columns", selection: $gridColumns) {
                            ForEach([6, 7, 8, 9, 10], id: \.self) { columns in
                                Text("\(columns)").tag(columns)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 200)
                    }
                    
                    Toggle("Show App Names", isOn: $showAppNames)
                    Toggle("Enable Animations", isOn: $enableAnimations)
                    Toggle("Dark Mode", isOn: $darkMode)
                }
                
                Section("Behavior") {
                    Toggle("Auto Refresh Apps", isOn: $autoRefresh)
                    
                    Button("Refresh App List") {
                        AppManager.shared.loadInstalledApps()
                    }
                    .foregroundColor(.blue)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("GitHub Repository", destination: URL(string: "https://github.com/yourusername/launchpad")!)
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
} 