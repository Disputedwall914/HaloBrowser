//
//  TabRowView.swift
//  HaloBrowser
//
//  Created by Julian on 12.03.26.
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Tab Row
struct TabRowView: View {
    @Bindable var model: BrowserViewModel
    let tab: HaloTab
    @Binding var draggedTabId: UUID?
    let dropIndex: Int
    @State private var isHovering = false
    @State private var isDragOver = false

    var isActive: Bool   { model.activeTabId == tab.id }
    var isDragging: Bool { draggedTabId == tab.id }

    var body: some View {
        let dotColor = tab.isSleeping ? Color.gray : model.activeSpace.color
        let titleColor = tab.isSleeping ? Color.secondary : Color.primary
        let backgroundColor: Color = {
            if isActive {
                return model.activeSpace.color.opacity(0.15)
            }
            if isDragOver {
                return Color.primary.opacity(0.07)
            }
            if isHovering {
                return Color.primary.opacity(0.05)
            }
            return Color.clear
        }()
        let strokeColor = isActive ? model.activeSpace.color.opacity(0.3) : Color.clear

        HStack(spacing: 8) {
            Circle().fill(dotColor).frame(width: 7, height: 7)
            TabFaviconView(url: tab.faviconURL)
            Text(tab.displayTitle).font(.system(size: 13)).lineLimit(1)
                .foregroundColor(titleColor)
            Spacer()
            if isActive || isHovering {
                Button { model.closeTab(tab) } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain).transition(.opacity)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 8).fill(backgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(strokeColor, lineWidth: 1))
        .opacity(isDragging ? 0.4 : 1.0).scaleEffect(isDragging ? 0.97 : 1.0)
        .overlay {
            if isDragOver {
                Rectangle()
                    .fill(model.activeSpace.color)
                    .frame(height: 2)
                    .cornerRadius(1)
                    .padding(.horizontal, 8)
                    .offset(y: -22)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .animation(.easeInOut(duration: 0.1),  value: isDragging)
        .onTapGesture { model.selectTab(tab) }
        .contextMenu {
            Button("Duplicate Tab")      { model.openURLInNewTab(tab.persistedURLString) }
            /// ⭐️ "Pin Tab" context menu pins the tab into the favorites strip
            Button("Favourite")            { model.moveTabToPinned(tab) }
            if !model.activeSpace.folders.isEmpty {
                Menu("Move to Folder") {
                    ForEach(model.activeSpace.folders) { folder in
                        Button(folder.name) { model.moveTabToFolder(tab, folder: folder) }
                    }
                }
            }
            Divider()
            Button(tab.isSleeping ? "Wake Tab" : "Sleep Tab") {
                tab.isSleeping ? tab.wake() : tab.sleep(); model.saveState()
            }
            Divider()
            Button("Close Tab", role: .destructive) { model.closeTab(tab) }
        }
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        #endif
    }
}
