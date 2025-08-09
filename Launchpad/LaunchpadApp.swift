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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(.clear)
                .onAppear {
                    windowManager.setupWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
