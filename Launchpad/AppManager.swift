//
//  AppManager.swift
//  Launchpad
//
//  Created by liao on 2025/8/9.
//

import Foundation
import AppKit
import SwiftUI

class AppManager: ObservableObject {
    @Published var installedApps: [AppItem] = []
    @Published var isLoading = false
    
    static let shared = AppManager()
    
    private init() {}
    
    func loadInstalledApps() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = self?.scanInstalledApps() ?? []
            
            DispatchQueue.main.async {
                self?.installedApps = apps
                self?.isLoading = false
            }
        }
    }
    
    private func scanInstalledApps() -> [AppItem] {
        var apps: [AppItem] = []
        
        // 只扫描 /Applications 文件夹
        let applicationsPath = "/Applications"
        
        if let enumerator = FileManager.default.enumerator(atPath: applicationsPath) {
            while let fileName = enumerator.nextObject() as? String {
                if fileName.hasSuffix(".app") {
                    let fullPath = "\(applicationsPath)/\(fileName)"
                    if let appInfo = getAppInfo(from: fullPath) {
                        apps.append(appInfo)
                    }
                }
            }
        }
        
        // 按名称排序
        return apps.sorted { $0.name < $1.name }
    }
    
    private func getAppInfo(from path: String) -> AppItem? {
        let bundle = Bundle(path: path)
        guard let bundle = bundle else { return nil }
        
        let appName = bundle.infoDictionary?["CFBundleDisplayName"] as? String ??
                     bundle.infoDictionary?["CFBundleName"] as? String ??
                     (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        
        let bundleIdentifier = bundle.bundleIdentifier ?? ""
        
        // 根据应用类型分类
        let category = categorizeApp(bundleIdentifier: bundleIdentifier, appName: appName)
        
        // 获取应用图标
        let icon = getAppIcon(from: bundle)
        
        return AppItem(
            name: appName,
            icon: icon,
            category: category,
            bundleIdentifier: bundleIdentifier,
            path: path
        )
    }
    
    private func categorizeApp(bundleIdentifier: String, appName: String) -> String {
        let lowercasedName = appName.lowercased()
        let lowercasedBundle = bundleIdentifier.lowercased()
        
        // 系统应用
        if lowercasedBundle.contains("com.apple") || 
           lowercasedName.contains("finder") ||
           lowercasedName.contains("safari") ||
           lowercasedName.contains("mail") ||
           lowercasedName.contains("messages") ||
           lowercasedName.contains("facetime") ||
           lowercasedName.contains("photos") ||
           lowercasedName.contains("music") ||
           lowercasedName.contains("calendar") ||
           lowercasedName.contains("notes") ||
           lowercasedName.contains("maps") ||
           lowercasedName.contains("weather") ||
           lowercasedName.contains("calculator") ||
           lowercasedName.contains("preview") ||
           lowercasedName.contains("textedit") ||
           lowercasedName.contains("quicktime") ||
           lowercasedName.contains("app store") ||
           lowercasedName.contains("dictionary") ||
           lowercasedName.contains("stocks") ||
           lowercasedName.contains("voice memos") ||
           lowercasedName.contains("home") ||
           lowercasedName.contains("shortcuts") {
            return "System"
        }
        
        // 开发工具
        if lowercasedName.contains("xcode") ||
           lowercasedName.contains("terminal") ||
           lowercasedName.contains("visual studio") ||
           lowercasedName.contains("android studio") ||
           lowercasedName.contains("intellij") ||
           lowercasedName.contains("sublime") ||
           lowercasedName.contains("vscode") ||
           lowercasedName.contains("atom") ||
           lowercasedName.contains("vim") ||
           lowercasedName.contains("emacs") {
            return "Development"
        }
        
        // 生产力工具
        if lowercasedName.contains("microsoft word") ||
           lowercasedName.contains("microsoft excel") ||
           lowercasedName.contains("microsoft powerpoint") ||
           lowercasedName.contains("google chrome") ||
           lowercasedName.contains("firefox") ||
           lowercasedName.contains("slack") ||
           lowercasedName.contains("zoom") ||
           lowercasedName.contains("teams") ||
           lowercasedName.contains("notion") ||
           lowercasedName.contains("evernote") ||
           lowercasedName.contains("trello") ||
           lowercasedName.contains("asana") {
            return "Productivity"
        }
        
        // 娱乐应用
        if lowercasedName.contains("spotify") ||
           lowercasedName.contains("netflix") ||
           lowercasedName.contains("youtube") ||
           lowercasedName.contains("disney") ||
           lowercasedName.contains("steam") ||
           lowercasedName.contains("discord") ||
           lowercasedName.contains("twitch") ||
           lowercasedName.contains("instagram") ||
           lowercasedName.contains("facebook") ||
           lowercasedName.contains("twitter") {
            return "Entertainment"
        }
        
        // 实用工具
        return "Utilities"
    }
    
    private func getAppIcon(from bundle: Bundle) -> String {
        // 尝试获取应用程序的实际图标
        if let iconFile = bundle.infoDictionary?["CFBundleIconFile"] as? String {
            return iconFile
        }
        
        // 如果没有找到图标文件，尝试从 Info.plist 中获取
        if let iconFiles = bundle.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = iconFiles["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFilesList = primaryIcon["CFBundleIconFiles"] as? [String],
           let firstIcon = iconFilesList.first {
            return firstIcon
        }
        
        // 如果还是没有，使用应用名称来匹配 SF Symbols
        let appName = bundle.infoDictionary?["CFBundleDisplayName"] as? String ??
                     bundle.infoDictionary?["CFBundleName"] as? String ??
                     (bundle.bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        
        return getIconNameForApp(appName: appName)
    }
    
    private func getIconNameForApp(appName: String) -> String {
        let lowercasedName = appName.lowercased()
        
        // 系统应用图标映射
        if lowercasedName.contains("safari") { return "safari" }
        if lowercasedName.contains("mail") { return "envelope" }
        if lowercasedName.contains("messages") { return "message" }
        if lowercasedName.contains("facetime") { return "video" }
        if lowercasedName.contains("photos") { return "photo" }
        if lowercasedName.contains("music") { return "music.note" }
        if lowercasedName.contains("calendar") { return "calendar" }
        if lowercasedName.contains("notes") { return "note.text" }
        if lowercasedName.contains("maps") { return "map" }
        if lowercasedName.contains("weather") { return "cloud.sun" }
        if lowercasedName.contains("calculator") { return "plus.forwardslash.minus" }
        if lowercasedName.contains("terminal") { return "terminal" }
        if lowercasedName.contains("xcode") { return "hammer" }
        if lowercasedName.contains("finder") { return "folder" }
        if lowercasedName.contains("preview") { return "eye" }
        if lowercasedName.contains("textedit") { return "doc.text" }
        if lowercasedName.contains("quicktime") { return "play.rectangle" }
        if lowercasedName.contains("app store") { return "bag" }
        if lowercasedName.contains("dictionary") { return "book" }
        if lowercasedName.contains("stocks") { return "chart.line.uptrend.xyaxis" }
        if lowercasedName.contains("voice memos") { return "mic" }
        if lowercasedName.contains("home") { return "house" }
        if lowercasedName.contains("shortcuts") { return "square.grid.2x2" }
        if lowercasedName.contains("system preferences") || lowercasedName.contains("settings") { return "gearshape" }
        
        // 第三方应用图标映射
        if lowercasedName.contains("chrome") { return "globe" }
        if lowercasedName.contains("firefox") { return "flame" }
        if lowercasedName.contains("spotify") { return "music.note" }
        if lowercasedName.contains("netflix") { return "play.tv" }
        if lowercasedName.contains("youtube") { return "play.rectangle" }
        if lowercasedName.contains("steam") { return "gamecontroller" }
        if lowercasedName.contains("discord") { return "message" }
        if lowercasedName.contains("slack") { return "message" }
        if lowercasedName.contains("zoom") { return "video" }
        if lowercasedName.contains("teams") { return "person.3" }
        if lowercasedName.contains("word") { return "doc.text" }
        if lowercasedName.contains("excel") { return "tablecells" }
        if lowercasedName.contains("powerpoint") { return "rectangle.stack" }
        if lowercasedName.contains("visual studio") { return "hammer" }
        if lowercasedName.contains("android studio") { return "hammer" }
        if lowercasedName.contains("intellij") { return "hammer" }
        if lowercasedName.contains("sublime") { return "doc.text" }
        if lowercasedName.contains("vscode") { return "doc.text" }
        if lowercasedName.contains("atom") { return "doc.text" }
        if lowercasedName.contains("vim") { return "terminal" }
        if lowercasedName.contains("emacs") { return "terminal" }
        if lowercasedName.contains("notion") { return "doc.text" }
        if lowercasedName.contains("evernote") { return "note.text" }
        if lowercasedName.contains("trello") { return "rectangle.stack" }
        if lowercasedName.contains("asana") { return "checklist" }
        if lowercasedName.contains("instagram") { return "camera" }
        if lowercasedName.contains("facebook") { return "person.2" }
        if lowercasedName.contains("twitter") { return "bird" }
        
        // 默认图标
        return "app"
    }
    
    func launchApp(_ app: AppItem) {
        guard let path = app.path else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.launchPath = "/usr/bin/open"
            process.arguments = [path]
            
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Failed to launch app: \(error)")
            }
        }
    }
}

 