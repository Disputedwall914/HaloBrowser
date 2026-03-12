//
//  ProfilesPane.swift
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
// MARK: PANE: PROFILES  (stub — no settings to wire yet)
// ─────────────────────────────────────────────────────────────────────────────
//
// 🔧 TO WIRE: iCloud sync
//   This requires NSUbiquitousKeyValueStore or a CloudKit container.
//   When ready, replace the two methods in BrowserViewModel:
//     saveState()  → writes to NSUbiquitousKeyValueStore.default instead of UserDefaults
//     loadState()  → reads from NSUbiquitousKeyValueStore.default instead of UserDefaults
//   Then listen for NSUbiquitousKeyValueStoreDidChangeExternally to reload on other devices.
//   No BrowserSettings properties needed — it's purely a storage backend swap.
// ─────────────────────────────────────────────────────────────────────────────

struct ProfilesPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(pane: .profiles)

            SettingsSection(title: "Current Profile") {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.green.opacity(0.15)).frame(width: 48, height: 48)
                        Image(systemName: "person.fill").font(.system(size: 20)).foregroundColor(.green)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Default Profile").font(.system(size: 14, weight: .semibold))
                        Text("Local — no sync").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }

            SettingsSection(title: "Coming Soon") {
                SettingsRow("iCloud Sync")       { plannedBadge() }
                RowDivider()
                SettingsRow("Multiple Profiles") { plannedBadge() }
            }
        }
    }

    private func plannedBadge() -> some View {
        Text("Planned")
            .font(.system(size: 11)).foregroundColor(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12)).clipShape(Capsule())
    }
}
