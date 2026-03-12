//
//  AdvancedPane.swift
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
// MARK: PANE: ADVANCED
// ─────────────────────────────────────────────────────────────────────────────
//
// 🔧 TO WIRE: developerMode (Web Inspector)
//   ① Add to BrowserSettings:  var developerMode: Bool = false
//   ② In HaloTab.wake(), after `let newPage = WebPage()`:
//       #if DEBUG
//       newPage.configuration.preferences.setValue(
//           model.settings.developerMode, forKey: "developerExtrasEnabled")
//       #endif
//      "developerExtrasEnabled" is a private-but-stable WebKit key. Works on macOS.
//      On iOS it only shows in Safari's Develop menu on a provisioned device.
//   ③ Replace @State developerMode below with $model.settings.developerMode
//
// 🔧 TO WIRE: showFullURL  (also very easy)
//   ① Add to BrowserSettings:  var showFullURL: Bool = false
//   ② In BrowserTopBarView, change displayHost computed property to:
//       private var displayHost: String {
//           if model.settings.showFullURL {
//               return activeURL?.absoluteString ?? "New Tab"
//           }
//           return activeURL?.host.map { $0.isEmpty ? "New Tab" : $0 } ?? "New Tab"
//       }
//   That's all — the top bar redraws automatically since it reads from the model.
//   ③ Replace @State showFullURL below with $model.settings.showFullURL
// ─────────────────────────────────────────────────────────────────────────────

struct AdvancedPane: View {
    @Bindable var model: BrowserViewModel

    // 🔧 Move both of these to BrowserSettings and bind via $model.settings.*
    @State private var developerMode = false
    @State private var showFullURL = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(pane: .advanced)

            SettingsSection(title: "Developer") {
                SettingsRow("Web Inspector",
                            description: "Right-click any page → Inspect Element") {
                    Toggle("", isOn: $developerMode)
                        .labelsHidden()
                        // 🔧 .onChange(of: developerMode) { _, v in
                        //     model.settings.developerMode = v; model.saveState() }
                }
            }

            SettingsSection(title: "Address Bar") {
                SettingsRow("Show full URL",
                            description: "Shows https://www.example.com instead of just example.com") {
                    Toggle("", isOn: $showFullURL)
                        .labelsHidden()
                        // 🔧 .onChange(of: showFullURL) { _, v in
                        //     model.settings.showFullURL = v; model.saveState() }
                }
            }

            SettingsSection(title: "About") {
                SettingsRow("Version") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                        .font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary)
                }
                RowDivider()
                SettingsRow("Build") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")
                        .font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary)
                }
            }
        }
    }
}
