//
//  SettingsPane.swift
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

// MARK: - Settings
// ─────────────────────────────────────────────────────────────────────────────
// ARCHITECTURE NOTE
// ─────────────────────────────────────────────────────────────────────────────
// ALL settings live in BrowserSettings (owned by BrowserViewModel).
// This file only contains Views — zero business logic.
//
// To make a stub setting actually work:
//   1. Add a property to BrowserSettings (shown inline with each stub below)
//   2. Replace the local @State with a $model.settings.yourProperty binding
//   3. Call model.saveState() in onChange (or use the didSet on BrowserSettings)
//
// Close button: uses @Environment(\.dismiss) which works automatically
// because this view is presented via .sheet() in BrowserView.
// ─────────────────────────────────────────────────────────────────────────────

import SwiftUI
import WebKit

// MARK: - Pane Enum

enum SettingsPane: String, CaseIterable, Identifiable {
    case tabs      = "Tabs"
    case spaces    = "Spaces"
    case search    = "Search"
    case profiles  = "Profiles"
    case privacy   = "Privacy"
    case advanced  = "Advanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .tabs:     return "rectangle.stack"
        case .spaces:   return "square.grid.2x2"
        case .search:   return "magnifyingglass"
        case .profiles: return "person.crop.circle"
        case .privacy:  return "lock.shield"
        case .advanced: return "gearshape.2"
        }
    }

    var color: Color {
        switch self {
        case .tabs:     return .blue
        case .spaces:   return .purple
        case .search:   return .orange
        case .profiles: return .green
        case .privacy:  return .red
        case .advanced: return .gray
        }
    }
}

// MARK: - Root Settings View

struct BrowserSettingsView: View {
    @Bindable var model: BrowserViewModel
    @State private var selectedPane: SettingsPane = .tabs
    private let sidebarBackgroundColor = SettingsViewColors.sidebarBackground
    private let windowBackgroundColor = SettingsViewColors.windowBackground

    /// Dismisses the sheet. Works automatically because BrowserView presents
    /// this via .sheet() — no extra @Binding<Bool> needed.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 0) {

            // ── Left sidebar ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {

                // Close button — top-left, macOS traffic-light style position
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: []) // Esc also closes
                    .padding(.leading, 14)
                    .padding(.top, 16)
                    Spacer()
                }

                Text("Settings")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ForEach(SettingsPane.allCases) { pane in
                    SidebarRow(pane: pane, isSelected: selectedPane == pane)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedPane = pane }
                        }
                }

                Spacer()
            }
            .frame(width: 200)
            .background(sidebarBackgroundColor)

            Divider()

            // ── Right content pane ────────────────────────────────────────
            ScrollView {
                Group {
                    switch selectedPane {
                    case .tabs:     TabsPane(model: model)
                    case .spaces:   SpacesPane(model: model)
                    case .search:   SearchPane(model: model)
                    case .profiles: ProfilesPane()
                    case .privacy:  PrivacyPane(model: model)
                    case .advanced: AdvancedPane(model: model)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(32)
            }
        }
        .frame(minWidth: 680, minHeight: 500)
        .frame(height: 500)
        .background(windowBackgroundColor)
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    let pane: SettingsPane
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(pane.color.gradient)
                    .frame(width: 26, height: 26)
                Image(systemName: pane.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(pane.rawValue).font(.system(size: 13)).foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 7)
            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 7)
            .stroke(isSelected ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 1))
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Shared Layout Primitives

struct PaneHeader: View {
    let pane: SettingsPane
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(pane.color.gradient)
                    .frame(width: 40, height: 40)
                Image(systemName: pane.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(pane.rawValue).font(.system(size: 22, weight: .bold))
        }
        .padding(.bottom, 20)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
                .padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(SettingsViewColors.sidebarBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1))
        }
        .padding(.bottom, 24)
    }
}

private enum SettingsViewColors {
    static let sidebarBackground = platformControlBackgroundColor
    static let windowBackground = platformWindowBackgroundColor
}

struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 16) }
}

struct SettingsRow<Control: View>: View {
    let label: String
    let description: String?
    @ViewBuilder let control: () -> Control

    init(_ label: String, description: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.label = label; self.description = description; self.control = control
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 13))
                if let desc = description {
                    Text(desc).font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
