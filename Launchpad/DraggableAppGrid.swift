//
//  DraggableAppGrid.swift
//  Launchpad
//
//  Created by liao on 2025/8/9.
//

import SwiftUI

struct DraggableAppGrid: View {
    let apps: [AppItem]
    let columns: [GridItem]
    let onAppTap: (AppItem) -> Void
    @Binding var draggedApp: AppItem?
    @Binding var appsOrder: [AppItem]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 30) {
            ForEach(appsOrder) { app in
                AppIconView(app: app)
                    .onTapGesture {
                        onAppTap(app)
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
        .padding(.horizontal, 20)
    }
}

struct DropViewDelegate: DropDelegate {
    let item: AppItem
    @Binding var appsOrder: [AppItem]
    @Binding var draggedApp: AppItem?
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedApp = draggedApp else { return false }
        
        if let fromIndex = appsOrder.firstIndex(where: { $0.id == draggedApp.id }),
           let toIndex = appsOrder.firstIndex(where: { $0.id == item.id }) {
            
            withAnimation(.easeInOut(duration: 0.3)) {
                let movedItem = appsOrder.remove(at: fromIndex)
                appsOrder.insert(movedItem, at: toIndex)
            }
        }
        
        self.draggedApp = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Can add visual feedback for drag enter here
    }
    
    func dropExited(info: DropInfo) {
        // Can add visual feedback for drag exit here
    }
} 