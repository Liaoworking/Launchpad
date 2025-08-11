//
//  SettingsView.swift
//  Launchpad
//
//  Created by liao on 2025/8/9.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("blurRadius") private var blurRadius: Double = 30
    @AppStorage("enableBackgroundAnimation") private var enableBackgroundAnimation: Bool = true
    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 1.0
    @AppStorage("overlayOpacity") private var overlayOpacity: Double = 0.2
    @AppStorage("autoRefreshBackground") private var autoRefreshBackground: Bool = false
    @AppStorage("refreshInterval") private var refreshInterval: Double = 300 // 5 minutes
    @AppStorage("gridColumns") private var gridColumns: Int = 8
    @AppStorage("gridRows") private var gridRows: Int = 6
    
    @State private var cacheSize: Int64 = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Wallpaper Blur Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Blur Intensity")
                            Spacer()
                            Text("\(Int(blurRadius))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $blurRadius, in: 5...50, step: 1)
                            .accentColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Background Opacity")
                            Spacer()
                            Text("\(Int(backgroundOpacity * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $backgroundOpacity, in: 0.3...1.0, step: 0.05)
                            .accentColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Overlay Opacity")
                            Spacer()
                            Text("\(Int(overlayOpacity * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $overlayOpacity, in: 0.0...0.5, step: 0.05)
                            .accentColor(.blue)
                    }
                }
                
                Section("Animation Settings") {
                    Toggle("Enable Background Animation", isOn: $enableBackgroundAnimation)
                    
                    if enableBackgroundAnimation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Animation Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Background will have subtle breathing effect to make interface more lively")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Grid Layout Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Apps Per Row")
                            Spacer()
                            Text("\(gridColumns) apps")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(gridColumns) },
                            set: { gridColumns = Int($0) }
                        ), in: 4...15, step: 1)
                            .accentColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Rows Per Page")
                            Spacer()
                            Text("\(gridRows) rows")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(gridRows) },
                            set: { gridRows = Int($0) }
                        ), in: 3...8, step: 1)
                            .accentColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Layout Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Maximum \(gridColumns * gridRows) apps per page")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Auto Refresh") {
                    Toggle("Auto Refresh Background", isOn: $autoRefreshBackground)
                    
                    if autoRefreshBackground {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Refresh Interval")
                                Spacer()
                                Text("\(Int(refreshInterval / 60)) minutes")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $refreshInterval, in: 60...1800, step: 60)
                                .accentColor(.blue)
                        }
                    }
                }
                
                Section("Preview") {
                    VStack(spacing: 16) {
                        Text("Blur Effect Preview")
                            .font(.headline)
                        
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.3),
                                        Color.purple.opacity(0.3),
                                        Color.blue.opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 120)
                            .blur(radius: blurRadius)
                            .opacity(backgroundOpacity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                Rectangle()
                                    .fill(Color.black.opacity(overlayOpacity))
                                    .cornerRadius(12)
                            )
                            .overlay(
                                Text("Preview Text")
                                    .foregroundColor(.white)
                                    .font(.title2)
                                    .fontWeight(.medium)
                            )
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                }
                
                Section("Cache Management") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Wallpaper Cache")
                                .font(.headline)
                            Text("Cache Size: \(formatCacheSize())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .onAppear {
                                    updateCacheSize()
                                }
                        }
                        Spacer()
                        Button("Clear Cache") {
                            clearWallpaperCache()
                        }
                        .foregroundColor(.red)
                    }
                    
                    let cacheInfo = WallpaperCache.shared.getCacheInfo()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Hit Rate: \(String(format: "%.1f%%", cacheInfo.stats.hitRate * 100))")
                                .font(.caption)
                                .foregroundColor(.green)
                            Spacer()
                            Text("Hits: \(cacheInfo.stats.hits)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Misses: \(cacheInfo.stats.misses)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let identifier = cacheInfo.identifier {
                            Text("Wallpaper ID: \(identifier)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cache Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Wallpaper cache can significantly improve startup speed, recommended to keep")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Actions") {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Refresh Background") {
                        refreshBackground()
                    }
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
        .frame(width: 500, height: 700)
        .onAppear {
            updateCacheSize()
        }
    }
    
    private func resetToDefaults() {
        blurRadius = 30
        enableBackgroundAnimation = true
        backgroundOpacity = 1.0
        overlayOpacity = 0.2
        autoRefreshBackground = false
        refreshInterval = 300
        gridColumns = 8
        gridRows = 6
    }
    
    private func refreshBackground() {
        // Notify ContentView to refresh background
        NotificationCenter.default.post(name: NSNotification.Name("RefreshBackground"), object: nil)
    }
    
    private func formatCacheSize() -> String {
        if cacheSize < 1024 {
            return "\(cacheSize) B"
        } else if cacheSize < 1024 * 1024 {
            return String(format: "%.1f KB", Double(cacheSize) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(cacheSize) / (1024.0 * 1024.0))
        }
    }
    
    private func updateCacheSize() {
        cacheSize = WallpaperCache.shared.getCacheSize()
    }
    
    private func clearWallpaperCache() {
        WallpaperCache.shared.clearCache()
        // Update cache size display
        updateCacheSize()
    }
}

#Preview {
    SettingsView()
} 