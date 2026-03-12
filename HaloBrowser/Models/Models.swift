//
//  HaloTab.swift
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
// MARK: 1. CORE MODELS
// MARK: ─────────────────────────────────────────────────────────────────────

/// A single browser tab.  `page` is non-nil when the tab is awake (has an active WebView).
/// When sleeping, we store the last known URL in `urlString` and `page = nil`.
@Observable
class HaloTab: Identifiable, Hashable {
    let id: UUID
    var urlString: String
    var page: WebPage?

    /// Chrome-like user agent used for Google domains to ensure full feature support
    private static let googleUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    init(id: UUID = UUID(), url: String, isSleeping: Bool = false) {
        self.id = id
        self.urlString = url
        if !isSleeping { wake() }
    }

    /// The best display title: prefer the page's <title>, fall back to URL string
    var displayTitle: String {
        guard let page, !page.title.isEmpty else { return urlString }
        return page.title
    }

    var isSleeping: Bool { page == nil }

    /// Allocate a WebPage and start loading.  No-op if already awake.
    func wake() {
        guard page == nil else { return }
        let newPage = WebPage()
        if let agent = preferredUserAgent(for: urlString) { newPage.customUserAgent = agent }
        page = newPage
        if let url = URL(string: urlString) { page?.load(URLRequest(url: url)) }
    }

    /// Capture the current live URL, then deallocate the WebPage to free memory.
    func sleep() {
        if let live = page?.url?.absoluteString { urlString = live }
        page = nil
    }

    /// The URL to use for persistence — prefers the live page URL over the stored string
    var persistedURLString: String { page?.url?.absoluteString ?? urlString }

    var currentURL: URL? { page?.url ?? URL(string: urlString) }

    /// Google Favicon Service URL for this tab's domain
    var faviconURL: URL? {
        guard let host = currentURL?.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)")
    }

    // MARK: Hashable / Equatable — identity only
    static func == (lhs: HaloTab, rhs: HaloTab) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private func preferredUserAgent(for urlString: String) -> String? {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return nil }
        return host.contains("google.") ? Self.googleUserAgent : nil
    }
}

/// A named folder that contains tabs.  Folders live inside a `HaloSpace`.
@Observable
class HaloFolder: Identifiable {
    let id: UUID
    var name: String
    var tabs: [HaloTab]
    var isExpanded: Bool
    var color: Color

    init(id: UUID = UUID(), name: String, color: Color = .blue, tabs: [HaloTab] = [], isExpanded: Bool = false) {
        self.id = id; self.name = name; self.color = color
        self.tabs = tabs; self.isExpanded = isExpanded
    }
}

/// A workspace that owns regular tabs, folders of tabs, AND pinned-favorite tabs.
///
/// ⭐️ KEY DESIGN: `pinnedTabs` replaces the old `HaloFavorite` model entirely.
/// A pinned tab IS a `HaloTab` — selecting it navigates to it, just like any other tab.
/// The only difference is it appears in the Arc-style favicon strip at the top of the sidebar.
@Observable
class HaloSpace: Identifiable {
    let id: UUID
    var name: String
    var iconName: String
    var color: Color

    /// Normal browsing tabs shown in the main sidebar list
    var tabs: [HaloTab] = []

    /// Folders that group tabs
    var folders: [HaloFolder] = []

    /// ⭐️ Pinned/favorited tabs — shown as the Arc-style favicon strip.
    /// These ARE tabs (selectable, closeable) — not a separate data type.
    var pinnedTabs: [HaloTab] = []

    init(id: UUID = UUID(), name: String, iconName: String, color: Color) {
        self.id = id; self.name = name; self.iconName = iconName; self.color = color
    }
}

/// User-configurable performance/privacy settings
@Observable
class BrowserSettings {
    var searchEngine: String = "Google"
    var showSuggestions: Bool = true
    var maxActiveTabs: Int
    var adBlockLevel: Int
    init(maxActiveTabs: Int = 3, adBlockLevel: Int = 0) {
        self.maxActiveTabs = maxActiveTabs; self.adBlockLevel = adBlockLevel
    }
}


// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: 2. PERSISTENCE MODELS  (plain Codable structs — no @Observable needed)
// MARK: ─────────────────────────────────────────────────────────────────────

struct PersistedTab: Codable {
    let id: UUID
    let urlString: String
    let isSleeping: Bool
}

struct PersistedFolder: Codable {
    let id: UUID
    let name: String
    let color: PersistedColor
    let tabs: [PersistedTab]
    let isExpanded: Bool
}

struct PersistedColor: Codable {
    let red, green, blue, alpha: Double
}

struct PersistedSpace: Codable {
    let id: UUID
    let name: String
    let iconName: String
    let color: PersistedColor
    let tabs: [PersistedTab]
    let folders: [PersistedFolder]
    /// ⭐️ Previously stored as `favorites: [PersistedFavorite]`.
    /// Now stored as `pinnedTabs: [PersistedTab]` — same shape as normal tabs.
    let pinnedTabs: [PersistedTab]

    enum CodingKeys: String, CodingKey {
        case id, name, iconName, color, tabs, folders, pinnedTabs
        // "favorites" kept as a migration alias inside init(from:) below
    }

    init(id: UUID, name: String, iconName: String, color: PersistedColor,
         tabs: [PersistedTab], folders: [PersistedFolder], pinnedTabs: [PersistedTab]) {
        self.id = id; self.name = name; self.iconName = iconName
        self.color = color; self.tabs = tabs; self.folders = folders; self.pinnedTabs = pinnedTabs
    }

    /// Custom decoder: gracefully handles old saved state that used "favorites" key
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self,   forKey: .id)
        name     = try c.decode(String.self, forKey: .name)
        iconName = try c.decode(String.self, forKey: .iconName)
        tabs     = try c.decode([PersistedTab].self, forKey: .tabs)
        color    = (try? c.decode(PersistedColor.self, forKey: .color))
                    ?? PersistedColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
        folders  = (try? c.decode([PersistedFolder].self, forKey: .folders)) ?? []
        // Try new key first; fall back to empty (old "favorites" were a different type)
        pinnedTabs = (try? c.decode([PersistedTab].self, forKey: .pinnedTabs)) ?? []
    }
}

struct PersistedSettings: Codable {
    let maxActiveTabs: Int
    let adBlockLevel: Int
}

struct PersistedBrowserState: Codable {
    let spaces: [PersistedSpace]
    let activeSpaceId: UUID
    let activeTabId: UUID?
    let settings: PersistedSettings
}

//MARK: - OMNIBOX MODEL

struct OmniboxSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let input: String
    let iconURL: URL?
    let fallbackSystemImage: String
}
