//
//  LaunchpadApp.swift
//  Launchpad
//
//  Created by liao on 2025/8/9.
//

import SwiftUI
import AppKit

@main
struct LaunchpadApp: App {
    @StateObject private var windowManager = WindowManager.shared
    @StateObject private var gestureManager = GestureManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(.clear)
                .onAppear {
                    windowManager.setupWindow()
                    gestureManager.startMonitoring()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
    
    init() {
        // 设置应用代理，防止应用在所有窗口关闭后退出
        NSApplication.shared.delegate = AppDelegate.shared
    }
}

// 应用代理类，确保应用在窗口关闭后不退出
class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()
    
    private override init() {
        super.init()
    }
    
    // 当所有窗口关闭时，返回false防止应用退出
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // 处理应用激活
    func applicationDidBecomeActive(_ notification: Notification) {
        // 当应用被激活时，可以在这里处理逻辑
    }
}
