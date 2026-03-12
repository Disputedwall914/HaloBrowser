//
//  PinnedTabDropDelegate.swift
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

/// Drop delegate that reorders within the `pinnedTabs` array
struct PinnedTabDropDelegate: DropDelegate {
    let model: BrowserViewModel
    let targetTab: HaloTab
    @Binding var draggedPinId: UUID?

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [UTType.text]) }

    func dropEntered(info: DropInfo) {
        guard let fromId = draggedPinId else { return }
        let pins = model.activeSpace.pinnedTabs
        guard let from = pins.firstIndex(where: { $0.id == fromId }),
              let to   = pins.firstIndex(where: { $0.id == targetTab.id }),
              from != to else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
            model.activeSpace.pinnedTabs.move(fromOffsets: IndexSet(integer: from),
                                               toOffset: to > from ? to + 1 : to)
        }
    }

    func performDrop(info: DropInfo) -> Bool { draggedPinId = nil; return true }
}
