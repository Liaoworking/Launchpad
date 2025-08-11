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
        // Try to load cached data when initializing
        loadCachedApps()
    }
    
    // MARK: - Cache Management
    private let cacheKey = "CachedInstalledApps"
    private let cacheExpirationKey = "CacheExpirationDate"
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour cache expiration
    
    private func loadCachedApps() {
        if let cachedData = UserDefaults.standard.data(forKey: cacheKey) {
            do {
                let cachedApps = try JSONDecoder().decode([AppItem].self, from: cachedData)
                
                // Check if cache is expired
                let expirationDate = UserDefaults.standard.object(forKey: cacheExpirationKey) as? Date ?? Date.distantPast
                if Date().timeIntervalSince(expirationDate) < cacheExpirationInterval {
                    // Cache not expired, use directly
                    DispatchQueue.main.async {
                        self.installedApps = cachedApps
                    }
                    return
                }
            } catch {
                // Clear invalid cache
                UserDefaults.standard.removeObject(forKey: cacheKey)
                UserDefaults.standard.removeObject(forKey: cacheExpirationKey)
            }
        }
        
        // No cache or cache expired, load immediately
        loadInstalledApps()
    }
    
    private func saveAppsToCache(_ apps: [AppItem]) {
        if let encodedData = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(encodedData, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheExpirationKey)
        }
    }
    
    func loadInstalledApps() {
        // If there's cached data, display it first
        if !installedApps.isEmpty {
            // Refresh in background, don't show loading state
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let apps = self?.scanInstalledApps() ?? []
                
                DispatchQueue.main.async {
                    self?.installedApps = apps
                    self?.saveAppsToCache(apps)
                }
            }
        } else {
            // No cached data, show loading state
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
    
    // Force refresh (clear cache)
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

 