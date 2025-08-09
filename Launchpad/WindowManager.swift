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
    
    private init() {}
    
    func setupWindow() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first else { return }
            
            // 设置窗口级别为覆盖 MenuBar
            window.level = .screenSaver
            
            // 设置窗口行为
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            // 设置透明
            window.isOpaque = false
            window.backgroundColor = NSColor.clear
            window.hasShadow = false
            
            // 设置窗口样式 - 移除 fullSizeContentView 以确保事件处理正常
            window.styleMask = [.borderless, .fullSizeContentView]
//            window.styleMask = [.borderless]

            // 设置窗口大小为全屏（包括 MenuBar 区域）
            if let screen = NSScreen.main {
                window.setFrame(screen.frame, display: true)
            }
            
            // 设置窗口为全屏
            window.toggleFullScreen(nil)
        }
    }
    
    func closeWindow() {
        NSApplication.shared.terminate(nil)
    }
} 
