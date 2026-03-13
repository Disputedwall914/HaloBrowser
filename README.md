# Halo Browser

A lightweight, Arc-inspired browser for **iOS & macOS** built with SwiftUI and WebKit. Spaces, pinned tabs, tab sleeping, and a fast omnibox — all in a clean sidebar-first layout.

---

## ✨ Features

### 🗂️ Spaces
Organise your browsing into named workspaces — Personal, Work, Research, or whatever fits. Each space has its own colour, icon, tabs, folders, and pinned favourites. Switch between them with a single tap from the bottom of the sidebar.

### ⭐️ Pinned Favourites
Pin any tab to the Arc-style favicon strip at the top of the sidebar. Pinned tabs are full tabs — select them, close them, or unpin them back to the regular list. Drag to reorder.

### 📁 Tab Folders
Group related tabs into colour-coded folders. Expand/collapse inline, drag tabs onto folders to organise, or pull them back out with a right-click. Folders move with their space.

### 💤 Tab Sleeping
Halo automatically puts older tabs to sleep when you hit the configurable active-tab limit (default: 3). Sleeping tabs preserve their URL but free their WebView memory. Wake any tab with a tap.

### 🔍 Omnibox
Press `+` or click the address bar to open the command palette. Type a URL, search query, or a shortcut:

| Shortcut | Action |
|---|---|
| `@yt <query>` | Search YouTube |
| `@wiki <query>` | Search Wikipedia |
| `@g <query>` | Search Google |

Live suggestions are fetched as you type (can be disabled in Settings → Search).

### 🔒 Site Info
Click the lock icon in the address bar for a popover showing protocol, certificate status, and full URL — with a one-tap copy button.

### ⚙️ Settings
Full settings panel (macOS sheet / iPad glass overlay) with six panes:

- **Tabs** — max active tabs, new tab behaviour
- **Spaces** — add, edit, reorder, and delete spaces
- **Search** — default engine (Google, DDG, Brave, Bing, Ecosia, Kagi), suggestion toggle
- **Profiles** — coming soon
- **Privacy** — ad block level, cookie controls, HTTPS upgrade, fingerprint protection, clear site data
- **Advanced** — Web Inspector toggle, full URL display

---

## 🗺️ Roadmap

### 🔜 Near-term
- [ ] Wire up `newTabBehaviour` and `defaultNewTabPage` settings
- [ ] Wire up `httpsUpgrade` in WKWebView configuration
- [ ] Wire up `blockThirdPartyCookies` via content rules
- [ ] Wire up `fingerprintProtection` via `WKUserScript` injection
- [ ] Wire up `developerMode` (Web Inspector / Inspect Element)
- [ ] Wire up `showFullURL` in the address bar

### 🧭 Planned
- [ ] iCloud sync
- [ ] Multiple profiles
- [ ] Favourites grid as default new tab page
- [ ] History and bookmarks
- [ ] Extensions / content rule list editor

---

## 🚀 Getting Started

1. Clone the repo and open `HaloBrowser.xcodeproj` in Xcode
2. Select your target — **iOS** (iPad recommended) or **macOS**
3. Build & run — no third-party dependencies required
