//
//  iPadSettingsView.swift
//  HaloBrowser
//
//  Created for iPad — replaces the macOS sheet with a full-overlay
//  glass-effect panel that looks and feels like a native macOS Settings
//  window, but adapted for iPadOS touch interaction.
//
//  HOW TO USE in BrowserView.swift:
//
//    Replace:
//      .sheet(isPresented: $showSettings) { BrowserSettingsView(model: model) }
//
//    With:
//      #if os(iOS)
//      .overlay {
//          if showSettings {
//              iPadSettingsView(model: model, isPresented: $showSettings)
//                  .transition(.opacity.combined(with: .scale(scale: 0.97,
//                               anchor: .center)))
//                  .animation(.spring(response: 0.35, dampingFraction: 0.85),
//                             value: showSettings)
//                  .zIndex(99)
//          }
//      }
//      #else
//      .sheet(isPresented: $showSettings) { BrowserSettingsView(model: model) }
//      #endif
// ─────────────────────────────────────────────────────────────────────────────

#if os(iOS)
import SwiftUI

// MARK: - Root iPad Settings Overlay

struct iPadSettingsView: View {
    @Bindable var model: BrowserViewModel
    @Binding var isPresented: Bool

    @State private var selectedPane: SettingsPane = .tabs
    @State private var sidebarHover: SettingsPane? = nil

    // Slight entrance animation for the panel itself
    @State private var appeared = false

    var body: some View {
        ZStack {
            // ── Scrim ────────────────────────────────────────────────────
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
                .transition(.opacity)

            // ── Panel ────────────────────────────────────────────────────
            HStack(spacing: 0) {

                // LEFT — sidebar
                iPadSettingsSidebar(
                    selectedPane: $selectedPane,
                    accentColor: model.activeSpace.color,
                    onDismiss: dismiss
                )
                .frame(width: 210)

                // Hairline divider
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 0.5)

                // RIGHT — content
                ScrollView {
                    iPadPaneContent(model: model, pane: selectedPane)
                        .padding(36)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity)
            }
            // Glass card
            .background(
                ZStack {
                    // Deep frosted layer
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.ultraThinMaterial)
                    // Subtle tint wash from active space colour
                    RoundedRectangle(cornerRadius: 22)
                        .fill(model.activeSpace.color.opacity(0.06))
                    // Inner highlight ring
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.28), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.35), radius: 60, x: 0, y: 20)
            .frame(width: 820, height: 580)
            .scaleEffect(appeared ? 1 : 0.96)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            appeared = false
        }
        // Small delay so the out-animation plays before removing from hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
    }
}


// MARK: - Sidebar

private struct iPadSettingsSidebar: View {
    @Binding var selectedPane: SettingsPane
    let accentColor: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Close button row
            HStack {
                Button(action: onDismiss) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.14))
                            .frame(width: 26, height: 26)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 4)

            // "Settings" heading
            Text("Settings")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            // Nav rows
            VStack(spacing: 2) {
                ForEach(SettingsPane.allCases) { pane in
                    iPadSidebarRow(
                        pane: pane,
                        isSelected: selectedPane == pane
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedPane = pane
                        }
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Version badge at the bottom
            Text("Halo Browser")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
    }
}

private struct iPadSidebarRow: View {
    let pane: SettingsPane
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Coloured icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(pane.color.gradient)
                    .frame(width: 28, height: 28)
                Image(systemName: pane.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(pane.rawValue)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .primary : .secondary)

            Spacer()

            if isSelected {
                RoundedRectangle(cornerRadius: 2)
                    .fill(pane.color)
                    .frame(width: 3, height: 18)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected
                      ? pane.color.opacity(0.18)
                      : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? pane.color.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}


// MARK: - Pane Content Router

/// Re-uses all the existing Pane views (TabsPane, SpacesPane, etc.)
/// but wraps them so they render correctly inside the iPad overlay
/// instead of inside an NSColor-backed macOS window.
private struct iPadPaneContent: View {
    @Bindable var model: BrowserViewModel
    let pane: SettingsPane

    var body: some View {
        Group {
            switch pane {
            case .tabs:     iPadTabsPane(model: model)
            case .spaces:   iPadSpacesPane(model: model)
            case .search:   iPadSearchPane(model: model)
            case .profiles: iPadProfilesPane()
            case .privacy:  iPadPrivacyPane(model: model)
            case .advanced: iPadAdvancedPane(model: model)
            }
        }
    }
}


// MARK: - iPad-adapted Pane views
// These mirror the macOS panes exactly, swapping NSColor → UIColor /
// Color(uiColorLiteral) where needed, and dropping macOS-only APIs.

// ── Shared layout components (iPad-flavoured) ────────────────────────────────

struct iPadPaneHeader: View {
    let pane: SettingsPane
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(pane.color.gradient)
                    .frame(width: 46, height: 46)
                    .shadow(color: pane.color.opacity(0.4), radius: 8, x: 0, y: 4)
                Image(systemName: pane.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(pane.rawValue)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding(.bottom, 22)
    }
}

struct iPadSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, 8)

            VStack(spacing: 0) { content() }
                // Glass-tinted card background instead of NSColor.controlBackgroundColor
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.bottom, 24)
    }
}

struct iPadSettingsRow<Control: View>: View {
    let label: String
    let description: String?
    @ViewBuilder let control: () -> Control

    init(_ label: String,
         description: String? = nil,
         @ViewBuilder control: @escaping () -> Control) {
        self.label = label
        self.description = description
        self.control = control
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 14))
                if let desc = description {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct iPadRowDivider: View {
    var body: some View {
        Divider()
            .overlay(.white.opacity(0.08))
            .padding(.leading, 16)
    }
}


// ── TABS pane ────────────────────────────────────────────────────────────────
private struct iPadTabsPane: View {
    @Bindable var model: BrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            iPadPaneHeader(pane: .tabs)

            iPadSettingsSection(title: "Memory Management") {
                iPadSettingsRow("Max active tabs",
                                description: "Older tabs sleep automatically beyond this limit") {
                    HStack(spacing: 10) {
                        Text("\(model.settings.maxActiveTabs)")
                            .font(.system(size: 14, weight: .semibold).monospacedDigit())
                            .frame(width: 32)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Slider(value: Binding<Double>(
                            get: { Double(model.settings.maxActiveTabs) },
                            set: { model.settings.maxActiveTabs = Int($0) }
                        ), in: 1...30, step: 1)
                        .frame(width: 160)
                        .onChange(of: model.settings.maxActiveTabs) { _, _ in model.saveState() }
                    }
                }
            }

            iPadSettingsSection(title: "New Tab Behaviour") {
                iPadSettingsRow("Open new tabs in") {
                    Picker("", selection: .constant("current")) {
                        Text("Current space").tag("current")
                        Text("Last used space").tag("last")
                    }
                    .labelsHidden().pickerStyle(.menu).frame(width: 170)
                }
                iPadRowDivider()
                iPadSettingsRow("Default new tab page") {
                    Picker("", selection: .constant("blank")) {
                        Text("Blank").tag("blank")
                        Text("Favourites").tag("favs")
                    }
                    .labelsHidden().pickerStyle(.menu).frame(width: 170)
                }
            }
        }
    }
}


// ── SPACES pane ──────────────────────────────────────────────────────────────
private struct iPadSpacesPane: View {
    @Bindable var model: BrowserViewModel
    @State private var editingSpaceId: UUID? = nil
    @State private var showAddSheet = false

    private let columns = [
        GridItem(.flexible(), alignment: .top),
        GridItem(.flexible(), alignment: .top),
        GridItem(.flexible(), alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                iPadPaneHeader(pane: .spaces)
                Spacer()
                Button { showAddSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        Text("New Space").font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(.tint.opacity(0.15))
                    .foregroundStyle(.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(.tint.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(model.spaces) { space in
                    SpaceCard(
                        space: space,
                        isEditing: editingSpaceId == space.id,
                        isDragging: false,
                        canDelete: model.spaces.count > 1,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                editingSpaceId = editingSpaceId == space.id ? nil : space.id
                            }
                        },
                        onDelete: { model.removeSpace(space) },
                        onChanged: { model.saveState() }
                    )
                }
            }

            if model.spaces.count > 1 {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 10))
                    Text("Tap a card to edit it")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.top, 12)
            }
        }
        .sheet(isPresented: $showAddSheet) { AddSpaceSheet(model: model) }
    }
}


// ── SEARCH pane ──────────────────────────────────────────────────────────────
private struct iPadSearchPane: View {
    @Bindable var model: BrowserViewModel
    private let engines = ["Google", "DuckDuckGo", "Brave", "Bing", "Ecosia", "Kagi"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            iPadPaneHeader(pane: .search)

            iPadSettingsSection(title: "Default Search Engine") {
                ForEach(engines, id: \.self) { engine in
                    if engine != engines.first { iPadRowDivider() }
                    Button {
                        model.settings.searchEngine = engine
                        model.saveState()
                    } label: {
                        HStack {
                            Text(engine).font(.system(size: 14)).foregroundStyle(.primary)
                            Spacer()
                            if model.settings.searchEngine == engine {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }

            iPadSettingsSection(title: "Omnibox") {
                iPadSettingsRow("Show search suggestions",
                                description: "Fetches live suggestions as you type") {
                    Toggle("", isOn: $model.settings.showSuggestions)
                        .labelsHidden()
                        .onChange(of: model.settings.showSuggestions) { _, _ in model.saveState() }
                }
            }

            iPadSettingsSection(title: "Shortcuts") {
                iPadSettingsRow("@yt")   { monoLabel("youtube.com/results?…") }
                iPadRowDivider()
                iPadSettingsRow("@wiki") { monoLabel("wikipedia.org/…Special:Search?…") }
                iPadRowDivider()
                iPadSettingsRow("@g")    { monoLabel("google.com/search?q=…") }
            }
        }
    }

    private func monoLabel(_ s: String) -> some View {
        Text(s).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
    }
}


// ── PROFILES pane ────────────────────────────────────────────────────────────
private struct iPadProfilesPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            iPadPaneHeader(pane: .profiles)

            iPadSettingsSection(title: "Current Profile") {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.green.opacity(0.18)).frame(width: 50, height: 50)
                        Image(systemName: "person.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.green)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Default Profile").font(.system(size: 15, weight: .semibold))
                        Text("Local — no sync").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }

            iPadSettingsSection(title: "Coming Soon") {
                iPadSettingsRow("iCloud Sync")       { plannedBadge() }
                iPadRowDivider()
                iPadSettingsRow("Multiple Profiles") { plannedBadge() }
            }
        }
    }

    private func plannedBadge() -> some View {
        Text("Planned")
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(.secondary.opacity(0.12)).clipShape(Capsule())
    }
}


// ── PRIVACY pane ─────────────────────────────────────────────────────────────
private struct iPadPrivacyPane: View {
    @Bindable var model: BrowserViewModel
    @State private var blockThirdPartyCookies = true
    @State private var httpsUpgrade = true
    @State private var fingerprintProtection = false
    @State private var showClearConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            iPadPaneHeader(pane: .privacy)

            iPadSettingsSection(title: "Ad Blocking") {
                iPadSettingsRow("Block level",
                                description: "Off · Balanced · Strict") {
                    Picker("", selection: $model.settings.adBlockLevel) {
                        Text("Off").tag(0)
                        Text("Balanced").tag(1)
                        Text("Strict").tag(2)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .onChange(of: model.settings.adBlockLevel) { _, _ in model.saveState() }
                }
            }

            iPadSettingsSection(title: "Tracking & Cookies") {
                iPadSettingsRow("Block third-party cookies",
                                description: "Keeps first-party cookies intact") {
                    Toggle("", isOn: $blockThirdPartyCookies).labelsHidden()
                }
                iPadRowDivider()
                iPadSettingsRow("Upgrade HTTP to HTTPS automatically") {
                    Toggle("", isOn: $httpsUpgrade).labelsHidden()
                }
                iPadRowDivider()
                iPadSettingsRow("Fingerprint protection",
                                description: "Randomises canvas & audio fingerprints") {
                    Toggle("", isOn: $fingerprintProtection).labelsHidden()
                }
            }

            iPadSettingsSection(title: "Data") {
                iPadSettingsRow("Clear all website data",
                                description: "Removes cookies, caches, localStorage, and IndexedDB") {
                    Button("Clear…") { showClearConfirm = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                        .confirmationDialog("Clear all website data?",
                                            isPresented: $showClearConfirm,
                                            titleVisibility: .visible) {
                            Button("Clear Everything", role: .destructive) {
                                WKWebsiteDataStore.default().removeData(
                                    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                                    modifiedSince: .distantPast) { }
                            }
                        } message: { Text("This cannot be undone.") }
                }
            }
        }
    }
}


// ── ADVANCED pane ────────────────────────────────────────────────────────────
private struct iPadAdvancedPane: View {
    @Bindable var model: BrowserViewModel
    @State private var developerMode = false
    @State private var showFullURL = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            iPadPaneHeader(pane: .advanced)

            iPadSettingsSection(title: "Developer") {
                iPadSettingsRow("Web Inspector",
                                description: "Right-click any page → Inspect Element") {
                    Toggle("", isOn: $developerMode).labelsHidden()
                }
            }

            iPadSettingsSection(title: "Address Bar") {
                iPadSettingsRow("Show full URL",
                                description: "Shows https://www.example.com instead of just example.com") {
                    Toggle("", isOn: $showFullURL).labelsHidden()
                }
            }

            iPadSettingsSection(title: "About") {
                iPadSettingsRow("Version") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                        .font(.system(size: 13, design: .monospaced)).foregroundStyle(.secondary)
                }
                iPadRowDivider()
                iPadSettingsRow("Build") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")
                        .font(.system(size: 13, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

#endif // os(iOS)