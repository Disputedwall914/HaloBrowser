import SwiftUI
import WebKit
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

private var platformWindowBackgroundColor: Color {
    #if os(macOS)
    return Color(NSColor.windowBackgroundColor)
    #else
    return Color(UIColor.systemBackground)
    #endif
}

extension Color {
    init(persisted: PersistedColor) {
        self = Color(.sRGB, red: persisted.red, green: persisted.green, blue: persisted.blue, opacity: persisted.alpha)
    }
    
    var persistedColor: PersistedColor {
        #if os(macOS)
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.black
        return PersistedColor(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
        #else
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return PersistedColor(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
        #endif
    }
}

// MARK: - 1. Core Models (@Observable)

enum TabCategory: String, Codable {
    case favorite
    case pinned
    case normal
}

@Observable
class HaloTab: Identifiable, Hashable {
    let id: UUID
    var urlString: String
    var customTitle: String?
    var category: TabCategory
    var page: WebPage? // Optional: Nil means the tab is "sleeping" to save RAM
    private static let googleUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    
    init(
        id: UUID = UUID(),
        url: String,
        isSleeping: Bool = false,
        category: TabCategory = .normal,
        customTitle: String? = nil
    ) {
        self.id = id
        self.urlString = url
        self.category = category
        self.customTitle = customTitle
        if !isSleeping {
            wake() // Load immediately on creation
        }
    }
    
    var displayTitle: String {
        if let customTitle, !customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customTitle
        }
        guard let page = page, !page.title.isEmpty else { return urlString }
        return page.title
    }
    
    var isSleeping: Bool {
        page == nil
    }
    
    // RAM Management: Create WebPage
    func wake() {
        if page == nil {
            print("Waking tab: \(urlString)")
            let newPage = WebPage()
            if let customAgent = preferredUserAgent(for: urlString) {
                newPage.customUserAgent = customAgent
            }
            page = newPage
            if let parsedURL = URL(string: urlString) {
                page?.load(URLRequest(url: parsedURL))
            }
        }
    }
    
    // RAM Management: Destroy WebPage
    func sleep() {
        if let currentURL = page?.url?.absoluteString {
            self.urlString = currentURL // Save current state
        }
        print("Sleeping tab to save memory: \(urlString)")
        page = nil
    }
    
    static func == (lhs: HaloTab, rhs: HaloTab) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
    var currentURL: URL? {
        if let pageURL = page?.url { return pageURL }
        return URL(string: urlString)
    }

    var persistedURLString: String {
        page?.url?.absoluteString ?? urlString
    }
    
    var faviconURL: URL? {
        guard let host = currentURL?.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)")
    }
    
    private func preferredUserAgent(for urlString: String) -> String? {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return nil }
        if host.contains("google.") {
            return Self.googleUserAgent
        }
        return nil
    }
}

@Observable
class HaloSpace: Identifiable {
    let id: UUID
    var name: String
    var iconName: String
    var color: Color
    var favoriteTabs: [HaloTab] = []
    var pinnedTabs: [HaloTab] = []
    var tabs: [HaloTab] = []
    var folders: [HaloFolder] = []
    
    init(id: UUID = UUID(), name: String, iconName: String, color: Color) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.color = color
    }
}

@Observable
class HaloFolder: Identifiable, Hashable {
    let id: UUID
    var name: String
    var tabs: [HaloTab]
    
    init(id: UUID = UUID(), name: String, tabs: [HaloTab] = []) {
        self.id = id
        self.name = name
        self.tabs = tabs
    }
    
    static func == (lhs: HaloFolder, rhs: HaloFolder) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@Observable
class BrowserSettings {
    var maxActiveTabs: Int
    var adBlockLevel: Int
    
    init(maxActiveTabs: Int = 3, adBlockLevel: Int = 0) {
        self.maxActiveTabs = maxActiveTabs
        self.adBlockLevel = adBlockLevel
    }
}

struct PersistedTab: Codable {
    let id: UUID
    let urlString: String
    let isSleeping: Bool
    let category: TabCategory
    let customTitle: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case urlString
        case isSleeping
        case category
        case customTitle
    }
    
    init(id: UUID, urlString: String, isSleeping: Bool, category: TabCategory, customTitle: String?) {
        self.id = id
        self.urlString = urlString
        self.isSleeping = isSleeping
        self.category = category
        self.customTitle = customTitle
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        urlString = try container.decode(String.self, forKey: .urlString)
        isSleeping = try container.decode(Bool.self, forKey: .isSleeping)
        category = (try? container.decode(TabCategory.self, forKey: .category)) ?? .normal
        customTitle = try? container.decode(String.self, forKey: .customTitle)
    }
}

struct PersistedFolder: Codable {
    let id: UUID
    let name: String
    let tabs: [PersistedTab]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tabs
    }
    
    init(id: UUID, name: String, tabs: [PersistedTab]) {
        self.id = id
        self.name = name
        self.tabs = tabs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tabs = (try? container.decode([PersistedTab].self, forKey: .tabs)) ?? []
    }
}

struct PersistedSpace: Codable {
    let id: UUID
    let name: String
    let iconName: String
    let color: PersistedColor
    let favoriteTabs: [PersistedTab]
    let pinnedTabs: [PersistedTab]
    let tabs: [PersistedTab]
    let folders: [PersistedFolder]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case iconName
        case color
        case favoriteTabs
        case pinnedTabs
        case tabs
        case folders
    }
    
    init(
        id: UUID,
        name: String,
        iconName: String,
        color: PersistedColor,
        favoriteTabs: [PersistedTab],
        pinnedTabs: [PersistedTab],
        tabs: [PersistedTab],
        folders: [PersistedFolder]
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.color = color
        self.favoriteTabs = favoriteTabs
        self.pinnedTabs = pinnedTabs
        self.tabs = tabs
        self.folders = folders
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        favoriteTabs = (try? container.decode([PersistedTab].self, forKey: .favoriteTabs)) ?? []
        pinnedTabs = (try? container.decode([PersistedTab].self, forKey: .pinnedTabs)) ?? []
        tabs = (try? container.decode([PersistedTab].self, forKey: .tabs)) ?? []
        folders = (try? container.decode([PersistedFolder].self, forKey: .folders)) ?? []
        color = (try? container.decode(PersistedColor.self, forKey: .color))
            ?? PersistedColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
    }
}

struct PersistedSettings: Codable {
    let maxActiveTabs: Int
    let adBlockLevel: Int
}

struct PersistedColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

struct PersistedBrowserState: Codable {
    let spaces: [PersistedSpace]
    let activeSpaceId: UUID
    let activeTabId: UUID?
    let settings: PersistedSettings
}

@Observable
class BrowserViewModel {
    var spaces: [HaloSpace]
    var activeSpaceId: UUID
    var activeTabId: UUID?
    var settings: BrowserSettings = BrowserSettings()
    
    // Omnibox state
    var showOmnibox: Bool = false
    var omniboxInput: String = ""
    var suggestions: [OmniboxSuggestion] = []
    var selectedSuggestionIndex: Int = 0
    
    var activeSpace: HaloSpace {
        spaces.first(where: { $0.id == activeSpaceId }) ?? spaces[0]
    }
    
    var activeTab: HaloTab? {
        activeSpaceAllTabs.first(where: { $0.id == activeTabId })
    }

    private var activeSpaceAllTabs: [HaloTab] {
        activeSpace.favoriteTabs
            + activeSpace.pinnedTabs
            + activeSpace.tabs
            + activeSpace.folders.flatMap { $0.tabs }
    }
    
    init() {
        if let persistedState = Self.loadState() {
            let decodedSpaces = persistedState.spaces.map { space in
                let haloSpace = HaloSpace(
                    id: space.id,
                    name: space.name,
                    iconName: space.iconName,
                    color: Color(persisted: space.color)
                )
                haloSpace.favoriteTabs = space.favoriteTabs.map { tab in
                    HaloTab(
                        id: tab.id,
                        url: tab.urlString,
                        isSleeping: tab.isSleeping,
                        category: .favorite,
                        customTitle: tab.customTitle
                    )
                }
                haloSpace.pinnedTabs = space.pinnedTabs.map { tab in
                    HaloTab(
                        id: tab.id,
                        url: tab.urlString,
                        isSleeping: tab.isSleeping,
                        category: .pinned,
                        customTitle: tab.customTitle
                    )
                }
                haloSpace.tabs = space.tabs.map { tab in
                    HaloTab(
                        id: tab.id,
                        url: tab.urlString,
                        isSleeping: tab.isSleeping,
                        category: tab.category,
                        customTitle: tab.customTitle
                    )
                }
                haloSpace.folders = space.folders.map { folder in
                    HaloFolder(
                        id: folder.id,
                        name: folder.name,
                        tabs: folder.tabs.map { tab in
                            HaloTab(
                                id: tab.id,
                                url: tab.urlString,
                                isSleeping: tab.isSleeping,
                                category: .normal,
                                customTitle: tab.customTitle
                            )
                        }
                    )
                }
                return haloSpace
            }
            if decodedSpaces.isEmpty {
                let fallbackSpaces: [HaloSpace] = [
                    HaloSpace(name: "Personal", iconName: "person", color: Self.randomSpaceColor()),
                    HaloSpace(name: "Work", iconName: "briefcase", color: Self.randomSpaceColor())
                ]
                self.spaces = fallbackSpaces
                self.activeSpaceId = fallbackSpaces[0].id
                self.activeTabId = nil
            } else {
                self.spaces = decodedSpaces
                self.activeSpaceId = persistedState.activeSpaceId
                self.activeTabId = persistedState.activeTabId
                sanitizeSelection()
            }
            self.settings = BrowserSettings(
                maxActiveTabs: persistedState.settings.maxActiveTabs,
                adBlockLevel: persistedState.settings.adBlockLevel
            )
        } else {
            let initialSpaces: [HaloSpace] = [
                HaloSpace(name: "Personal", iconName: "person", color: Self.randomSpaceColor()),
                HaloSpace(name: "Work", iconName: "briefcase", color: Self.randomSpaceColor())
            ]
            self.spaces = initialSpaces
            self.activeSpaceId = initialSpaces[0].id
            self.activeTabId = nil
        }
    }
    
    func selectTab(_ tab: HaloTab) {
        manageMemory(incomingTab: tab)
        tab.wake()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            activeTabId = tab.id
        }
        saveState()
    }
    
    func closeTab(_ tab: HaloTab) {
        guard tab.category != .favorite else { return }
        if let index = activeSpace.tabs.firstIndex(of: tab) {
            activeSpace.tabs.remove(at: index)
        } else if let index = activeSpace.pinnedTabs.firstIndex(of: tab) {
            activeSpace.pinnedTabs.remove(at: index)
        } else if let folder = folderContaining(tab: tab), let index = folder.tabs.firstIndex(of: tab) {
            folder.tabs.remove(at: index)
        }
        if activeTabId == tab.id {
            activeTabId = activeSpaceAllTabs.last?.id
        }
        saveState()
    }

    func setActiveSpace(_ space: HaloSpace) {
        activeSpaceId = space.id
        activeTabId = (space.favoriteTabs + space.pinnedTabs + space.tabs).last?.id
        saveState()
    }

    func openURLInNewTab(_ urlString: String) {
        let newTab = HaloTab(url: urlString, category: .normal)
        activeSpace.tabs.append(newTab)
        selectTab(newTab)
    }
    
    @discardableResult
    func createFolder(name: String) -> HaloFolder? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let newFolder = HaloFolder(name: trimmed)
        activeSpace.folders.append(newFolder)
        saveState()
        return newFolder
    }
    
    func renameTab(_ tab: HaloTab, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        tab.customTitle = trimmed.isEmpty ? nil : trimmed
        saveState()
    }
    
    func duplicateTab(_ tab: HaloTab) {
        let duplicate = HaloTab(
            url: tab.persistedURLString,
            isSleeping: tab.isSleeping,
            category: tab.category,
            customTitle: tab.customTitle
        )
        if let folder = folderContaining(tab: tab) {
            folder.tabs.append(duplicate)
        } else if tab.category == .favorite {
            activeSpace.favoriteTabs.append(duplicate)
        } else if tab.category == .pinned {
            activeSpace.pinnedTabs.append(duplicate)
        } else {
            activeSpace.tabs.append(duplicate)
        }
        saveState()
    }
    
    func toggleFavorite(_ tab: HaloTab) {
        if tab.category == .favorite {
            removeFromFavorites(tab)
        } else {
            favoriteTab(tab)
        }
    }
    
    func togglePinned(_ tab: HaloTab) {
        if tab.category == .pinned {
            moveTab(tab, to: .normal)
        } else {
            pinTab(tab)
        }
    }
    
    func moveTab(_ tab: HaloTab, toSpace space: HaloSpace) {
        guard space.id != activeSpaceId else { return }
        _ = removeTabFromAllSections(tab)
        space.tabs.append(tab)
        if activeTabId == tab.id {
            activeTabId = activeSpaceAllTabs.last?.id
        }
        saveState()
    }
    
    func moveTab(_ tab: HaloTab, toFolder folder: HaloFolder) {
        _ = removeTabFromAllSections(tab)
        tab.category = .normal
        folder.tabs.append(tab)
        if activeTabId == tab.id {
            activeTabId = activeSpaceAllTabs.last?.id
        }
        saveState()
    }
    
    func removeTabFromFolder(_ tab: HaloTab, folder: HaloFolder) {
        guard let index = folder.tabs.firstIndex(of: tab) else { return }
        folder.tabs.remove(at: index)
        activeSpace.tabs.append(tab)
        saveState()
    }
    
    func folderContaining(tab: HaloTab) -> HaloFolder? {
        activeSpace.folders.first(where: { $0.tabs.contains(tab) })
    }
    
    func copyURL(for tab: HaloTab) {
        let urlString = tab.currentURL?.absoluteString ?? tab.persistedURLString
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
        #else
        UIPasteboard.general.string = urlString
        #endif
    }

    func addSpace(name: String, iconName: String, color: Color) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newSpace = HaloSpace(name: trimmed, iconName: iconName, color: color)
        spaces.append(newSpace)
        saveState()
    }

    func removeSpace(_ space: HaloSpace) {
        guard spaces.count > 1, let index = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        spaces.remove(at: index)
        if activeSpaceId == space.id {
            activeSpaceId = spaces.first?.id ?? activeSpaceId
            activeTabId = activeSpaceAllTabs.last?.id
        }
        saveState()
    }
    
    func moveTab(_ tab: HaloTab, to category: TabCategory, index: Int? = nil) {
        _ = removeTabFromAllSections(tab)
        tab.category = category
        switch category {
        case .favorite:
            let insertIndex = min(index ?? activeSpace.favoriteTabs.count, activeSpace.favoriteTabs.count)
            activeSpace.favoriteTabs.insert(tab, at: insertIndex)
        case .pinned:
            let insertIndex = min(index ?? activeSpace.pinnedTabs.count, activeSpace.pinnedTabs.count)
            activeSpace.pinnedTabs.insert(tab, at: insertIndex)
        case .normal:
            let insertIndex = min(index ?? activeSpace.tabs.count, activeSpace.tabs.count)
            activeSpace.tabs.insert(tab, at: insertIndex)
        }
        saveState()
    }

    func moveTabWithinCategory(_ tab: HaloTab, toIndex: Int, category: TabCategory) {
        switch category {
        case .favorite:
            guard let fromIndex = activeSpace.favoriteTabs.firstIndex(of: tab) else { return }
            if fromIndex == toIndex { return }
            let clampedIndex = min(max(toIndex, 0), activeSpace.favoriteTabs.count)
            activeSpace.favoriteTabs.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: clampedIndex > fromIndex ? clampedIndex + 1 : clampedIndex
            )
        case .pinned:
            guard let fromIndex = activeSpace.pinnedTabs.firstIndex(of: tab) else { return }
            if fromIndex == toIndex { return }
            let clampedIndex = min(max(toIndex, 0), activeSpace.pinnedTabs.count)
            activeSpace.pinnedTabs.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: clampedIndex > fromIndex ? clampedIndex + 1 : clampedIndex
            )
        case .normal:
            guard let fromIndex = activeSpace.tabs.firstIndex(of: tab) else { return }
            if fromIndex == toIndex { return }
            let clampedIndex = min(max(toIndex, 0), activeSpace.tabs.count)
            activeSpace.tabs.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: clampedIndex > fromIndex ? clampedIndex + 1 : clampedIndex
            )
        }
        saveState()
    }

    func tab(for id: UUID) -> HaloTab? {
        activeSpaceAllTabs.first(where: { $0.id == id })
    }
    
    func pinTab(_ tab: HaloTab) {
        moveTab(tab, to: .pinned)
    }
    
    func favoriteTab(_ tab: HaloTab) {
        moveTab(tab, to: .favorite)
    }
    
    func removeFromFavorites(_ tab: HaloTab) {
        guard tab.category == .favorite else { return }
        moveTab(tab, to: .normal)
    }
    
    func updateSuggestions() {
        let trimmedInput = omniboxInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        suggestionTask?.cancel()
        if trimmedInput.isEmpty {
            suggestions = []
            selectedSuggestionIndex = 0
            return
        }
        
        let commandMatches = commandSuggestions(for: trimmedInput)
        let searchSuggestion = searchQuerySuggestion(for: trimmedInput)
        suggestions = commandMatches + [searchSuggestion]
        selectedSuggestionIndex = 0
        
        suggestionTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            let googleSuggestions = await fetchGoogleSuggestions(query: trimmedInput)
            if Task.isCancelled { return }
            await MainActor.run {
                let combined = commandMatches + [searchSuggestion] + googleSuggestions
                suggestions = combined
            }
        }
    }
    
    func selectNextSuggestion() {
        guard !suggestions.isEmpty else { return }
        selectedSuggestionIndex = min(selectedSuggestionIndex + 1, suggestions.count - 1)
    }
    
    func selectPreviousSuggestion() {
        guard !suggestions.isEmpty else { return }
        selectedSuggestionIndex = max(selectedSuggestionIndex - 1, 0)
    }
    
    // The RAM Manager: Unloads tabs if we exceed maxActiveTabs
    private func manageMemory(incomingTab: HaloTab) {
        let activeTabs = spaces.flatMap { space in
            space.favoriteTabs + space.pinnedTabs + space.tabs + space.folders.flatMap { $0.tabs }
        }.filter { !$0.isSleeping && $0.id != incomingTab.id }
        
        if activeTabs.count >= settings.maxActiveTabs {
            // Find the oldest active tab that isn't the currently active one and sleep it
            if let victim = activeTabs.first(where: { $0.id != self.activeTabId }) {
                victim.sleep()
            }
        }
    }

    private func sanitizeSelection() {
        if !spaces.contains(where: { $0.id == activeSpaceId }) {
            activeSpaceId = spaces.first?.id ?? activeSpaceId
        }
        if let activeTabId, activeSpaceAllTabs.contains(where: { $0.id == activeTabId }) {
            return
        }
        activeTabId = activeSpaceAllTabs.last?.id
    }

    private func removeTabFromAllSections(_ tab: HaloTab) -> TabCategory? {
        if let index = activeSpace.favoriteTabs.firstIndex(of: tab) {
            activeSpace.favoriteTabs.remove(at: index)
            return .favorite
        }
        if let index = activeSpace.pinnedTabs.firstIndex(of: tab) {
            activeSpace.pinnedTabs.remove(at: index)
            return .pinned
        }
        if let index = activeSpace.tabs.firstIndex(of: tab) {
            activeSpace.tabs.remove(at: index)
            return .normal
        }
        if let folder = folderContaining(tab: tab),
           let index = folder.tabs.firstIndex(of: tab) {
            folder.tabs.remove(at: index)
            return .normal
        }
        return nil
    }

    func saveState() {
        let spacesToPersist = spaces.map { space in
            PersistedSpace(
                id: space.id,
                name: space.name,
                iconName: space.iconName,
                color: space.color.persistedColor,
                favoriteTabs: space.favoriteTabs.map { tab in
                    PersistedTab(
                        id: tab.id,
                        urlString: tab.persistedURLString,
                        isSleeping: tab.isSleeping,
                        category: .favorite,
                        customTitle: tab.customTitle
                    )
                },
                pinnedTabs: space.pinnedTabs.map { tab in
                    PersistedTab(
                        id: tab.id,
                        urlString: tab.persistedURLString,
                        isSleeping: tab.isSleeping,
                        category: .pinned,
                        customTitle: tab.customTitle
                    )
                },
                tabs: space.tabs.map { tab in
                    PersistedTab(
                        id: tab.id,
                        urlString: tab.persistedURLString,
                        isSleeping: tab.isSleeping,
                        category: .normal,
                        customTitle: tab.customTitle
                    )
                },
                folders: space.folders.map { folder in
                    PersistedFolder(
                        id: folder.id,
                        name: folder.name,
                        tabs: folder.tabs.map { tab in
                            PersistedTab(
                                id: tab.id,
                                urlString: tab.persistedURLString,
                                isSleeping: tab.isSleeping,
                                category: .normal,
                                customTitle: tab.customTitle
                            )
                        }
                    )
                },
                folders: space.folders.map { folder in
                    PersistedFolder(
                        id: folder.id,
                        name: folder.name,
                        tabs: folder.tabs.map { tab in
                            PersistedTab(
                                id: tab.id,
                                urlString: tab.persistedURLString,
                                isSleeping: tab.isSleeping,
                                category: .normal,
                                customTitle: tab.customTitle
                            )
                        }
                    )
                }
            )
        }
        let state = PersistedBrowserState(
            spaces: spacesToPersist,
            activeSpaceId: activeSpaceId,
            activeTabId: activeTabId,
            settings: PersistedSettings(
                maxActiveTabs: settings.maxActiveTabs,
                adBlockLevel: settings.adBlockLevel
            )
        )

        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        } catch {
            print("Failed to save browser state: \(error)")
        }
    }

    private static func loadState() -> PersistedBrowserState? {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return nil }
        do {
            return try JSONDecoder().decode(PersistedBrowserState.self, from: data)
        } catch {
            print("Failed to load browser state: \(error)")
            return nil
        }
    }

    private static let persistenceKey = "HaloBrowser.PersistentState"
    private static let availableColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .pink, .purple
    ]
    
    static func randomSpaceColor() -> Color {
        availableColors.randomElement() ?? .blue
    }
    
    private var suggestionTask: Task<Void, Never>?
    
    private func commandSuggestions(for input: String) -> [OmniboxSuggestion] {
        let lowered = input.lowercased()
        var matches: [OmniboxSuggestion] = []
        
        if "help".hasPrefix(lowered) {
            matches.append(
                OmniboxSuggestion(
                    title: "help",
                    subtitle: "Show available commands",
                    input: "help",
                    iconURL: nil,
                    fallbackSystemImage: "questionmark.circle"
                )
            )
        }
        
        if "settings".hasPrefix(lowered) {
            matches.append(
                OmniboxSuggestion(
                    title: "settings",
                    subtitle: "Open basic settings page",
                    input: "settings",
                    iconURL: nil,
                    fallbackSystemImage: "gearshape"
                )
            )
        }
        
        return matches
    }
    
    private func searchQuerySuggestion(for input: String) -> OmniboxSuggestion {
        let isURLLike = input.contains(".") && !input.contains(" ")
        let normalized = input.hasPrefix("http") ? input : "https://" + input
        let title = isURLLike ? "Open \(normalized)" : "Search for \"\(input)\""
        let iconURL = isURLLike ? faviconURL(for: normalized) : nil
        let fallbackIcon = isURLLike ? "globe" : "magnifyingglass"
        
        return OmniboxSuggestion(
            title: title,
            subtitle: input,
            input: input,
            iconURL: iconURL,
            fallbackSystemImage: fallbackIcon
        )
    }
    
    private func fetchGoogleSuggestions(query: String) async -> [OmniboxSuggestion] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&q=\(encodedQuery)") else {
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONSerialization.jsonObject(with: data, options: [])
            guard let array = decoded as? [Any],
                  array.count > 1,
                  let suggestions = array[1] as? [String] else {
                return []
            }
            
            return suggestions.map { suggestion in
                OmniboxSuggestion(
                    title: suggestion,
                    subtitle: "Search",
                    input: suggestion,
                    iconURL: nil,
                    fallbackSystemImage: "magnifyingglass"
                )
            }
        } catch {
            return []
        }
    }
    
    private func faviconURL(for urlString: String) -> URL? {
        guard let url = URL(string: urlString),
              let host = url.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=32&domain=\(host)")
    }
}

// MARK: - 2. Main Layout
struct BrowserView: View {
    @State private var model = BrowserViewModel()
    @State private var sidebarWidth: CGFloat = 250
    @State private var showSettings: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                BrowserTopBarView(model: model)
                
                HStack(spacing: 0) {
                    // Sidebar
                    SidebarView(model: model, showSettings: $showSettings)
                        .frame(width: sidebarWidth)
                        .background(.ultraThinMaterial)
                        .background(model.activeSpace.color.opacity(0.12))
                    
                    BrowserContentView(model: model)
                }
            }
            
            // Omnibox Overlay
            if model.showOmnibox {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) { model.showOmnibox = false }
                    }
                
                OmniboxView(model: model)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .sheet(isPresented: $showSettings) {
            BrowserSettingsView(model: model)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                model.saveState()
            }
        }
    }
}

struct BrowserContentView: View {
    @Bindable var model: BrowserViewModel
    
    var body: some View {
        // Active Web Content
        ZStack {
            platformWindowBackgroundColor.ignoresSafeArea()
            
            if let activeTab = model.activeTab, let page = activeTab.page {
                WebView(page)
                    .cornerRadius(12)
                    .padding(8)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            } else if model.activeTab?.isSleeping == true {
                VStack {
                    ProgressView()
                    Text("Waking Tab...")
                        .foregroundColor(.secondary)
                        .padding(.top)
                }.onAppear {
                    model.activeTab?.wake()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Open a new tab to begin")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Top Bar
struct BrowserTopBarView: View {
    @Bindable var model: BrowserViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: connectionIconName)
                    .foregroundColor(connectionColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(connectionLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(connectionDetail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 12)
            
            Spacer()
            
            Button(action: {
                model.omniboxInput = activeURLString
                withAnimation(.spring()) {
                    model.showOmnibox = true
                }
            }) {
                Text(displayHost)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Halo")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.trailing, 12)
        }
        .frame(height: 44)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }
    
    private var activeURL: URL? {
        if let pageURL = model.activeTab?.page?.url {
            return pageURL
        }
        if let urlString = model.activeTab?.urlString {
            return URL(string: urlString)
        }
        return nil
    }
    
    private var activeURLString: String {
        activeURL?.absoluteString ?? ""
    }
    
    private var displayHost: String {
        let host = activeURL?.host ?? ""
        return host.isEmpty ? "New Tab" : host
    }
    
    private var connectionLabel: String {
        guard let scheme = activeURL?.scheme?.lowercased() else { return "No Connection" }
        return scheme == "https" ? "Secure" : "Insecure"
    }
    
    private var connectionDetail: String {
        guard let url = activeURL else { return "Not connected" }
        return "\(url.scheme?.uppercased() ?? "UNKNOWN") • \(url.host ?? "")"
    }
    
    private var connectionIconName: String {
        guard let scheme = activeURL?.scheme?.lowercased() else { return "bolt.slash" }
        return scheme == "https" ? "lock.fill" : "exclamationmark.triangle.fill"
    }
    
    private var connectionColor: Color {
        guard let scheme = activeURL?.scheme?.lowercased() else { return .secondary }
        return scheme == "https" ? .green : .orange
    }
}

// MARK: - 3. Sidebar View
struct SidebarView: View {
    @Bindable var model: BrowserViewModel
    @Binding var showSettings: Bool
    @State private var draggedTabId: UUID?
    @State private var highlightedCategory: TabCategory?
    
    private let favoriteColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Action Area
            HStack {
                Text(model.activeSpace.name)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        model.omniboxInput = ""
                        model.showOmnibox = true
                    }
                }) {
                    Image(systemName: "plus")
                        .padding(8)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Tabs List
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !model.activeSpace.favoriteTabs.isEmpty || draggedTabId != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Favorites")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        VStack(spacing: 8) {
                            if model.activeSpace.favoriteTabs.isEmpty, draggedTabId != nil {
                                Text("Drop tab to favorite")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            LazyVGrid(columns: favoriteColumns, spacing: 10) {
                                ForEach(model.activeSpace.favoriteTabs) { tab in
                                    Button(action: { model.selectTab(tab) }) {
                                        TabFaviconView(url: tab.faviconURL)
                                            .frame(width: 36, height: 36)
                                            .background(Color.primary.opacity(0.08))
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        model.activeTabId == tab.id ? model.activeSpace.color : Color.clear,
                                                        lineWidth: 2
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .onDrag {
                                        draggedTabId = tab.id
                                        return NSItemProvider(object: tab.id.uuidString as NSString)
                                    }
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: TabSectionDropDelegate(
                                            model: model,
                                            targetCategory: .favorite,
                                            targetTab: tab,
                                            draggedTabId: $draggedTabId,
                                            highlightedCategory: $highlightedCategory
                                        )
                                    )
                                }
                            }
                        }
                        .padding(10)
                        .background(
                            highlightedCategory == .favorite
                            ? Color.primary.opacity(0.08)
                            : Color.clear
                        )
                        .cornerRadius(12)
                        .onDrop(
                            of: [UTType.text],
                            delegate: TabSectionDropDelegate(
                                model: model,
                                targetCategory: .favorite,
                                targetTab: nil,
                                draggedTabId: $draggedTabId,
                                highlightedCategory: $highlightedCategory
                            )
                        )
                        }
                    }
                    
                    if !model.activeSpace.pinnedTabs.isEmpty || draggedTabId != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pinned")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        VStack(spacing: 6) {
                            if model.activeSpace.pinnedTabs.isEmpty, draggedTabId != nil {
                                Text("Drop tab to pin")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                            }
                            ForEach(model.activeSpace.pinnedTabs) { tab in
                                HStack(spacing: 8) {
                                    TabFaviconView(url: tab.faviconURL)
                                    Text(tab.displayTitle)
                                        .lineLimit(1)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(tab.isSleeping ? .secondary : .primary)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(model.activeTabId == tab.id ? Color.primary.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    model.selectTab(tab)
                                }
                                .onDrag {
                                    draggedTabId = tab.id
                                    return NSItemProvider(object: tab.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: TabSectionDropDelegate(
                                        model: model,
                                        targetCategory: .pinned,
                                        targetTab: tab,
                                        draggedTabId: $draggedTabId,
                                        highlightedCategory: $highlightedCategory
                                    )
                                )
                            }
                        }
                        .padding(10)
                        .background(
                            highlightedCategory == .pinned
                            ? Color.primary.opacity(0.08)
                            : Color.clear
                        )
                        .cornerRadius(12)
                        .onDrop(
                            of: [UTType.text],
                            delegate: TabSectionDropDelegate(
                                model: model,
                                targetCategory: .pinned,
                                targetTab: nil,
                                draggedTabId: $draggedTabId,
                                highlightedCategory: $highlightedCategory
                            )
                        )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tabs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        VStack(spacing: 4) {
                            ForEach(model.activeSpace.tabs) { tab in
                                HStack {
                                    // Sleeping Indicator
                                    Circle()
                                        .fill(tab.isSleeping ? Color.gray : model.activeSpace.color)
                                        .frame(width: 8, height: 8)
                                    
                                    TabFaviconView(url: tab.faviconURL)
                                    
                                    Text(tab.displayTitle)
                                        .lineLimit(1)
                                        .foregroundColor(tab.isSleeping ? .secondary : .primary)
                                    
                                    Spacer()
                                    
                                    Button(action: { model.closeTab(tab) }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .opacity(model.activeTabId == tab.id ? 1 : 0.0)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(model.activeTabId == tab.id ? Color.primary.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    model.selectTab(tab)
                                }
                                .onDrag {
                                    draggedTabId = tab.id
                                    return NSItemProvider(object: tab.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: TabSectionDropDelegate(
                                        model: model,
                                        targetCategory: .normal,
                                        targetTab: tab,
                                        draggedTabId: $draggedTabId,
                                        highlightedCategory: $highlightedCategory
                                    )
                                )
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(highlightedCategory == .normal ? 0.12 : 0.04))
                        )
                        .onDrop(
                            of: [UTType.text],
                            delegate: TabSectionDropDelegate(
                                model: model,
                                targetCategory: .normal,
                                targetTab: nil,
                                draggedTabId: $draggedTabId,
                                highlightedCategory: $highlightedCategory
                            )
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }
            
            Spacer()
            
            // Space Switcher
            HStack {
                ForEach(model.spaces) { space in
                    Button(action: {
                        withAnimation { model.setActiveSpace(space) }
                    }) {
                        Image(systemName: space.iconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 26, height: 26)
                            .background(space.color.opacity(model.activeSpaceId == space.id ? 0.45 : 0.2))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(model.activeSpaceId == space.id ? 0.4 : 0.0), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                }
                
                Spacer()
                
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.05))
        }
    }
}

struct TabSectionDropDelegate: DropDelegate {
    let model: BrowserViewModel
    let targetCategory: TabCategory
    let targetTab: HaloTab?
    @Binding var draggedTabId: UUID?
    @Binding var highlightedCategory: TabCategory?
    
    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }
    
    func dropEntered(info: DropInfo) {
        highlightedCategory = targetCategory
        guard let draggedTabId, let draggedTab = model.tab(for: draggedTabId) else { return }
        
        if draggedTab.category == targetCategory {
            if let targetTab {
                let toIndex = indexForTarget(tab: targetTab, in: targetCategory)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    model.moveTabWithinCategory(draggedTab, toIndex: toIndex, category: targetCategory)
                }
            }
        } else {
            let toIndex = targetTab.map { indexForTarget(tab: $0, in: targetCategory) }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                model.moveTab(draggedTab, to: targetCategory, index: toIndex)
            }
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        highlightedCategory = nil
        draggedTabId = nil
        return true
    }
    
    func dropExited(info: DropInfo) {
        if highlightedCategory == targetCategory {
            highlightedCategory = nil
        }
    }
    
    private func indexForTarget(tab: HaloTab, in category: TabCategory) -> Int {
        switch category {
        case .favorite:
            return model.activeSpace.favoriteTabs.firstIndex(of: tab) ?? model.activeSpace.favoriteTabs.count
        case .pinned:
            return model.activeSpace.pinnedTabs.firstIndex(of: tab) ?? model.activeSpace.pinnedTabs.count
        case .normal:
            return model.activeSpace.tabs.firstIndex(of: tab) ?? model.activeSpace.tabs.count
        }
    }
}

// MARK: - 4. Omnibox (Command Bar)
struct OmniboxView: View {
    @Bindable var model: BrowserViewModel
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search or type a command...", text: $model.omniboxInput)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit {
                            executePrimaryAction()
                        }
                }
                .padding()
                
                if !model.suggestions.isEmpty {
                    Divider()
                    
                    VStack(spacing: 0) {
                        ForEach(Array(model.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                            Button(action: {
                                applySuggestion(suggestion)
                            }) {
                                HStack(spacing: 10) {
                                    OmniboxIconView(iconURL: suggestion.iconURL, fallbackSystemImage: suggestion.fallbackSystemImage)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .foregroundColor(.primary)
                                        if let subtitle = suggestion.subtitle {
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(index == model.selectedSuggestionIndex ? Color.primary.opacity(0.08) : Color.clear)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            #if os(macOS)
                            .onHover { isHovering in
                                if isHovering {
                                    model.selectedSuggestionIndex = index
                                }
                            }
                            #endif
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
            .background(platformWindowBackgroundColor)
            .cornerRadius(12)
            .shadow(radius: 20)
            .frame(maxWidth: 600)
            .padding(.top, 100)
            
            Spacer()
        }
        .onAppear {
            isFocused = true
            model.updateSuggestions()
        }
        .onChange(of: model.omniboxInput) { _, newValue in
            model.updateSuggestions()
        }
        #if os(macOS)
        .onMoveCommand { direction in
            switch direction {
            case .down:
                model.selectNextSuggestion()
            case .up:
                model.selectPreviousSuggestion()
            default:
                break
            }
        }
        #endif
    }
    
    private func executePrimaryAction() {
        guard !model.suggestions.isEmpty else {
            executeCommand()
            return
        }
        
        let safeIndex = min(max(model.selectedSuggestionIndex, 0), model.suggestions.count - 1)
        applySuggestion(model.suggestions[safeIndex])
    }
    
    private func executeCommand(input: String? = nil) {
        let rawInput = input ?? model.omniboxInput
        let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedInput = trimmedInput.lowercased()
        var finalURLStr = ""
        
        // Command Parser
        if lowercasedInput == "help" {
            finalURLStr = makeDataURL(html: omniboxHelpHTML)
        } else if lowercasedInput == "settings" {
            finalURLStr = makeDataURL(html: omniboxSettingsHTML)
        } else if trimmedInput.hasPrefix("@yt ") {
            let query = trimmedInput.dropFirst(4).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            finalURLStr = "https://www.youtube.com/results?search_query=\(query)"
        } else if trimmedInput.hasPrefix("@wiki ") {
            let query = trimmedInput.dropFirst(6).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            finalURLStr = "https://en.wikipedia.org/wiki/Special:Search?search=\(query)"
        } else if trimmedInput.hasPrefix("@g ") {
            let query = trimmedInput.dropFirst(3).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            finalURLStr = "https://www.google.com/search?q=\(query)"
        } else {
            // Standard URL or Search fallback
            if trimmedInput.contains(".") && !trimmedInput.contains(" ") {
                finalURLStr = trimmedInput.hasPrefix("http") ? trimmedInput : "https://" + trimmedInput
            } else {
                let query = trimmedInput.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                finalURLStr = "https://google.com/search?q=\(query)"
            }
        }
        
        // Create new tab and clean up
        model.openURLInNewTab(finalURLStr)
        
        withAnimation(.spring()) {
            model.showOmnibox = false
            model.omniboxInput = ""
        }
    }
    
    private func applySuggestion(_ suggestion: OmniboxSuggestion) {
        model.omniboxInput = suggestion.input
        executeCommand(input: suggestion.input)
    }
    
    private func makeDataURL(html: String) -> String {
        let encoded = html.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "data:text/html," + encoded
    }
    
    private var omniboxHelpHTML: String {
        """
        <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
        <body style="font-family: -apple-system; padding: 24px;">
            <h2>Halo Browser Help</h2>
            <p>Type a URL to open it, or search with standard queries.</p>
            <ul>
                <li><b>@yt</b> search YouTube</li>
                <li><b>@wiki</b> search Wikipedia</li>
                <li><b>@g</b> search Google</li>
                <li><b>help</b> show this page</li>
                <li><b>settings</b> open settings page</li>
            </ul>
        </body>
        </html>
        """
    }
    
    private var omniboxSettingsHTML: String {
        """
        <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
        <body style="font-family: -apple-system; padding: 24px;">
            <h2>Settings</h2>
            <p>Use the gear icon in the sidebar to open Settings.</p>
        </body>
        </html>
        """
    }
}

struct OmniboxSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let input: String
    let iconURL: URL?
    let fallbackSystemImage: String
}

struct OmniboxIconView: View {
    let iconURL: URL?
    let fallbackSystemImage: String
    
    var body: some View {
        Group {
            if let iconURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        Image(systemName: fallbackSystemImage)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Image(systemName: fallbackSystemImage)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }
}

struct TabFaviconView: View {
    let url: URL?
    
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        Image(systemName: "globe")
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }
}

struct BrowserSettingsView: View {
    @Bindable var model: BrowserViewModel
    @State private var newSpaceName: String = ""
    @State private var newSpaceIconName: String = "person"
    @State private var newSpaceColor: Color = BrowserViewModel.randomSpaceColor()
    
    private let iconOptions: [String] = [
        "person",
        "briefcase",
        "globe",
        "sparkles",
        "book",
        "hammer",
        "heart",
        "bolt",
        "leaf",
        "gamecontroller"
    ]
    
    var body: some View {
        Form {
            Section("Spaces") {
                HStack(spacing: 12) {
                    TextField("Space name", text: $newSpaceName)
                    Picker("Icon", selection: $newSpaceIconName) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Label(icon, systemImage: icon)
                        }
                    }
                    .pickerStyle(.menu)
                    ColorPicker("Color", selection: $newSpaceColor, supportsOpacity: false)
                        .labelsHidden()
                    Button("Add") {
                        model.addSpace(name: newSpaceName, iconName: newSpaceIconName, color: newSpaceColor)
                        newSpaceName = ""
                        newSpaceColor = BrowserViewModel.randomSpaceColor()
                    }
                    .disabled(newSpaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(model.spaces) { space in
                    HStack {
                        Image(systemName: space.iconName)
                            .foregroundColor(.secondary)
                        Text(space.name)
                        Spacer()
                        ColorPicker(
                            "Color",
                            selection: Binding(
                                get: { space.color },
                                set: { newValue in
                                    space.color = newValue
                                    model.saveState()
                                }
                            ),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        Button("Remove") {
                            model.removeSpace(space)
                        }
                        .disabled(model.spaces.count <= 1)
                    }
                }
            }
            
            Section("Performance") {
                Stepper(value: $model.settings.maxActiveTabs, in: 1...12) {
                    Text("Max active tabs: \(model.settings.maxActiveTabs)")
                }
                Picker("Ad block level", selection: $model.settings.adBlockLevel) {
                    Text("Off").tag(0)
                    Text("Balanced").tag(1)
                    Text("Strict").tag(2)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
        .onChange(of: model.settings.maxActiveTabs) { _, _ in
            model.saveState()
        }
        .onChange(of: model.settings.adBlockLevel) { _, _ in
            model.saveState()
        }
    }
}
@main
struct HaloBrowserApp: App {
    var body: some Scene {
        WindowGroup {
            BrowserView()
        }
    }
}
