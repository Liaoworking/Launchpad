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
    @Published var launchpadItems: [LaunchpadItem] = [] // 新的统一数据源
    @Published var isLoading = false
    
    static let shared = AppManager()
    
    private init() {
        // Try to load cached data when initializing
        loadCachedApps()
    }
    
    // MARK: - Cache Management
    private let cacheKey = "CachedInstalledApps"
    private let launchpadCacheKey = "CachedLaunchpadItems" // 新的文件夹缓存key
    private let cacheExpirationKey = "CacheExpirationDate"
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour cache expiration
    
    private func loadCachedApps() {
        let expirationDate = UserDefaults.standard.object(forKey: cacheExpirationKey) as? Date ?? Date.distantPast
        let isExpired = Date().timeIntervalSince(expirationDate) >= cacheExpirationInterval
        
        // 尝试加载LaunchpadItem缓存
        if let launchpadCachedData = UserDefaults.standard.data(forKey: launchpadCacheKey), !isExpired {
            do {
                let cachedLaunchpadItems = try JSONDecoder().decode([LaunchpadItem].self, from: launchpadCachedData)
                DispatchQueue.main.async {
                    self.launchpadItems = cachedLaunchpadItems
                    // 同时更新旧的installedApps以保持兼容性
                    self.installedApps = self.extractAppsFromLaunchpadItems(cachedLaunchpadItems)
                }
                return
            } catch {
                // 清除无效的LaunchpadItem缓存
                UserDefaults.standard.removeObject(forKey: launchpadCacheKey)
            }
        }
        
        // 回退到旧的AppItem缓存
        if let cachedData = UserDefaults.standard.data(forKey: cacheKey), !isExpired {
            do {
                let cachedApps = try JSONDecoder().decode([AppItem].self, from: cachedData)
                DispatchQueue.main.async {
                    self.installedApps = cachedApps
                    // 将AppItem转换为LaunchpadItem
                    self.launchpadItems = cachedApps.map { .app($0) }
                }
                return
            } catch {
                // 清除无效的AppItem缓存
                UserDefaults.standard.removeObject(forKey: cacheKey)
            }
        }
        
        // 清除过期缓存
        if isExpired {
            UserDefaults.standard.removeObject(forKey: cacheKey)
            UserDefaults.standard.removeObject(forKey: launchpadCacheKey)
            UserDefaults.standard.removeObject(forKey: cacheExpirationKey)
        }
        
        // 没有缓存或缓存过期，立即加载
        loadInstalledApps()
    }
    
    // 从LaunchpadItem中提取所有AppItem
    private func extractAppsFromLaunchpadItems(_ items: [LaunchpadItem]) -> [AppItem] {
        var apps: [AppItem] = []
        for item in items {
            switch item {
            case .app(let app):
                apps.append(app)
            case .folder(let folder):
                apps.append(contentsOf: folder.apps)
            }
        }
        return apps
    }
    
    private func saveAppsToCache(_ apps: [AppItem]) {
        if let encodedData = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(encodedData, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheExpirationKey)
        }
    }
    
    private func saveLaunchpadItemsToCache(_ items: [LaunchpadItem]) {
        if let encodedData = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encodedData, forKey: launchpadCacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheExpirationKey)
        }
    }
    
    func loadInstalledApps() {
        // If there's cached data, display it first
        if !installedApps.isEmpty || !launchpadItems.isEmpty {
            // Refresh in background, don't show loading state
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let (apps, launchpadItems) = self?.scanInstalledAppsAndFolders() ?? ([], [])
                
                DispatchQueue.main.async {
                    self?.installedApps = apps
                    self?.launchpadItems = launchpadItems
                    self?.saveAppsToCache(apps)
                    self?.saveLaunchpadItemsToCache(launchpadItems)
                }
            }
        } else {
            // No cached data, show loading state
            isLoading = true
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let (apps, launchpadItems) = self?.scanInstalledAppsAndFolders() ?? ([], [])
                
                DispatchQueue.main.async {
                    self?.installedApps = apps
                    self?.launchpadItems = launchpadItems
                    self?.isLoading = false
                    self?.saveAppsToCache(apps)
                    self?.saveLaunchpadItemsToCache(launchpadItems)
                }
            }
        }
    }
    
    // Force refresh (clear cache)
    func forceRefreshApps() {
        // 清除所有缓存
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: launchpadCacheKey)
        UserDefaults.standard.removeObject(forKey: cacheExpirationKey)
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let (apps, launchpadItems) = self?.scanInstalledAppsAndFolders() ?? ([], [])
            
            DispatchQueue.main.async {
                self?.installedApps = apps
                self?.launchpadItems = launchpadItems
                self?.isLoading = false
                self?.saveAppsToCache(apps)
                self?.saveLaunchpadItemsToCache(launchpadItems)
            }
        }
    }
    
    // 新的扫描方法，支持文件夹结构
    private func scanInstalledAppsAndFolders() -> ([AppItem], [LaunchpadItem]) {
        var allApps: [AppItem] = []
        var launchpadItems: [LaunchpadItem] = []
        
        // 扫描系统应用目录 (/System/Applications)
        let systemApplicationsUrl = URL(fileURLWithPath: "/System/Applications")
        let systemItems = loadApplicationsWithFolders(from: systemApplicationsUrl, isLoadingDirectory: true)
        launchpadItems.append(contentsOf: systemItems)
        
        // 扫描用户安装的应用目录 (/Applications)
        let applicationUrl = URL(fileURLWithPath: "/Applications")
        let userItems = loadApplicationsWithFolders(from: applicationUrl, isLoadingDirectory: true)
        launchpadItems.append(contentsOf: userItems)
        
        // 扫描用户主目录的Applications目录（如果存在）
        if let userApplicationsPath = getUserApplicationsPath() {
            let userApplicationUrl = URL(fileURLWithPath: userApplicationsPath)
            let homeItems = loadApplicationsWithFolders(from: userApplicationUrl, isLoadingDirectory: true)
            launchpadItems.append(contentsOf: homeItems)
        }
        
        // 提取所有应用用于兼容性
        allApps = extractAppsFromLaunchpadItems(launchpadItems)
        
        // 排序
        allApps = allApps.sorted { $0.name < $1.name }
        launchpadItems = launchpadItems.sorted { $0.name < $1.name }
        
        return (allApps, launchpadItems)
    }
    
    private func scanInstalledApps() -> [AppItem] {
        var apps: [AppItem] = []
        
        // Scan system applications (/System/Applications)
        let systemApplicationsUrl = URL(fileURLWithPath: "/System/Applications")
        apps.append(contentsOf: loadApplications(from: systemApplicationsUrl, isLoadingDirectory: true))
        
        // Scan user installed applications (/Applications)
        let applicationUrl = URL(fileURLWithPath: "/Applications")
        apps.append(contentsOf: loadApplications(from: applicationUrl, isLoadingDirectory: true))
        
        // Scan user's home Applications directory if it exists
        if let userApplicationsPath = getUserApplicationsPath() {
            let userApplicationUrl = URL(fileURLWithPath: userApplicationsPath)
            apps.append(contentsOf: loadApplications(from: userApplicationUrl, isLoadingDirectory: true))
        }
        
        // Sort by name
        return apps.sorted { $0.name < $1.name }
    }
    
    // Get user's home Applications directory path
    private func getUserApplicationsPath() -> String? {
        let userHomePath = FileManager.default.homeDirectoryForCurrentUser.path
        let components = userHomePath.components(separatedBy: "/")
        if components.count >= 3,
           components[1] == "Users" {
            let homePath = "/\(components[1])/\(components[2])/Applications"
            // Check if the directory exists
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: homePath, isDirectory: &isDirectory) && isDirectory.boolValue {
                return homePath
            }
        }
        return nil
    }
    
    // 支持文件夹结构的应用加载方法
    private func loadApplicationsWithFolders(from folderUrl: URL, isLoadingDirectory: Bool) -> [LaunchpadItem] {
        let fileManager = FileManager.default
        var launchpadItems: [LaunchpadItem] = []
        
        do {
            let resourceKeys: [URLResourceKey] = [.isApplicationKey, .isDirectoryKey]
            guard let enumerator = fileManager.enumerator(at: folderUrl,
                                                        includingPropertiesForKeys: resourceKeys,
                                                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
                                                        errorHandler: { url, error in
                return true
            }) else {
                return []
            }
            
            while let url = enumerator.nextObject() as? URL {
                // 跳过隐藏文件和系统文件
                let fileName = url.lastPathComponent
                if fileName.hasPrefix(".") || fileName.hasPrefix("~") {
                    continue
                }
                
                if url.lastPathComponent.hasSuffix(".app") {
                    if let appInfo = getAppInfo(from: url.path) {
                        launchpadItems.append(.app(appInfo))
                    }
                    continue
                }
                
                guard isLoadingDirectory else { continue }
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                if resourceValues.isDirectory == true {
                    // 递归加载子文件夹中的应用
                    let subItems = loadApplicationsWithFolders(from: url, isLoadingDirectory: false)
                    if !subItems.isEmpty {
                        // 只有当文件夹中有应用时才创建文件夹项目
                        let folderApps = subItems.compactMap { item -> AppItem? in
                            if case .app(let app) = item {
                                return app
                            }
                            return nil
                        }
                        
                        if !folderApps.isEmpty {
                            let folderName = fileName
                            let folderCategory = determineFolderCategory(folderName: folderName, apps: folderApps)
                            let folder = FolderItem(
                                name: folderName,
                                category: folderCategory,
                                apps: folderApps,
                                folderPath: url.path
                            )
                            launchpadItems.append(.folder(folder))
                        }
                    }
                }
            }
        } catch {
            // 静默处理错误
        }
        
        return launchpadItems
    }
    
    // 根据文件夹名称和包含的应用确定文件夹分类
    private func determineFolderCategory(folderName: String, apps: [AppItem]) -> String {
        let lowercasedName = folderName.lowercased()
        
        // 基于文件夹名称的分类
        if lowercasedName.contains("util") || lowercasedName.contains("tool") {
            return "Utilities"
        } else if lowercasedName.contains("game") || lowercasedName.contains("entertain") {
            return "Entertainment"
        } else if lowercasedName.contains("develop") || lowercasedName.contains("dev") || lowercasedName.contains("code") {
            return "Development"
        } else if lowercasedName.contains("product") || lowercasedName.contains("office") {
            return "Productivity"
        } else if lowercasedName.contains("system") {
            return "System"
        }
        
        // 基于文件夹中应用的主要分类
        let categoryCount = Dictionary(grouping: apps, by: { $0.category })
            .mapValues { $0.count }
        
        if let mostCommonCategory = categoryCount.max(by: { $0.value < $1.value })?.key {
            return mostCommonCategory
        }
        
        return "Utilities"
    }
    
    // Optimized application loading using FileManager enumerator
    private func loadApplications(from folderUrl: URL, isLoadingDirectory: Bool) -> [AppItem] {
        let fileManager = FileManager.default
        var applications: [AppItem] = []
        
        do {
            let resourceKeys: [URLResourceKey] = [.isApplicationKey, .isDirectoryKey]
            guard let enumerator = fileManager.enumerator(at: folderUrl,
                                                        includingPropertiesForKeys: resourceKeys,
                                                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
                                                        errorHandler: { url, error in
                print("Error accessing \(url): \(error)")
                return true
            }) else {
                return []
            }
            
            while let url = enumerator.nextObject() as? URL {
                if url.lastPathComponent.hasSuffix(".app") {
                    if let appInfo = getAppInfo(from: url.path) {
                        applications.append(appInfo)
                    }
                    continue
                }
                
                guard isLoadingDirectory else { continue }
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                if resourceValues.isDirectory == true {
                    applications.append(contentsOf: loadApplications(from: url, isLoadingDirectory: false))
                }
            }
        } catch {
            print("Error loading applications from \(folderUrl): \(error)")
        }
        
        return applications
    }
    

    
    private func getAppInfo(from path: String) -> AppItem? {
        let bundle = Bundle(path: path)
        guard let bundle = bundle else { return nil }
        
        let appName = bundle.infoDictionary?["CFBundleDisplayName"] as? String ??
                     bundle.infoDictionary?["CFBundleName"] as? String ??
                     (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        
        let bundleIdentifier = bundle.bundleIdentifier ?? ""
        
        // Categorize based on application type
        let category = categorizeApp(bundleIdentifier: bundleIdentifier, appName: appName)
        
        return AppItem(
            name: appName,
            icon: "app", // Keep for backward compatibility
            category: category,
            bundleIdentifier: bundleIdentifier,
            path: path
        )
    }
    
    private func categorizeApp(bundleIdentifier: String, appName: String) -> String {
        let lowercasedName = appName.lowercased()
        let lowercasedBundle = bundleIdentifier.lowercased()
        
        // System applications
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
        
        // Development tools
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
        
        // Productivity tools
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
        
        // Entertainment applications
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
        
        // Utility tools
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

 