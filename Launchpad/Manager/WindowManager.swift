//
//  WindowManager.swift
//  Launchpad
//
//  Created by liao on 2025/8/9.
//

import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var isWindowVisible = true
    private var window: NSWindow?
    
    private init() {}
    
    func setupWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let window = NSApplication.shared.windows.first else { return }
            self?.window = window
            
            // Set window level to overlay MenuBar
            window.level = .screenSaver
            
            // Set window behavior
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            // Set transparency
            window.isOpaque = false
            window.backgroundColor = NSColor.clear
            window.hasShadow = false
            
            // Set window style - remove fullSizeContentView to ensure proper event handling
            window.styleMask = [.borderless, .fullSizeContentView]
//            window.styleMask = [.borderless]

            // Set window size to full screen (including MenuBar area)
            if let screen = NSScreen.main {
                window.setFrame(screen.frame, display: true)
            }
            
            // Set window to full screen
            window.toggleFullScreen(nil)
            
            // 监听窗口关闭事件
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.hideWindow()
            }
        }
    }
    
    func showWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let window = self.window {
                // 确保窗口可见
                window.setIsVisible(true)
                window.makeKeyAndOrderFront(nil)
                
                // 强制激活应用
                NSApplication.shared.activate(ignoringOtherApps: true)
                
                // 确保窗口在最前面
                window.level = .screenSaver
                window.orderFrontRegardless()
                
                self.isWindowVisible = true
                print("🪟 窗口已显示 - Level: \(window.level.rawValue), Visible: \(window.isVisible)")
            } else {
                print("⚠️ 窗口引用为空，尝试重新获取")
                // 尝试重新获取窗口
                if let newWindow = NSApplication.shared.windows.first {
                    self.window = newWindow
                    self.showWindow() // 递归调用显示
                } else {
                    print("❌ 无法找到窗口")
                }
            }
        }
    }
    
    func hideWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let window = self.window {
                window.orderOut(nil)
                window.setIsVisible(false)
                self.isWindowVisible = false
                print("🫥 窗口已隐藏 - Visible: \(window.isVisible)")
            }
        }
    }
    
    func closeWindow() {
        hideWindow()
    }
    
    private func createNewWindow() {
        // 创建新窗口的逻辑
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.window = newWindow
        
        // 重新设置窗口属性
        newWindow.level = .screenSaver
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newWindow.isOpaque = false
        newWindow.backgroundColor = NSColor.clear
        newWindow.hasShadow = false
        
        if let screen = NSScreen.main {
            newWindow.setFrame(screen.frame, display: true)
        }
        
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.toggleFullScreen(nil)
        
        self.isWindowVisible = true
        print("🆕 新窗口已创建并显示")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 
