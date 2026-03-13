//
//  BrowserViewModel.swift
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

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 3. BROWSERVIEWMODEL  — single source of truth for ALL browser logic
// MARK: ─────────────────────────────────────────────────────────────────────

@Observable
class BrowserViewModel {

    // MARK: Core state
    var spaces: [HaloSpace]
    var activeSpaceId: UUID
    var activeTabId: UUID?
    var settings: BrowserSettings = BrowserSettings()

    // MARK: Omnibox state
    var showOmnibox: Bool = false
    var omniboxInput: String = ""
    var suggestions: [OmniboxSuggestion] = []
    var selectedSuggestionIndex: Int = 0

    // MARK: Drag state  (kept in ViewModel so delegates can coordinate)
    var draggingTabId: UUID? = nil
    var dragOverFolderId: UUID? = nil
    
    var searchEngine: String = "Google"
    var showSuggestions: Bool = true

    // MARK: Computed convenience

    /// The currently active `HaloSpace`
    var activeSpace: HaloSpace {
        spaces.first { $0.id == activeSpaceId } ?? spaces[0]
    }

    /// The currently active `HaloTab`, searched across top-level tabs, folder tabs, AND pinned tabs
    var activeTab: HaloTab? {
        guard let id = activeTabId else { return nil }
        if let t = activeSpace.tabs.first(where: { $0.id == id }) { return t }
        for folder in activeSpace.folders {
            if let t = folder.tabs.first(where: { $0.id == id }) { return t }
        }
        if let t = activeSpace.pinnedTabs.first(where: { $0.id == id }) { return t }
        return nil
    }

    /// Returns true if the active tab is currently pinned in this space
    var isActiveTabPinned: Bool {
        guard let tab = activeTab else { return false }
        return activeSpace.pinnedTabs.contains { $0.id == tab.id }
    }


    // MARK: ── Init / Persistence ──────────────────────────────────────────

    init() {
        if let saved = Self.loadState() {
            // Reconstruct live @Observable objects from plain Codable structs
            let decoded = saved.spaces.map { ps -> HaloSpace in
                let space = HaloSpace(id: ps.id, name: ps.name, iconName: ps.iconName,
                                      color: Color(persisted: ps.color))
                space.tabs       = ps.tabs.map       { HaloTab(id: $0.id, url: $0.urlString, isSleeping: $0.isSleeping) }
                space.pinnedTabs = ps.pinnedTabs.map {
                    HaloTab(id: $0.id, url: $0.urlString, isSleeping: true)
                }
                space.folders    = ps.folders.map { pf in
                    HaloFolder(id: pf.id, name: pf.name, color: Color(persisted: pf.color),
                               tabs: pf.tabs.map { HaloTab(id: $0.id, url: $0.urlString, isSleeping: $0.isSleeping) },
                               isExpanded: pf.isExpanded)
                }
                return space
            }

            if decoded.isEmpty {
                let defaults = Self.defaultSpaces()
                spaces = defaults; activeSpaceId = defaults[0].id
            } else {
                spaces = decoded
                activeSpaceId = saved.activeSpaceId
                activeTabId   = saved.activeTabId
                sanitizeSelection()
            }
            settings = BrowserSettings(maxActiveTabs: saved.settings.maxActiveTabs,
                                        adBlockLevel:  saved.settings.adBlockLevel)
        } else {
            let defaults = Self.defaultSpaces()
            spaces = defaults; activeSpaceId = defaults[0].id
        }
    }

    private static func defaultSpaces() -> [HaloSpace] {
        [HaloSpace(name: "Personal", iconName: "person",    color: randomSpaceColor()),
         HaloSpace(name: "Work",     iconName: "briefcase", color: randomSpaceColor())]
    }

    /// Serialise all state to UserDefaults
    func saveState() {
        let persistedSpaces = spaces.map { space in
            PersistedSpace(
                id:          space.id,
                name:        space.name,
                iconName:    space.iconName,
                color:       space.color.persistedColor,
                tabs:        space.tabs.map       { PersistedTab(id: $0.id, urlString: $0.persistedURLString, isSleeping: $0.isSleeping) },
                folders:     space.folders.map { folder in
                    PersistedFolder(id: folder.id, name: folder.name, color: folder.color.persistedColor,
                                    tabs: folder.tabs.map { PersistedTab(id: $0.id, urlString: $0.persistedURLString, isSleeping: $0.isSleeping) },
                                    isExpanded: folder.isExpanded)
                },
                pinnedTabs:  space.pinnedTabs.map { PersistedTab(id: $0.id, urlString: $0.persistedURLString, isSleeping: $0.isSleeping) }
            )
        }
        let state = PersistedBrowserState(spaces: persistedSpaces, activeSpaceId: activeSpaceId,
                                          activeTabId: activeTabId,
                                          settings: PersistedSettings(maxActiveTabs: settings.maxActiveTabs,
                                                                       adBlockLevel:  settings.adBlockLevel))
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        }
    }

    private static func loadState() -> PersistedBrowserState? {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return nil }
        return try? JSONDecoder().decode(PersistedBrowserState.self, from: data)
    }

    private static let persistenceKey = "HaloBrowser.PersistentState.v2"

    /// Make sure the stored activeSpaceId / activeTabId actually exist after loading
    private func sanitizeSelection() {
        if !spaces.contains(where: { $0.id == activeSpaceId }) {
            activeSpaceId = spaces.first?.id ?? activeSpaceId
        }
        // If the stored activeTabId can't be found anywhere, fall back to last normal tab
        if let id = activeTabId {
            let allIds = activeSpace.tabs.map(\.id)
                + activeSpace.folders.flatMap(\.tabs).map(\.id)
                + activeSpace.pinnedTabs.map(\.id)
            if !allIds.contains(id) { activeTabId = activeSpace.tabs.last?.id }
        } else {
            activeTabId = activeSpace.tabs.last?.id
        }
    }


    // MARK: ── Tab Selection & Lifecycle ──────────────────────────────────

    /// Select a tab — wakes it first and enforces the memory cap
    func selectTab(_ tab: HaloTab) {
        enforceMemoryCap(incomingTab: tab)
        tab.wake()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            activeTabId = tab.id
        }
        saveState()
    }

    /// Close a tab, searching across top-level tabs, folders, and pinned tabs
    func closeTab(_ tab: HaloTab) {
        // Try top-level
        if let i = activeSpace.tabs.firstIndex(of: tab) {
            activeSpace.tabs.remove(at: i)
            if activeTabId == tab.id { activeTabId = activeSpace.tabs.last?.id }
            saveState(); return
        }
        // Try each folder
        for folder in activeSpace.folders {
            if let i = folder.tabs.firstIndex(of: tab) {
                folder.tabs.remove(at: i)
                if activeTabId == tab.id { activeTabId = activeSpace.tabs.last?.id }
                saveState(); return
            }
        }
        // Try pinned tabs
        if let i = activeSpace.pinnedTabs.firstIndex(of: tab) {
            activeSpace.pinnedTabs.remove(at: i)
            if activeTabId == tab.id { activeTabId = activeSpace.tabs.last?.id }
            saveState()
        }
    }

    /// Open a URL in a brand-new tab at the end of the normal tabs list
    func openURLInNewTab(_ urlString: String) {
        let tab = HaloTab(url: urlString)
        activeSpace.tabs.append(tab)
        selectTab(tab)
    }

    /// Sleep tabs beyond the memory cap — oldest non-active tabs sleep first
    private func enforceMemoryCap(incomingTab: HaloTab) {
        let allAwake = (spaces.flatMap(\.tabs) + spaces.flatMap { $0.folders.flatMap(\.tabs) } + spaces.flatMap(\.pinnedTabs))
            .filter { !$0.isSleeping && $0.id != incomingTab.id }
        if allAwake.count >= settings.maxActiveTabs {
            allAwake.first(where: { $0.id != activeTabId })?.sleep()
        }
    }


    // MARK: ── ⭐️ Pinned Tabs (Arc-style Favorites) ─────────────────────────
    //
    // A "pinned tab" is just a HaloTab stored in `space.pinnedTabs` instead of `space.tabs`.
    // Selecting it works exactly like selecting any other tab.
    // Pinning moves the tab from `tabs` → `pinnedTabs`; unpinning does the reverse.

    /// Pin the active tab — moves it from `tabs` (or folder tabs) into `pinnedTabs`
    func pinActiveTab() {
        guard let tab = activeTab else { return }
        guard !activeSpace.pinnedTabs.contains(tab) else { return }

        if let liveURL = tab.page?.url?.absoluteString {
            tab.urlString = liveURL
        }

        removeTabFromAllContainers(tab, inSpace: activeSpace)
        activeSpace.pinnedTabs.append(tab)
        activeTabId = tab.id
        saveState()
    }

    /// Unpin a pinned tab — moves it back into the normal `tabs` list
    func unpinTab(_ tab: HaloTab) {
        guard let i = activeSpace.pinnedTabs.firstIndex(of: tab) else { return }
        if let liveURL = tab.page?.url?.absoluteString {
            tab.urlString = liveURL
        }
        activeSpace.pinnedTabs.remove(at: i)
        activeSpace.tabs.append(tab)
        saveState()
    }

    /// Toggle pin state of the active tab (used by the star button in the top bar)
    func togglePinActiveTab() {
        guard let tab = activeTab else { return }
        if activeSpace.pinnedTabs.contains(tab) { unpinTab(tab) }
        else { pinActiveTab() }
    }

    /// Remove a tab from EVERY container (tabs, folders, pinnedTabs) in a space
    private func removeTabFromAllContainers(_ tab: HaloTab, inSpace space: HaloSpace) {
        space.tabs.removeAll { $0.id == tab.id }
        for folder in space.folders { folder.tabs.removeAll { $0.id == tab.id } }
        space.pinnedTabs.removeAll { $0.id == tab.id }
    }


    // MARK: ── Folder Management ───────────────────────────────────────────

    func addFolder(name: String, color: Color = .blue) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        activeSpace.folders.append(HaloFolder(name: trimmed, color: color))
        saveState()
    }

    /// Delete a folder; its tabs are moved back to the top-level list
    func removeFolder(_ folder: HaloFolder) {
        activeSpace.tabs.append(contentsOf: folder.tabs)
        activeSpace.folders.removeAll { $0.id == folder.id }
        saveState()
    }

    func moveTabToFolder(_ tab: HaloTab, folder: HaloFolder) {
        // Remove from every container first (handles pinned → folder too)
        removeTabFromAllContainers(tab, inSpace: activeSpace)
        guard !folder.tabs.contains(tab) else { return }
        folder.tabs.append(tab)
        folder.isExpanded = true
        saveState()
    }

    func moveTabOutOfFolder(_ tab: HaloTab, folder: HaloFolder) {
        folder.tabs.removeAll { $0.id == tab.id }
        if !activeSpace.tabs.contains(tab) { activeSpace.tabs.append(tab) }
        saveState()
    }


    // MARK: ── Space Management ────────────────────────────────────────────

    func addSpace(name: String, iconName: String, color: Color) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        spaces.append(HaloSpace(name: trimmed, iconName: iconName, color: color))
        saveState()
    }

    func removeSpace(_ space: HaloSpace) {
        guard spaces.count > 1, let i = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        spaces.remove(at: i)
        if activeSpaceId == space.id {
            activeSpaceId = spaces.first!.id
            activeTabId   = activeSpace.tabs.last?.id
        }
        saveState()
    }

    func setActiveSpace(_ space: HaloSpace) {
        activeSpaceId = space.id
        activeTabId   = space.tabs.last?.id ?? space.folders.first?.tabs.last?.id
        saveState()
    }


    // MARK: ── Omnibox ─────────────────────────────────────────────────────
    
    func searchURL(for query: String) -> String {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        switch settings.searchEngine {
        case "DuckDuckGo": return "https://duckduckgo.com/?q=\(q)"
        case "Bing":       return "https://bing.com/search?q=\(q)"
        case "Brave":      return "https://search.brave.com/search?q=\(q)"
        case "Ecosia":     return "https://ecosia.org/search?q=\(q)"
        case "Kagi":       return "https://kagi.com/search?q=\(q)"
        default:           return "https://google.com/search?q=\(q)"
        }
    }
    
    private var suggestionTask: Task<Void, Never>?

    func updateSuggestions() {
        let input = omniboxInput.trimmingCharacters(in: .whitespacesAndNewlines)
        suggestionTask?.cancel()
        guard !input.isEmpty else { suggestions = []; selectedSuggestionIndex = 0; return }

        let commands = commandSuggestions(for: input)
        let main     = searchQuerySuggestion(for: input)
        suggestions  = commands + [main]
        selectedSuggestionIndex = 0

        suggestionTask = Task {
            guard settings.showSuggestions else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let google = await fetchGoogleSuggestions(query: input)
            await MainActor.run { suggestions = commands + [main] + google }
        }
    }

    func selectNextSuggestion()     { selectedSuggestionIndex = min(selectedSuggestionIndex + 1, suggestions.count - 1) }
    func selectPreviousSuggestion() { selectedSuggestionIndex = max(selectedSuggestionIndex - 1, 0) }

    private func commandSuggestions(for input: String) -> [OmniboxSuggestion] {
        let low = input.lowercased(); var out: [OmniboxSuggestion] = []
        if "help".hasPrefix(low)     { out.append(.init(title: "help",     subtitle: "Show commands",  input: "help",     iconURL: nil, fallbackSystemImage: "questionmark.circle")) }
        if "settings".hasPrefix(low) { out.append(.init(title: "settings", subtitle: "Open settings", input: "settings", iconURL: nil, fallbackSystemImage: "gearshape")) }
        return out
    }

    private func searchQuerySuggestion(for input: String) -> OmniboxSuggestion {
        let isURL  = input.contains(".") && !input.contains(" ")
        let norm   = input.hasPrefix("http") ? input : "https://" + input
        let title  = isURL ? "Open \(norm)" : "Search for \"\(input)\""
        return .init(title: title, subtitle: input, input: input,
                     iconURL: isURL ? faviconURL(for: norm) : nil,
                     fallbackSystemImage: isURL ? "globe" : "magnifyingglass")
    }

    private func fetchGoogleSuggestions(query: String) async -> [OmniboxSuggestion] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&q=\(encoded)")
        else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let arr = try JSONSerialization.jsonObject(with: data) as? [Any],
                  arr.count > 1,
                  let strs = arr[1] as? [String] else { return [] }
            return strs.map { .init(title: $0, subtitle: "Search", input: $0, iconURL: nil, fallbackSystemImage: "magnifyingglass") }
        } catch { return [] }
    }

    private func faviconURL(for urlString: String) -> URL? {
        guard let host = URL(string: urlString)?.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=32&domain=\(host)")
    }


    // MARK: ── Palette / Misc ──────────────────────────────────────────────

    static let availableColors: [Color] = [.red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .pink, .purple]
    static func randomSpaceColor() -> Color { availableColors.randomElement() ?? .blue }
}

// MARK: ── BrowserViewModel extension: helpers used by views ─────────────────
extension BrowserViewModel {
    /// Move a tab (from anywhere) into `pinnedTabs` — called from context menu "Pin Tab"
    func moveTabToPinned(_ tab: HaloTab) {
        if let liveURL = tab.page?.url?.absoluteString {
            tab.urlString = liveURL
        }
        removeTabFromAllContainers(tab, inSpace: activeSpace)
        if !activeSpace.pinnedTabs.contains(tab) {
            activeSpace.pinnedTabs.append(tab)
        }
        activeTabId = tab.id
        saveState()
    }

    /// Private helper exposed to the extension so views can call it
//    fileprivate func removeTabFromAllContainers(_ tab: HaloTab, inSpace space: HaloSpace) {
//        space.tabs.removeAll       { $0.id == tab.id }
//        for folder in space.folders { folder.tabs.removeAll { $0.id == tab.id } }
//        space.pinnedTabs.removeAll { $0.id == tab.id }
//    }
}
