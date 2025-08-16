//
//  GestureManager.swift
//  Launchpad
//
//  Created by liao on 2025/8/15.
//

import SwiftUI
import AppKit
import CoreGraphics

class GestureManager: ObservableObject {
    static let shared = GestureManager()
    
    private let windowManager = WindowManager.shared
    
    // 手势监听相关
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    
    // 手势防抖动
    private var lastGestureTime = Date()
    private let gestureDebounceInterval: TimeInterval = 0.5
    
    private init() {}
    
    func startMonitoring() {
        // 监听四指手势事件
        setupGestureMonitoring()
        print("🎮 四指手势监听已启动")
        print("🤏 四指捏合 = 显示窗口")
        print("🖐 四指张开 = 隐藏窗口")
        
        // 测试窗口管理器连接
        print("🔗 窗口管理器状态 - isWindowVisible: \(windowManager.isWindowVisible)")
    }
    
    func stopMonitoring() {
        if let localMonitor = localEventMonitor {
            NSEvent.removeMonitor(localMonitor)
            localEventMonitor = nil
        }
        
        if let globalMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalMonitor)
            globalEventMonitor = nil
        }
        
        print("🛑 手势监听已停止")
    }
    
    private func setupGestureMonitoring() {
        // 监听放大/缩小手势 (四指捏合/张开)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.gesture]) { [weak self] event in
            self?.handleMagnifyGesture(event)
        }
        
        // 监听本地放大/缩小手势
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.gesture]) { [weak self] event in
            self?.handleMagnifyGesture(event)
            return event
        }
        
        print("📱 手势监听器已设置 - 监听 .magnify 事件")
    }
    
    private func handleMagnifyGesture(_ event: NSEvent) {
        
        print("🔍 捕获到手势 - 看看是啥\(event.subtype)")

        
        let magnification = event.magnification
        let now = Date()
        
        // 防抖动：如果距离上次手势时间太短，忽略
        guard now.timeIntervalSince(lastGestureTime) > gestureDebounceInterval else {
            return
        }
        
        print("🔍 捕获到手势 - 放大倍数: \(magnification)")
        
        // 四指捏合 (缩小手势) - magnification < 0，显示窗口
        if magnification < -0.2 && !windowManager.isWindowVisible {
            print("🤏 检测到四指捏合手势 - 显示窗口")
            showWindow()
            lastGestureTime = now
        }
        // 四指张开 (放大手势) - magnification > 0，隐藏窗口
        else if magnification > 0.2 && windowManager.isWindowVisible {
            print("🖐 检测到四指张开手势 - 隐藏窗口")
            hideWindow()
            lastGestureTime = now
        }
    }
    
    private func showWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.windowManager.showWindow()
        }
    }
    
    private func hideWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.windowManager.hideWindow()
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
