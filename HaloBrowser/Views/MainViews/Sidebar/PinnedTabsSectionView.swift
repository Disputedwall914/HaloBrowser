//
//  PinnedTabsSectionView.swift
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

// MARK: ── ⭐️ Pinned Tabs Section ────────────────────────────────────────────
///
/// Arc-style horizontal favicon strip showing pinned tabs.
///
/// A pinned tab IS a HaloTab — tapping it calls `model.selectTab(tab)` to switch to it.
/// Right-clicking lets you unpin (which moves it back to the normal tabs list) or close it.
/// Drag-and-drop reorders within the `pinnedTabs` array.
struct PinnedTabsSectionView: View {
    @Bindable var model: BrowserViewModel
    @State private var draggedPinId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Favorites")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.activeSpace.pinnedTabs) { tab in
                        PinnedTabItemView(
                            tab: tab,
                            isActive: model.activeTabId == tab.id,
                            accentColor: model.activeSpace.color
                        )
                        /// Tapping a pinned tab simply selects it — no new tab created
                        .onTapGesture { model.selectTab(tab) }
                        .contextMenu {
                            /// Unpin moves the tab back into the regular tabs list
                            Button("Unpin") { model.unpinTab(tab) }
                            Divider()
                            Button("Close Tab", role: .destructive) { model.closeTab(tab) }
                        }
                        .onDrag {
                            draggedPinId = tab.id
                            return NSItemProvider(object: tab.id.uuidString as NSString)
                        }
                        .onDrop(of: [UTType.text], delegate: PinnedTabDropDelegate(
                            model: model, targetTab: tab, draggedPinId: $draggedPinId))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
            }
        }
    }
}
