//
//  ContentView.swift
//  Launchpad
//
//  Created by liao on 2025/8/9.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var appManager = AppManager.shared
    @StateObject private var windowManager = WindowManager.shared
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var filteredApps: [AppItem] = [] {
        didSet {
            let appsPerPage = gridColumns * 6 // 每页6行
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
    
    private let categories = ["All", "Utilities", "Productivity", "Entertainment", "Development", "System"]
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 20), count: gridColumns)
    }
    
    var body: some View {
        ZStack {
            // 半透明模糊背景
            Rectangle()
                .fill(.clear)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            // 关闭按钮
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
                // 顶部工具栏
                HStack {
                    // 顶部搜索栏
                    searchBar
                    
                    // 设置按钮
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
                
                // 分类选择器
//                categorySelector
                
                // 应用网格
                if appManager.isLoading {
                    loadingView
                } else {
                    pagedAppGrid
                }
                
                // 页面指示器
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
            // 点击背景空白区域关闭窗口
            animateAndClose()
        }
        .onAppear {
            appManager.loadInstalledApps()
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
        .onChange(of: searchText) { _ in
            filterApps()
        }
        .onChange(of: selectedCategory) { _ in
            filterApps()
        }
        .onChange(of: appManager.installedApps) { _ in
            filterApps()
        }
        .onChange(of: filteredApps) { newApps in
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
        
        let appsPerPage = gridColumns * 6 // 每页6行
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
        let appsPerPage = gridColumns * 6
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
                        // 透明的点击区域 - 扩大点击热区
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 24, height: 24)
                        
                        // 实际的圆点 - 保持视觉大小不变
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
        
        // 重置到第一页
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
                let appsPerPage = self.gridColumns * 6
                let totalPages = max(1, (self.filteredApps.count + appsPerPage - 1) / appsPerPage)
                if self.currentPage > 0 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.currentPage -= 1
                    }
                }
                return nil
            } else if event.keyCode == 124 { // Right arrow key
                let appsPerPage = self.gridColumns * 6
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
    @State private var appIcon: NSImage?
    
    var body: some View {
        VStack(spacing: 8) {
            // 应用图标
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
                
                if let appIcon = appIcon {
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
            
            // 应用名称
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
        .onAppear {
            loadAppIcon()
        }
    }
    
    private func loadAppIcon() {
        guard let path = app.path else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: path)
            
            DispatchQueue.main.async {
                self.appIcon = icon
            }
        }
    }
}

struct AppItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let icon: String
    let category: String
    let bundleIdentifier: String
    let path: String?
    
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
