//
//  TabsPane.swift
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: PANE: TABS
// ─────────────────────────────────────────────────────────────────────────────
//
// ✅ WIRED:   maxActiveTabs  — already on BrowserSettings, saves immediately.
//
// 🔧 TO WIRE: newTabBehaviour & defaultNewTabPage
//   ① Add to BrowserSettings:
//       var newTabBehaviour: String = "current"   // "current" | "last"
//       var defaultNewTabPage: String = "blank"   // "blank"   | "favs"
//
//   ② Replace .constant("current") / .constant("blank") below with:
//       $model.settings.newTabBehaviour / $model.settings.defaultNewTabPage
//      and add .onChange { _, _ in model.saveState() } to each Picker.
//
//   ③ In BrowserViewModel.openURLInNewTab(), read newTabBehaviour:
//       let targetSpace = settings.newTabBehaviour == "last"
//           ? (lastUsedSpace ?? activeSpace)
//           : activeSpace
//       targetSpace.tabs.append(tab)
//
//   ④ In BrowserContentView's empty-state block, check defaultNewTabPage:
//       if model.settings.defaultNewTabPage == "favs" {
//           PinnedTabsGridView(model: model)   // show favourites grid
//       } else {
//           // existing blank state
//       }
// ─────────────────────────────────────────────────────────────────────────────

struct TabsPane: View {
    @Bindable var model: BrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(pane: .tabs)

            SettingsSection(title: "Memory Management") {
                SettingsRow("Max active tabs",
                            description: "Older tabs sleep automatically beyond this limit") {
                    HStack(spacing: 8) {
                        Text("\(model.settings.maxActiveTabs)")
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .frame(width: 28)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(5)
                        Slider(value: Binding<Double>(
                            get: { Double(model.settings.maxActiveTabs) },
                            set: { model.settings.maxActiveTabs = Int($0) }
                        ), in: 1...30, step: 1)
                        .onChange(of: model.settings.maxActiveTabs) { _, _ in model.saveState() }
                    }
                }
            }

            SettingsSection(title: "New Tab Behaviour") {
                // 🔧 Replace .constant with $model.settings.newTabBehaviour once added
                SettingsRow("Open new tabs in") {
                    Picker("", selection: .constant("current")) {
                        Text("Current space").tag("current")
                        Text("Last used space").tag("last")
                    }
                    .labelsHidden().pickerStyle(.menu).frame(width: 160)
                }
                RowDivider()
                // 🔧 Replace .constant with $model.settings.defaultNewTabPage once added
                SettingsRow("Default new tab page") {
                    Picker("", selection: .constant("blank")) {
                        Text("Blank").tag("blank")
                        Text("Favourites").tag("favs")
                    }
                    .labelsHidden().pickerStyle(.menu).frame(width: 160)
                }
            }
        }
    }
}
