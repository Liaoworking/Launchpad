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
    
    private init() {
        // 初始化时尝试加载缓存
        loadCachedApps()
    }
    
    // MARK: - 缓存管理
    private let cacheKey = "CachedInstalledApps"
    private let cacheExpirationKey = "CacheExpirationDate"
    private let cacheExpirationInterval: TimeInterval = 3600 // 1小时缓存过期
    
    private func loadCachedApps() {
        if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
           let cachedApps = try? JSONDecoder().decode([AppItem].self, from: cachedData) {
            // 检查缓存是否过期
            let expirationDate = UserDefaults.standard.object(forKey: cacheExpirationKey) as? Date ?? Date.distantPast
            if Date().timeIntervalSince(expirationDate) < cacheExpirationInterval {
                // 缓存未过期，直接使用
                DispatchQueue.main.async {
                    self.installedApps = cachedApps
                }
                return
            }
        }
        
        // 没有缓存或缓存过期，立即加载
        loadInstalledApps()
    }
    
    private func saveAppsToCache(_ apps: [AppItem]) {
        if let encodedData = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(encodedData, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheExpirationKey)
        }
    }
    
    func loadInstalledApps() {
        // 如果有缓存数据，先显示缓存
        if !installedApps.isEmpty {
            // 后台刷新，不显示loading状态
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let apps = self?.scanInstalledApps() ?? []
                
                DispatchQueue.main.async {
                    self?.installedApps = apps
                    self?.saveAppsToCache(apps)
                }
            }
        } else {
            // 没有缓存数据，显示loading状态
            isLoading = true
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let apps = self?.scanInstalledApps() ?? []
                
                DispatchQueue.main.async {
                    self?.installedApps = apps
                    self?.isLoading = false
                    self?.saveAppsToCache(apps)
                }
            }
        }
    }
    
    // 强制刷新（清除缓存）
    func forceRefreshApps() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = self?.scanInstalledApps() ?? []
            
            DispatchQueue.main.async {
                self?.installedApps = apps
                self?.isLoading = false
                self?.saveAppsToCache(apps)
            }
        }
    }
    
    private func scanInstalledApps() -> [AppItem] {
        var apps: [AppItem] = []
        
        // 扫描用户安装的应用 (/Applications)
        let userApplicationsPath = "/Applications"
        apps.append(contentsOf: scanApplicationsDirectory(userApplicationsPath))
        
        // 扫描系统应用 (/System/Applications)
        let systemApplicationsPath = "/System/Applications"
        apps.append(contentsOf: scanApplicationsDirectory(systemApplicationsPath))
        
        // 按名称排序
        return apps.sorted { $0.name < $1.name }
    }
    
    private func scanApplicationsDirectory(_ path: String) -> [AppItem] {
        var apps: [AppItem] = []
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            
            for fileName in contents {
                if fileName.hasSuffix(".app") {
                    let fullPath = "\(path)/\(fileName)"
                    
                    // 检查是否为目录（应用包）
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                        if let appInfo = getAppInfo(from: fullPath) {
                            apps.append(appInfo)
                        }
                    }
                }
            }
        } catch {
            print("Error scanning applications directory \(path): \(error)")
        }
        
        return apps
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
        
        // 使用简单的默认图标，实际图标将在UI层按需加载
        let icon = "app"
        
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

 