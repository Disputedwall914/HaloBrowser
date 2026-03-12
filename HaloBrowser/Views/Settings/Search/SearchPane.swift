//
//  SearchPane.swift
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
// MARK: PANE: SEARCH
// ─────────────────────────────────────────────────────────────────────────────
//
// 🔧 TO WIRE: searchEngine
//   ① Add to BrowserSettings:
//       var searchEngine: String = "Google"
//       var showSuggestions: Bool = true
//
//   ② Replace @State selectedEngine with $model.settings.searchEngine
//      Replace @State showSuggestions with $model.settings.showSuggestions
//      Add .onChange { _, _ in model.saveState() } to each control.
//
//   ③ In BrowserViewModel (OmniboxView's run() method), replace the hardcoded
//      Google URL with a helper that reads model.settings.searchEngine:
//
//       func searchURL(for query: String) -> String {
//           let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
//           switch settings.searchEngine {
//           case "DuckDuckGo": return "https://duckduckgo.com/?q=\(q)"
//           case "Bing":       return "https://bing.com/search?q=\(q)"
//           case "Brave":      return "https://search.brave.com/search?q=\(q)"
//           case "Ecosia":     return "https://ecosia.org/search?q=\(q)"
//           case "Kagi":       return "https://kagi.com/search?q=\(q)"
//           default:           return "https://google.com/search?q=\(q)"
//           }
//       }
//
//   ④ For showSuggestions: in BrowserViewModel.updateSuggestions(),
//      wrap the fetchGoogleSuggestions task with:
//       guard settings.showSuggestions else { return }
// ─────────────────────────────────────────────────────────────────────────────

struct SearchPane: View {
    @Bindable var model: BrowserViewModel

    private let engines = ["Google", "DuckDuckGo", "Brave", "Bing", "Ecosia", "Kagi"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(pane: .search)

            SettingsSection(title: "Default Search Engine") {
                ForEach(engines, id: \.self) { engine in
                    if engine != engines.first { RowDivider() }
                    Button {
                        model.settings.searchEngine = engine
                        model.saveState()
                        // 🔧 Once wired: model.settings.searchEngine = engine; model.saveState()
                    } label: {
                        HStack {
                            Text(engine).font(.system(size: 13)).foregroundColor(.primary)
                            Spacer()
                            if model.settings.searchEngine == engine {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }

            SettingsSection(title: "Omnibox") {
                SettingsRow("Show search suggestions",
                            description: "Fetches live suggestions as you type") {
                    Toggle("", isOn: $model.settings.showSuggestions)
                        .labelsHidden()
                        .onChange(of: model.settings.showSuggestions) { _, _ in model.saveState() }
                }
            }

            SettingsSection(title: "Shortcuts") {
                SettingsRow("@yt")   { monoLabel("youtube.com/results?search_query=…") }
                RowDivider()
                SettingsRow("@wiki") { monoLabel("en.wikipedia.org/…Special:Search?search=…") }
                RowDivider()
                SettingsRow("@g")    { monoLabel("google.com/search?q=…") }
            }
        }
    }

    private func monoLabel(_ s: String) -> some View {
        Text(s).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
    }
}
