//
//  TabDropDelegate.swift
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

// MARK: - Drop Delegates

struct TabDropDelegate: DropDelegate {
    let model: BrowserViewModel
    let targetTab: HaloTab?
    @Binding var draggedTabId: UUID?

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [UTType.text]) }

    func dropEntered(info: DropInfo) {
        guard let fromId = draggedTabId else { return }
        let tabs = model.activeSpace.tabs
        guard let from = tabs.firstIndex(where: { $0.id == fromId }) else { return }
        if let targetTab, let to = tabs.firstIndex(where: { $0.id == targetTab.id }), from != to {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                model.activeSpace.tabs.move(fromOffsets: IndexSet(integer: from),
                                             toOffset: to > from ? to + 1 : to)
            }
            model.saveState()
        } else if targetTab == nil, from != tabs.count - 1 {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                model.activeSpace.tabs.move(fromOffsets: IndexSet(integer: from), toOffset: tabs.count)
            }
            model.saveState()
        }
    }

    func performDrop(info: DropInfo) -> Bool { draggedTabId = nil; return true }
}

struct FolderDropDelegate: DropDelegate {
    let model: BrowserViewModel
    let targetFolder: HaloFolder
    @Binding var draggedTabId: UUID?
    @Binding var dropTargetFolderId: UUID?

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [UTType.text]) }
    func dropEntered(info: DropInfo) { withAnimation(.easeInOut(duration: 0.15)) { dropTargetFolderId = targetFolder.id } }
    func dropExited(info: DropInfo)  { withAnimation(.easeInOut(duration: 0.15)) { if dropTargetFolderId == targetFolder.id { dropTargetFolderId = nil } } }

    func performDrop(info: DropInfo) -> Bool {
        guard let fromId = draggedTabId else { return false }
        let all = model.activeSpace.tabs + model.activeSpace.folders.flatMap(\.tabs) + model.activeSpace.pinnedTabs
        guard let tab = all.first(where: { $0.id == fromId }) else { return false }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { model.moveTabToFolder(tab, folder: targetFolder) }
        draggedTabId = nil; dropTargetFolderId = nil
        return true
    }
}
