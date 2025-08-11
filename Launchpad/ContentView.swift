//
//  ContentView.swift
//  Launchpad
//
//  Created by liao on 2025/8/9.
//

import SwiftUI
import AppKit
import CoreGraphics
import ScreenCaptureKit

// MARK: - Wallpaper Background View
struct WallpaperBackgroundView: View {
    @State private var backgroundImage: NSImage?
    @State private var isLoading = true
    @State private var captureAttempts = 0
    @State private var blurRadius: CGFloat = 30
    @State private var backgroundOpacity: Double = 1.0  // 初始透明度设为1.0，避免黑屏
    @State private var isAnimating = false
    @State private var isWallpaperReady = false  // 新增：标记壁纸是否准备就绪
    @State private var isInitialized = false  // 新增：标记是否已完成初始化
    
    private let fileManager = FileManager.default
    
    // 从设置中读取参数
    @AppStorage("blurRadius") private var settingsBlurRadius: Double = 30
    @AppStorage("enableBackgroundAnimation") private var enableBackgroundAnimation: Bool = true
    @AppStorage("backgroundOpacity") private var settingsBackgroundOpacity: Double = 1.0
    @AppStorage("overlayOpacity") private var overlayOpacity: Double = 0.2
    @AppStorage("autoRefreshBackground") private var autoRefreshBackground: Bool = false
    @AppStorage("refreshInterval") private var refreshInterval: Double = 300
    
    private let maxCaptureAttempts = 3
    
    var body: some View {
        ZStack {
            // 壁纸背景层
            if let backgroundImage = backgroundImage {
                Image(nsImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: blurRadius)
                    .scaleEffect(1.1) // Slightly scale up to avoid blur edges
                    .opacity(backgroundOpacity)  // 直接使用backgroundOpacity，不再依赖isWallpaperReady
                    .ignoresSafeArea()
                    .onAppear {
                        if enableBackgroundAnimation {
                            animateBackground()
                        }
                    }
            }
            
            // Fallback背景层 - 始终显示，但透明度根据壁纸状态调整
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.15, green: 0.15, blue: 0.2),
                            Color(red: 0.1, green: 0.1, blue: 0.15),
                            Color(red: 0.05, green: 0.05, blue: 0.1),
                            Color(red: 0.08, green: 0.08, blue: 0.12)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
                .opacity(isWallpaperReady ? 0.0 : 1.0) // 壁纸准备好时隐藏fallback背景
                .onAppear {
                    if enableBackgroundAnimation {
                        animateBackground()
                    }
                }
            
            // Enhanced overlay for better text readability
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(overlayOpacity),
                            Color.black.opacity(overlayOpacity * 0.5),
                            Color.black.opacity(overlayOpacity * 0.8)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
        }
        .onAppear {
            // 立即同步加载缓存壁纸，避免黑屏
            loadCachedWallpaper()
            
            // 设置自动刷新
            setupAutoRefresh()
            
            // 标记初始化完成
            isInitialized = true
        }
        .task {
            // 只有在初始化完成后才异步预加载壁纸
            guard isInitialized else { return }
            await preloadWallpaper()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshBackground"))) { _ in
            refreshBackground()
        }
        .onChange(of: settingsBlurRadius) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                blurRadius = CGFloat(newValue)
            }
        }
        .onChange(of: settingsBackgroundOpacity) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                backgroundOpacity = newValue
            }
        }
        .onChange(of: overlayOpacity) { _, _ in
            // 遮罩透明度变化会通过 @AppStorage 自动更新
        }
    }
    
    private func setupAutoRefresh() {
        guard autoRefreshBackground else { return }
        
        Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            refreshBackground()
        }
    }
    
    private func refreshBackground() {
        // 重置状态并重新捕获
        captureAttempts = 0
        captureScreenBackground()
    }
    
    private func animateBackground() {
        guard !isAnimating && enableBackgroundAnimation else { return }
        isAnimating = true
        
        // Subtle breathing animation for the background
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            blurRadius = CGFloat(settingsBlurRadius) + 5
            backgroundOpacity = settingsBackgroundOpacity * 0.95
        }
        
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 4.0)) {
                blurRadius = CGFloat(settingsBlurRadius)
                backgroundOpacity = settingsBackgroundOpacity
            }
            isAnimating = false
        }
    }
    
    private func checkScreenRecordingPermission() {
        // 立即开始加载壁纸，不等待
        captureScreenBackground()
    }
    
    private func loadCachedWallpaper() {
        // 同步从缓存加载壁纸，避免黑屏
        if let cachedImage = WallpaperCache.shared.getWallpaper() {
            self.backgroundImage = cachedImage
            self.blurRadius = CGFloat(self.settingsBlurRadius)
            self.backgroundOpacity = self.settingsBackgroundOpacity
            self.isWallpaperReady = true
            self.isLoading = false
            print("✅ 从缓存加载壁纸成功")
        } else {
            print("⚠️ 缓存中没有壁纸，开始捕获新壁纸")
            // 如果缓存中没有，立即开始捕获
            captureScreenBackground()
        }
    }
    
    private func captureScreenBackground() {
        guard captureAttempts < maxCaptureAttempts else {
            isLoading = false
            return
        }
        
        captureAttempts += 1
        isLoading = true
        
        // 只有在确实需要更新缓存时才清除
        if WallpaperCache.shared.shouldUpdateCache() && isInitialized {
            print("🔄 壁纸发生变化，清除旧缓存")
            WallpaperCache.shared.clearCache()
        }
        
        // 先尝试从缓存获取
        if let cachedImage = WallpaperCache.shared.getWallpaper() {
            DispatchQueue.main.async {
                self.backgroundImage = cachedImage
                self.blurRadius = CGFloat(self.settingsBlurRadius)
                self.backgroundOpacity = self.settingsBackgroundOpacity
                self.isWallpaperReady = true
                self.isLoading = false
                print("✅ 从缓存获取壁纸成功")
            }
            return
        }
        
        // 缓存中没有，则加载新壁纸
        DispatchQueue.global(qos: .userInteractive).async {
            let image = captureScreen()
            
            DispatchQueue.main.async {
                if let image = image {
                    self.backgroundImage = image
                    // 应用设置中的参数
                    self.blurRadius = CGFloat(self.settingsBlurRadius)
                    self.backgroundOpacity = self.settingsBackgroundOpacity
                    
                    // 保存到缓存
                    WallpaperCache.shared.setWallpaper(image)
                    print("💾 新壁纸已保存到缓存")
                    
                    // 壁纸准备就绪后，立即显示（无动画）
                    self.isWallpaperReady = true
                    self.backgroundOpacity = self.settingsBackgroundOpacity
                } else if self.captureAttempts < self.maxCaptureAttempts {
                    // Retry after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.captureScreenBackground()
                    }
                }
                self.isLoading = false
            }
        }
    }
    
    private func preloadWallpaper() async {
        // 只有在初始化完成后才进行预加载
        guard isInitialized else { return }
        
        // 检查是否需要更新缓存（只在必要时）
        if WallpaperCache.shared.shouldUpdateCache() {
            print("🔄 预加载时检测到壁纸变化，清除旧缓存")
            WallpaperCache.shared.clearCache()
        }
        
        // 先尝试从缓存获取壁纸
        if let cachedImage = WallpaperCache.shared.getWallpaper() {
            DispatchQueue.main.async {
                // 如果当前没有背景图片，才设置
                if self.backgroundImage == nil {
                    self.backgroundImage = cachedImage
                    self.blurRadius = CGFloat(self.settingsBlurRadius)
                    self.backgroundOpacity = self.settingsBackgroundOpacity
                    print("✅ 预加载时从缓存获取壁纸")
                }
                
                // 立即显示缓存的壁纸
                withAnimation(.easeIn(duration: 0.05)) {
                    self.isWallpaperReady = true
                }
            }
            return
        }
        
        // 缓存中没有，则加载新壁纸
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInteractive).async {
                let image = self.captureScreen()
                
                DispatchQueue.main.async {
                    if let image = image {
                        self.backgroundImage = image
                        self.blurRadius = CGFloat(self.settingsBlurRadius)
                        self.backgroundOpacity = self.settingsBackgroundOpacity
                        
                        // 保存到缓存
                        WallpaperCache.shared.setWallpaper(image)
                        print("💾 预加载时新壁纸已保存到缓存")
                        
                        // 立即显示壁纸，无延迟
                        withAnimation(.easeIn(duration: 0.1)) {
                            self.isWallpaperReady = true
                        }
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    private func captureScreen() -> NSImage? {
        // 使用 NSWorkspace 获取桌面壁纸，不需要权限
        if let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: NSScreen.main!) {
            if let image = NSImage(contentsOf: wallpaperURL) {
                // 检查壁纸是否发生变化
                checkWallpaperChange(image: image)
                return image
            }
        }
        
        // 如果上面的方法失败，尝试使用 NSScreen 方法
        if let image = captureUsingNSScreen() {
            return image
        }
        
        return nil
    }
    
    private func checkWallpaperChange(image: NSImage) {
        // 检查壁纸是否发生变化
        if let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: NSScreen.main!) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: wallpaperURL.path)
                if let modificationDate = attributes[.modificationDate] as? Date {
                    let currentKey = "wallpaper_\(Int(modificationDate.timeIntervalSince1970))"
                    // 这里可以添加更智能的缓存键生成逻辑
                }
            } catch {
                // 如果无法获取文件属性，继续使用默认缓存
            }
        }
    }
    
    private func captureUsingNSScreen() -> NSImage? {
        guard let screen = NSScreen.main else { return nil }
        
        // Try to create a simple screenshot using available methods
        let bounds = screen.frame
        
        // Create a simple colored background as fallback
        let size = bounds.size
        let image = NSImage(size: size)
        
        image.lockFocus()
        let context = NSGraphicsContext.current?.cgContext
        
        // Draw a gradient background similar to the fallback
        let colors = [
            CGColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0),
            CGColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0),
            CGColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0),
            CGColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        ]
        
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 0.3, 0.7, 1.0])!
        context?.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
        
        image.unlockFocus()
        
        return image
    }
}

struct ContentView: View {
    @StateObject private var appManager = AppManager.shared
    @StateObject private var windowManager = WindowManager.shared
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var filteredApps: [AppItem] = [] {
        didSet {
            let appsPerPage = gridColumns * gridRows
            let totalPages = max(1, (filteredApps.count + appsPerPage - 1) / appsPerPage)
            totalScrollPages = totalPages
        }
    }
    @State private var appsOrder: [AppItem] = []
    @State private var draggedApp: AppItem?
    @State private var showingSettings = false
    @State private var isClosing = false
    @State private var currentPage = 0
    @State private var previousDeltaX = 0.0
    @State private var totalScrollPages = 1
    
    @AppStorage("gridColumns") private var gridColumns = 8
    @AppStorage("gridRows") private var gridRows = 5
    
    private let categories = ["All", "Utilities", "Productivity", "Entertainment", "Development", "System"]
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 20), count: gridColumns)
    }
    
    var body: some View {
        ZStack {
            // Wallpaper blur background
            WallpaperBackgroundView()
            
            // Close button
//            VStack {
//                HStack {
//                    Spacer()
//                    Button(action: {
//                        animateAndClose()
//                    }) {
//                        Image(systemName: "xmark.circle.fill")
//                            .font(.system(size: 24))
//                            .foregroundColor(.white.opacity(0.8))
//                            .background(
//                                Circle()
//                                    .fill(Color.black.opacity(0.3))
//                                    .frame(width: 32, height: 32)
//                            )
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                    .padding(.trailing, 20)
//                    .padding(.top, 20)
//                }
//                Spacer()
//            }
            
            VStack(spacing: 0) {
                // Top toolbar
                HStack {
                    // Top search bar
                    searchBar.safeAreaPadding(.top)
                    
                    // Settings button
//                    Button(action: {
//                        showingSettings = true
//                    }) {
//                        Image(systemName: "gearshape")
//                            .font(.system(size: 18))
//                            .foregroundColor(.white)
//                            .frame(width: 40, height: 40)
//                            .background(
//                                RoundedRectangle(cornerRadius: 8)
//                                    .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 8)
//                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
//                                    )
//                            )
//                    }
//                    .buttonStyle(PlainButtonStyle())
                }
                
                // Category selector
//                categorySelector
                
                // Application grid
//                if appManager.isLoading {
//                    loadingView
//                } else {
//                    pagedAppGrid
//                }
                    pagedAppGrid

                // Page indicator
                if !appManager.isLoading && !filteredApps.isEmpty {
                    pageIndicator
                }
                

                
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .scaleEffect(isClosing ? 0.8 : 1.0)
        .opacity(isClosing ? 0.0 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isClosing)
        .onTapGesture {
            // Click on background blank area to close window
            animateAndClose()
        }
        .onAppear {
            // App manager will automatically load cache when initializing, here we only need to set up keyboard listener
            setupKeyboardListener()
            NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { event in
                if previousDeltaX == 0 && event.deltaX != 0 {
                    if event.deltaX > 0 {
                        withAnimation {
                            page.update(.previous)
                            if currentPage > 0 {
                                currentPage -= 1
                            }
                        }
                    } else {
                        withAnimation {
                            page.update(.next)
                            if currentPage < totalScrollPages - 1 {
                                currentPage += 1
                            }
                        }
                    }
                }
                previousDeltaX = event.deltaX
                return event
            }
        }
        .onChange(of: searchText) { _, _ in
            filterApps()
        }
        .onChange(of: selectedCategory) { _, _ in
            filterApps()
        }
        .onChange(of: appManager.installedApps) { _, _ in
            filterApps()
        }
        .onChange(of: filteredApps) { _, newApps in
            if appsOrder.isEmpty || appsOrder.count != newApps.count {
                appsOrder = newApps
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 12))
            
            TextField("Search", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12))
                .foregroundColor(.white)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .frame(width: 250, height: 24)
        .padding(.horizontal,10)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.init(white: 1.0, opacity: 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.bottom, 20)
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedCategory == category ? .white : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory == category ? 
                                          Color.blue.opacity(0.3) : 
                                          Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(selectedCategory == category ? 
                                                   Color.blue.opacity(0.5) : 
                                                   Color.gray.opacity(0.3), 
                                                   lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.bottom, 30)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("Loading applications...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    @StateObject var page: Page = .first()
    private var pagedAppGrid: some View {
        
        let appsPerPage = gridColumns * gridRows
        let totalPages = max(1, (filteredApps.count + appsPerPage - 1) / appsPerPage)
        let items = Array(0..<totalPages)

        return Pager(page: page,
                     data: items,
                     id: \.self) { pageIndex in
            let startIndex = pageIndex * appsPerPage
            let endIndex = min(startIndex + appsPerPage, filteredApps.count)
            let pageApps = Array(filteredApps[startIndex..<endIndex])
            VStack(content: {
                LazyVGrid(columns: columns, spacing: 30) {
                    ForEach(pageApps) { app in
                        AppIconView(app: app)
                            .onTapGesture {
                                animateAndClose {
                                    launchApp(app)
                                }
                            }
                            .onDrag {
                                draggedApp = app
                                return NSItemProvider(object: app.name as NSString)
                            }
                            .onDrop(of: [.text], delegate: DropViewDelegate(
                                item: app,
                                appsOrder: $appsOrder,
                                draggedApp: $draggedApp
                            ))
                            .scaleEffect(draggedApp?.id == app.id ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: draggedApp?.id)
                    }
                }
                Spacer()
            })
            .background {
                Color.black.opacity(0.001)
            }
        }.allowsKeyboardControl(false)
    }
    
    private var pageIndicator: some View {
        let appsPerPage = gridColumns * gridRows
        let totalPages = max(1, (filteredApps.count + appsPerPage - 1) / appsPerPage)
        
        return HStack(spacing: 0) {
            ForEach(0..<totalPages, id: \.self) { pageIndex in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        page.update(.new(index: pageIndex))
                        currentPage = pageIndex
                    }
                }) {
                    ZStack {
                        // Transparent click area - expand click hot zone
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 24, height: 24)
                        
                        // Actual dot - keep visual size unchanged
                        Circle()
                            .fill(currentPage == pageIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == pageIndex ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.bottom, 40)
    }
    
    private func filterApps() {
        filteredApps = appManager.installedApps.filter { app in
            let matchesSearch = searchText.isEmpty || 
                app.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == "All" || 
                app.category == selectedCategory
            return matchesSearch && matchesCategory
        }
        
        // Reset to first page
        currentPage = 0
    }
    
    private func launchApp(_ app: AppItem) {
        appManager.launchApp(app)
    }
    
    private func setupKeyboardListener() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC key
                animateAndClose()
                return nil
            } else if event.keyCode == 123 { // Left arrow key
                let appsPerPage = self.gridColumns * self.gridRows
                let _ = max(1, (self.filteredApps.count + appsPerPage - 1) / appsPerPage)
                if self.currentPage > 0 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.currentPage -= 1
                    }
                }
                return nil
            } else if event.keyCode == 124 { // Right arrow key
                let appsPerPage = self.gridColumns * self.gridRows
                let totalPages = max(1, (self.filteredApps.count + appsPerPage - 1) / appsPerPage)
                if self.currentPage < totalPages - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.currentPage += 1
                    }
                }
                return nil
            }
            return event
        }
    }
    
    private func animateAndClose(success: (()->Void)? = nil) {
        isClosing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            success?()
            windowManager.closeWindow()
        }
    }
}

struct AppIconView: View {
    let app: AppItem
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Application icon
            ZStack {
//                RoundedRectangle(cornerRadius: 16)
//                    .fill(
//                        LinearGradient(
//                            gradient: Gradient(colors: [
//                                Color(red: 0.3, green: 0.3, blue: 0.4),
//                                Color(red: 0.2, green: 0.2, blue: 0.3)
//                            ]),
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        )
//                    )
//                    .frame(width: 75, height: 75)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 30)
//                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
//                    )
//                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Use the pre-loaded NSImage from AppItem for instant display
                if let appIcon = app.image {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                } else {
                    Image(systemName: app.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            // Application name
            Text(app.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .shadow(radius: 2)
                .frame(width: 80)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Wallpaper Cache Manager
class WallpaperCache {
    static let shared = WallpaperCache()
    private let cache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let wallpaperKey = "current_wallpaper"
    
    // 缓存统计
    private var cacheHits = 0
    private var cacheMisses = 0
    
    // 当前壁纸的标识符
    private var currentWallpaperIdentifier: String?
    
    private init() {
        cache.countLimit = 5 // Cache up to 5 wallpapers
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB memory limit
        
        // 创建缓存目录
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("Launchpad/WallpaperCache")
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // 初始化时设置当前壁纸标识符，避免首次启动时误判
        currentWallpaperIdentifier = generateWallpaperIdentifier()
    }
    
    func getWallpaper() -> NSImage? {
        // 先从内存缓存获取
        if let cachedImage = cache.object(forKey: wallpaperKey as NSString) {
            cacheHits += 1
            return cachedImage
        }
        
        // 从磁盘缓存获取
        let cacheFile = cacheDirectory.appendingPathComponent("\(wallpaperKey).png")
        if let image = NSImage(contentsOf: cacheFile) {
            // 加载到内存缓存
            cache.setObject(image, forKey: wallpaperKey as NSString)
            cacheHits += 1
            return image
        }
        
        cacheMisses += 1
        return nil
    }
    
    func setWallpaper(_ image: NSImage) {
        // 保存到内存缓存
        cache.setObject(image, forKey: wallpaperKey as NSString)
        
        // 保存到磁盘缓存
        let cacheFile = cacheDirectory.appendingPathComponent("\(wallpaperKey).png")
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try? pngData.write(to: cacheFile)
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        return totalSize
    }
    
    func getCacheStats() -> (hits: Int, misses: Int, hitRate: Double) {
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        return (hits: cacheHits, misses: cacheMisses, hitRate: hitRate)
    }
    
    func generateWallpaperIdentifier() -> String? {
        guard let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: NSScreen.main!) else {
            return nil
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: wallpaperURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date,
               let fileSize = attributes[.size] as? Int64 {
                // 使用文件修改时间和大小生成标识符
                return "wallpaper_\(Int(modificationDate.timeIntervalSince1970))_\(fileSize)"
            }
        } catch {
            // 如果无法获取文件属性，使用文件路径作为标识符
            return "wallpaper_\(wallpaperURL.lastPathComponent)"
        }
        
        return nil
    }
    
    func shouldUpdateCache() -> Bool {
        // 如果还没有当前标识符，说明是首次启动，不应该清除缓存
        guard let currentIdentifier = currentWallpaperIdentifier else {
            // 首次启动时，设置当前标识符但不清除缓存
            currentWallpaperIdentifier = generateWallpaperIdentifier()
            return false
        }
        
        let newIdentifier = generateWallpaperIdentifier()
        if newIdentifier != currentIdentifier {
            print("🔄 壁纸标识符变化: \(currentIdentifier) -> \(newIdentifier ?? "nil")")
            currentWallpaperIdentifier = newIdentifier
            return true
        }
        return false
    }
    
    func getCacheInfo() -> (size: Int64, identifier: String?, stats: (hits: Int, misses: Int, hitRate: Double)) {
        let size = getCacheSize()
        let stats = getCacheStats()
        return (size: size, identifier: currentWallpaperIdentifier, stats: stats)
    }
}

// MARK: - Icon Cache Manager
class IconCache {
    static let shared = IconCache()
    private let cache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    
    private init() {
        cache.countLimit = 200 // Cache up to 200 icons
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit
    }
    
    func getIcon(for path: String) -> NSImage? {
        return cache.object(forKey: path as NSString)
    }
    
    func setIcon(_ icon: NSImage, for path: String) {
        cache.setObject(icon, forKey: path as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

struct AppItem: Identifiable, Equatable, Codable {
    var id = UUID()
    let name: String
    let icon: String // Keep for backward compatibility
    let category: String
    let bundleIdentifier: String
    let path: String?
    
    // Transient property to get NSImage from file path
    var image: NSImage? {
        guard let path = path else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }
    
    init(name: String, icon: String, category: String, bundleIdentifier: String = "", path: String? = nil) {
        self.name = name
        self.icon = icon
        self.category = category
        self.bundleIdentifier = bundleIdentifier
        self.path = path
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        return lhs.id == rhs.id
    }
}

#Preview {
    ContentView()
}
