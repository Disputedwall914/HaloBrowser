//
//  SpaceDropDelegate.swift
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

// MARK: - Space Drop Delegate

/// Handles live reordering of space cards during drag
struct SpaceDropDelegate: DropDelegate {
    let model: BrowserViewModel
    let targetSpace: HaloSpace
    @Binding var draggingSpaceId: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }

    func dropEntered(info: DropInfo) {
        guard let fromId = draggingSpaceId,
              fromId != targetSpace.id,
              let fromIndex = model.spaces.firstIndex(where: { $0.id == fromId }),
              let toIndex   = model.spaces.firstIndex(where: { $0.id == targetSpace.id })
        else { return }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            model.spaces.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingSpaceId = nil
        model.saveState()
        return true
    }

    func dropExited(info: DropInfo) { }
}
