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
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("壁纸模糊设置") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("模糊强度")
                            Spacer()
                            Text("\(Int(blurRadius))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $blurRadius, in: 5...50, step: 1)
                            .accentColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("背景透明度")
                            Spacer()
                            Text("\(Int(backgroundOpacity * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $backgroundOpacity, in: 0.3...1.0, step: 0.05)
                            .accentColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("遮罩透明度")
                            Spacer()
                            Text("\(Int(overlayOpacity * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $overlayOpacity, in: 0.0...0.5, step: 0.05)
                            .accentColor(.blue)
                    }
                }
                
                Section("动画设置") {
                    Toggle("启用背景动画", isOn: $enableBackgroundAnimation)
                    
                    if enableBackgroundAnimation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("动画说明")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("背景会有轻微的呼吸效果，让界面更加生动")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("自动刷新") {
                    Toggle("自动刷新背景", isOn: $autoRefreshBackground)
                    
                    if autoRefreshBackground {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("刷新间隔")
                                Spacer()
                                Text("\(Int(refreshInterval / 60)) 分钟")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $refreshInterval, in: 60...1800, step: 60)
                                .accentColor(.blue)
                        }
                    }
                }
                
                Section("预览") {
                    VStack(spacing: 16) {
                        Text("模糊效果预览")
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
                                Text("预览文本")
                                    .foregroundColor(.white)
                                    .font(.title2)
                                    .fontWeight(.medium)
                            )
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                }
                
                Section("操作") {
                    Button("重置为默认值") {
                        resetToDefaults()
                    }
                    .foregroundColor(.orange)
                    
                    Button("刷新背景") {
                        refreshBackground()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 700)
    }
    
    private func resetToDefaults() {
        blurRadius = 30
        enableBackgroundAnimation = true
        backgroundOpacity = 1.0
        overlayOpacity = 0.2
        autoRefreshBackground = false
        refreshInterval = 300
    }
    
    private func refreshBackground() {
        // 通知 ContentView 刷新背景
        NotificationCenter.default.post(name: NSNotification.Name("RefreshBackground"), object: nil)
    }
}

#Preview {
    SettingsView()
} 