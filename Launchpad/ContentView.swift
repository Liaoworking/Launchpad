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
    @State private var backgroundOpacity: Double = 1.0  // Set initial opacity to 1.0 to avoid black screen
    @State private var isAnimating = false
    @State private var isWallpaperReady = false  // Added: Mark whether wallpaper is ready
    @State private var isInitialized = false  // Added: Mark whether initialization is completed
    
    private let fileManager = FileManager.default
    
    // Read parameters from settings
    @AppStorage("blurRadius") private var settingsBlurRadius: Double = 30
    @AppStorage("enableBackgroundAnimation") private var enableBackgroundAnimation: Bool = true
    @AppStorage("backgroundOpacity") private var settingsBackgroundOpacity: Double = 1.0
    @AppStorage("overlayOpacity") private var overlayOpacity: Double = 0.2
    @AppStorage("autoRefreshBackground") private var autoRefreshBackground: Bool = false
    @AppStorage("refreshInterval") private var refreshInterval: Double = 300
    
    private let maxCaptureAttempts = 3
    
    var body: some View {
        ZStack {
            // Wallpaper background layer
            if let backgroundImage = backgroundImage {
                Image(nsImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: blurRadius)
                    .scaleEffect(1.1) // Slightly scale up to avoid blur edges
                    .opacity(backgroundOpacity)  // Use backgroundOpacity directly, no longer depend on isWallpaperReady
                    .ignoresSafeArea()
                    .onAppear {
                        if enableBackgroundAnimation {
                            animateBackground()
                        }
                    }
            }
            
            // Fallback background layer - always displayed, but opacity adjusted based on wallpaper status
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
                .opacity(isWallpaperReady ? 0.0 : 1.0) // Hide fallback background when wallpaper is ready
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
            // Immediately load cached wallpaper synchronously to avoid black screen
            loadCachedWallpaper()
            
            // Setup auto refresh
            setupAutoRefresh()
            
            // Mark initialization completed
            isInitialized = true
        }
        .task {
            // Only preload wallpaper asynchronously after initialization is completed
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
            // Overlay opacity changes will be automatically updated through @AppStorage
        }
    }
    
    private func setupAutoRefresh() {
        guard autoRefreshBackground else { return }
        
        Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            refreshBackground()
        }
    }
    
    private func refreshBackground() {
        // Reset state and re-capture
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
        // Start loading wallpaper immediately, don't wait
        captureScreenBackground()
    }
    
    private func loadCachedWallpaper() {
        // Load wallpaper from cache synchronously to avoid black screen
        if let cachedImage = WallpaperCache.shared.getWallpaper() {
            self.backgroundImage = cachedImage
            self.blurRadius = CGFloat(self.settingsBlurRadius)
            self.backgroundOpacity = self.settingsBackgroundOpacity
            self.isWallpaperReady = true
            self.isLoading = false
            print("✅ Successfully loaded wallpaper from cache")
        } else {
            print("⚠️ No wallpaper in cache, starting to capture new wallpaper")
            // If not in cache, start capturing immediately
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
        
        // Only clear cache when it actually needs to be updated
        if WallpaperCache.shared.shouldUpdateCache() && isInitialized {
            print("🔄 Wallpaper changed, clearing old cache")
            WallpaperCache.shared.clearCache()
        }
        
        // Try to get from cache first
        if let cachedImage = WallpaperCache.shared.getWallpaper() {
            DispatchQueue.main.async {
                self.backgroundImage = cachedImage
                self.blurRadius = CGFloat(self.settingsBlurRadius)
                self.backgroundOpacity = self.settingsBackgroundOpacity
                self.isWallpaperReady = true
                self.isLoading = false
                print("✅ Successfully got wallpaper from cache")
            }
            return
        }
        
        // Not in cache, load new wallpaper
        DispatchQueue.global(qos: .userInteractive).async {
            let image = captureScreen()
            
            DispatchQueue.main.async {
                if let image = image {
                    self.backgroundImage = image
                    // Apply parameters from settings
                    self.blurRadius = CGFloat(self.settingsBlurRadius)
                    self.backgroundOpacity = self.settingsBackgroundOpacity
                    
                    // Save to cache
                    WallpaperCache.shared.setWallpaper(image)
                    print("💾 New wallpaper saved to cache")
                    
                    // After wallpaper is ready, display immediately (no animation)
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
        // Only preload after initialization is completed
        guard isInitialized else { return }
        
        // Check if cache needs to be updated (only when necessary)
        if WallpaperCache.shared.shouldUpdateCache() {
            print("🔄 Wallpaper change detected during preload, clearing old cache")
            WallpaperCache.shared.clearCache()
        }
        
        // Try to get wallpaper from cache first
        if let cachedImage = WallpaperCache.shared.getWallpaper() {
            DispatchQueue.main.async {
                // Only set if there's no current background image
                if self.backgroundImage == nil {
                    self.backgroundImage = cachedImage
                    self.blurRadius = CGFloat(self.settingsBlurRadius)
                    self.backgroundOpacity = self.settingsBackgroundOpacity
                    print("✅ Got wallpaper from cache during preload")
                }
                
                // Display cached wallpaper immediately
                withAnimation(.easeIn(duration: 0.05)) {
                    self.isWallpaperReady = true
                }
            }
            return
        }
        
        // Not in cache, load new wallpaper
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInteractive).async {
                let image = self.captureScreen()
                
                DispatchQueue.main.async {
                    if let image = image {
                        self.backgroundImage = image
                        self.blurRadius = CGFloat(self.settingsBlurRadius)
                        self.backgroundOpacity = self.settingsBackgroundOpacity
                        
                        // Save to cache
                        WallpaperCache.shared.setWallpaper(image)
                        print("💾 New wallpaper saved to cache during preload")
                        
                        // Display wallpaper immediately, no delay
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
        // Use NSWorkspace to get desktop wallpaper, no permissions required
        if let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: NSScreen.main!) {
            if let image = NSImage(contentsOf: wallpaperURL) {
                // Check if wallpaper has changed
                checkWallpaperChange(image: image)
                return image
            }
        }
        
        // If the above method fails, try using NSScreen method
        if let image = captureUsingNSScreen() {
            return image
        }
        
        return nil
    }
    
    private func checkWallpaperChange(image: NSImage) {
        // Check if wallpaper has changed
        if let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: NSScreen.main!) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: wallpaperURL.path)
                if let modificationDate = attributes[.modificationDate] as? Date {
                    let currentKey = "wallpaper_\(Int(modificationDate.timeIntervalSince1970))"
                    // Smart cache key generation logic can be added here
                }
            } catch {
                // If unable to get file attributes, continue using default cache
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
    @State private var scrollAccumulator = 0.0
    @State private var lastScrollTime = Date()
    @State private var isScrolling = false
    @State private var iconSize: CGFloat = 100 // 动态计算的图标大小
    @State private var screenSize: CGSize = .zero // 屏幕尺寸
    
    @AppStorage("gridColumns") private var gridColumns = 8
    @AppStorage("gridRows") private var gridRows = 5
    
    private let categories = ["All", "Utilities", "Productivity", "Entertainment", "Development", "System"]
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 20), count: gridColumns)
    }
    
    // 计算动态图标大小
    private func calculateIconSize() -> CGFloat {
        guard screenSize.height > 0 else { return 100 }
        
        // 基于屏幕高度计算图标大小
        // 顶部边距(20px) + 搜索栏(44px) + 搜索栏下边距(20px) = 84px
        // 底部页面指示器(48px) + 底部边距(40px) = 88px
        // 总预留空间 = 84 + 88 = 172px
        let reservedHeight: CGFloat = 172
        let availableHeight = screenSize.height - reservedHeight
        
        // 计算每行可用高度（图标 + 文字 + 行间距）
        let gridSpacing: CGFloat = 30 // LazyVGrid的spacing
        let textHeight: CGFloat = 32 // 文字预估高度(两行文字 + 间距)
        let iconTextSpacing: CGFloat = 8 // 图标和文字之间的间距
        
        // 总的垂直间距 = (行数-1) * gridSpacing
        let totalGridSpacing = CGFloat(gridRows - 1) * gridSpacing
        
        // 可用于内容的高度
        let contentHeight = availableHeight - totalGridSpacing
        
        // 每行的高度
        let rowHeight = contentHeight / CGFloat(gridRows)
        
        // 图标高度 = 行高 - 文字高度 - 图标文字间距
        let iconHeight = rowHeight - textHeight - iconTextSpacing
        
        // 限制图标大小在合理范围内：最小50px，最大150px
        let clampedIconHeight = max(50, min(150, iconHeight))
        
        print("📐 屏幕高度: \(screenSize.height), 可用高度: \(availableHeight), 行高: \(rowHeight), 图标大小: \(clampedIconHeight)")
        
        return clampedIconHeight
    }
    
    // 获取当前屏幕尺寸
    private func updateScreenSize() {
        if let screen = NSScreen.main {
            screenSize = screen.visibleFrame.size
            iconSize = calculateIconSize()
        }
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
                    searchBar.safeAreaPadding(.top).padding(.vertical, 10)
                    
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
            .padding(.horizontal, 80)
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
            // 更新屏幕尺寸和图标大小
            updateScreenSize()
            
            // App manager will automatically load cache when initializing, here we only need to set up keyboard listener
            setupKeyboardListener()
            NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { event in
                handleScrollEvent(event)
                return event
            }
            
            // 监听窗口大小变化
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: nil,
                queue: .main
            ) { _ in
                updateScreenSize()
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
        .onChange(of: gridRows) { _, _ in
            // 网格行数改变时重新计算图标大小
            iconSize = calculateIconSize()
        }
        .onChange(of: gridColumns) { _, _ in
            // 网格列数改变时重新计算图标大小
            iconSize = calculateIconSize()
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
                        AppIconView(app: app, iconSize: iconSize)
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
                if self.currentPage > 0 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.page.update(.previous)
                        self.currentPage -= 1
                    }
                }
                return nil
            } else if event.keyCode == 124 { // Right arrow key
                let appsPerPage = self.gridColumns * self.gridRows
                let totalPages = max(1, (self.filteredApps.count + appsPerPage - 1) / appsPerPage)
                if self.currentPage < totalPages - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.page.update(.next)
                        self.currentPage += 1
                    }
                }
                return nil
            }
            return event
        }
    }
    
    private func handleScrollEvent(_ event: NSEvent) {
        let currentTime = Date()
        let timeSinceLastScroll = currentTime.timeIntervalSince(lastScrollTime)
        
        // Ignore vertical and tiny scrolls, only handle obvious horizontal scrolls
        guard abs(event.deltaX) > abs(event.deltaY) && abs(event.deltaX) > 1.0 else {
            return
        }
        
        // Debounce mechanism: ignore if just paged and time interval is less than 0.3 seconds
        if isScrolling && timeSinceLastScroll < 0.3 {
            return
        }
        
        // Reset or continue accumulating scroll
        if timeSinceLastScroll > 0.5 {
            scrollAccumulator = 0.0
        }
        
        // Accumulate horizontal scroll value
        scrollAccumulator += event.deltaX
        lastScrollTime = currentTime
        
        // Set scroll threshold: need to accumulate enough scroll amount to trigger page flip
        let scrollThreshold: Double = 20.0
        
        if abs(scrollAccumulator) >= scrollThreshold {
            isScrolling = true
            
            if scrollAccumulator > 0 {
                // Scroll left, previous page
                if currentPage > 0 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        page.update(.previous)
                        currentPage -= 1
                    }
                }
            } else {
                // Scroll right, next page
                if currentPage < totalScrollPages - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        page.update(.next)
                        currentPage += 1
                    }
                }
            }
            
            // Reset accumulator
            scrollAccumulator = 0.0
            
            // Set a delay to prevent continuous page flipping
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isScrolling = false
            }
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
    let iconSize: CGFloat
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
                        .frame(width: iconSize, height: iconSize)
                } else {
                    Image(systemName: app.icon)
                        .font(.system(size: iconSize * 0.4)) // 系统图标大小为图标尺寸的40%
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            // Application name
            Text(app.name)
                .font(.system(size: max(9, iconSize * 0.11), weight: .medium)) // 字体大小也动态调整
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .shadow(radius: 2)
                .frame(width: iconSize * 0.8) // 文字宽度为图标宽度的80%
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
