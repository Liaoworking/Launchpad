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
        }
    }
    
    func closeWindow() {
        NSApplication.shared.terminate(nil)
    }
} 
