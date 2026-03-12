//
//  SidebarView.swift
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

// MARK: - Sidebar
struct SidebarView: View {
    @Bindable var model: BrowserViewModel
    @Binding var showSettings: Bool
    @State private var draggedTabId: UUID?
    @State private var showAddFolder = false
    @State private var newFolderName = ""
    @State private var newFolderColor: Color = .blue
    @State private var dropTargetFolderId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(model.activeSpace.name).font(.headline).fontWeight(.bold)
                Spacer()
                Button {
                    withAnimation(.spring()) { model.omniboxInput = ""; model.showOmnibox = true }
                } label: {
                    Image(systemName: "plus")
                        .padding(8)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 0) {

                    // ── ⭐️ Pinned Tabs Section (Arc-style favicon strip) ──
                    // Only shown when there is at least one pinned tab.
                    // Tapping a pin SELECTS that tab (no new tab opened — it IS the tab).
                    if !model.activeSpace.pinnedTabs.isEmpty {
                        PinnedTabsSectionView(model: model)
                            .padding(.bottom, 4)
                        Divider().padding(.horizontal, 12).padding(.bottom, 4)
                    }

                    // ── Folders ──
                    if !model.activeSpace.folders.isEmpty {
                        VStack(spacing: 2) {
                            ForEach(model.activeSpace.folders) { folder in
                                FolderRowView(model: model, folder: folder,
                                              draggedTabId: $draggedTabId,
                                              isDropTarget: dropTargetFolderId == folder.id)
                                .onDrop(of: [UTType.text], delegate: FolderDropDelegate(
                                    model: model, targetFolder: folder,
                                    draggedTabId: $draggedTabId,
                                    dropTargetFolderId: $dropTargetFolderId))
                            }
                        }
                        .padding(.horizontal, 8).padding(.bottom, 4)
                        Divider().padding(.horizontal, 12).padding(.bottom, 4)
                    }

                    // ── Regular Tabs ──
                    VStack(spacing: 2) {
                        ForEach(Array(model.activeSpace.tabs.enumerated()), id: \.element.id) { index, tab in
                            TabRowView(model: model, tab: tab, draggedTabId: $draggedTabId, dropIndex: index)
                                .onDrag {
                                    draggedTabId = tab.id
                                    return NSItemProvider(object: tab.id.uuidString as NSString)
                                }
                                .onDrop(of: [UTType.text], delegate: TabDropDelegate(
                                    model: model, targetTab: tab, draggedTabId: $draggedTabId))
                        }
                        if !model.activeSpace.tabs.isEmpty {
                            Color.clear.frame(height: 8)
                                .onDrop(of: [UTType.text], delegate: TabDropDelegate(
                                    model: model, targetTab: nil, draggedTabId: $draggedTabId))
                        }
                    }
                    .padding(.horizontal, 8).padding(.top, 4)

                    // Add Folder Button
                    Button { showAddFolder.toggle() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus").font(.system(size: 11)).foregroundColor(.secondary)
                            Text("New Folder").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6).padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain).padding(.top, 8)

                    if showAddFolder {
                        HStack(spacing: 6) {
                            ColorPicker("", selection: $newFolderColor, supportsOpacity: false)
                                .labelsHidden().frame(width: 24)
                            TextField("Folder name", text: $newFolderName)
                                .textFieldStyle(.roundedBorder).font(.system(size: 12))
                                .onSubmit { commitNewFolder() }
                            Button("Add") { commitNewFolder() }
                                .buttonStyle(.plain).font(.system(size: 12))
                                .foregroundColor(model.activeSpace.color)
                        }
                        .padding(.horizontal, 12).padding(.bottom, 8)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
                .padding(.top, 8)
            }

            Spacer()

            // Space Switcher + Settings gear
            HStack {
                ForEach(model.spaces) { space in
                    Button { withAnimation { model.setActiveSpace(space) } } label: {
                        Image(systemName: space.iconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 26, height: 26)
                            .background(space.color.opacity(model.activeSpaceId == space.id ? 0.45 : 0.2))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(model.activeSpaceId == space.id ? 0.4 : 0.0), lineWidth: 1))
                    }
                    .buttonStyle(.plain).padding(.horizontal, 4)
                }
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.06)).clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding().frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.05))
        }
    }

    private func commitNewFolder() {
        guard !newFolderName.isEmpty else { return }
        model.addFolder(name: newFolderName, color: newFolderColor)
        newFolderName = ""; showAddFolder = false
    }
}
