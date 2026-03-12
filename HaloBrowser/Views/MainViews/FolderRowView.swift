//
//  FolderRowView.swift
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

// MARK: - Folder Row
struct FolderRowView: View {
    @Bindable var model: BrowserViewModel
    @Bindable var folder: HaloFolder
    @Binding var draggedTabId: UUID?
    let isDropTarget: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: folder.isExpanded ? "folder.fill" : "folder")
                    .font(.system(size: 13)).foregroundColor(folder.color)
                Text(folder.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                if !folder.tabs.isEmpty {
                    Text("\(folder.tabs.count)")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08)).clipShape(Capsule())
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    .rotationEffect(.degrees(folder.isExpanded ? 90 : 0))
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: folder.isExpanded)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(isDropTarget ? folder.color.opacity(0.18) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(isDropTarget ? folder.color.opacity(0.5) : Color.clear, lineWidth: 1.5))
            .animation(.easeInOut(duration: 0.15), value: isDropTarget)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { folder.isExpanded.toggle() } }
            .contextMenu {
                Button("Delete Folder", role: .destructive) { model.removeFolder(folder) }
            }

            if folder.isExpanded {
                VStack(spacing: 2) {
                    ForEach(folder.tabs) { tab in
                        HStack(spacing: 8) {
                            Rectangle().fill(folder.color.opacity(0.4)).frame(width: 2).padding(.leading, 14)
                            Circle().fill(tab.isSleeping ? Color.gray : folder.color).frame(width: 6, height: 6)
                            TabFaviconView(url: tab.faviconURL)
                            Text(tab.displayTitle).font(.system(size: 12)).lineLimit(1)
                                .foregroundColor(tab.isSleeping ? .secondary : .primary)
                            Spacer()
                            Button { model.closeTab(tab) } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    .opacity(model.activeTabId == tab.id ? 1 : 0.3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6).padding(.trailing, 12)
                        .background(model.activeTabId == tab.id ? folder.color.opacity(0.12) : Color.clear)
                        .cornerRadius(6)
                        .onTapGesture { model.selectTab(tab) }
                        .contextMenu {
                            Button("Move Out of Folder") { model.moveTabOutOfFolder(tab, folder: folder) }
                            Divider()
                            Button("Close Tab", role: .destructive) { model.closeTab(tab) }
                        }
                        .onDrag {
                            draggedTabId = tab.id
                            return NSItemProvider(object: tab.id.uuidString as NSString)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top))).padding(.bottom, 4)
            }
        }
    }
}
