//
//  OmniboxView.swift
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

// MARK: - Omnibox
struct OmniboxView: View {
    @Bindable var model: BrowserViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search or type a command...", text: $model.omniboxInput)
                        .textFieldStyle(.plain).focused($isFocused).onSubmit { executePrimary() }
                }
                .padding()

                if !model.suggestions.isEmpty {
                    Divider()
                    VStack(spacing: 0) {
                        ForEach(Array(model.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                            Button { applySuggestion(suggestion) } label: {
                                HStack(spacing: 10) {
                                    OmniboxIconView(iconURL: suggestion.iconURL, fallbackSystemImage: suggestion.fallbackSystemImage)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title).foregroundColor(.primary)
                                        if let sub = suggestion.subtitle { Text(sub).font(.caption).foregroundColor(.secondary) }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(index == model.selectedSuggestionIndex ? Color.primary.opacity(0.08) : Color.clear)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            #if os(macOS)
                            .onHover { if $0 { model.selectedSuggestionIndex = index } }
                            #endif
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
            .background(platformWindowBackgroundColor)
            .cornerRadius(12).shadow(radius: 20).frame(maxWidth: 600).padding(.top, 100)

            Spacer()
        }
        .onAppear { isFocused = true; model.updateSuggestions() }
        .onChange(of: model.omniboxInput) { _, _ in model.updateSuggestions() }
        #if os(macOS)
        .onMoveCommand { dir in
            switch dir {
            case .down: model.selectNextSuggestion()
            case .up:   model.selectPreviousSuggestion()
            default: break
            }
        }
        #endif
    }

    private func executePrimary() {
        guard !model.suggestions.isEmpty else { run(nil); return }
        applySuggestion(model.suggestions[min(max(model.selectedSuggestionIndex, 0), model.suggestions.count - 1)])
    }

    private func applySuggestion(_ s: OmniboxSuggestion) { model.omniboxInput = s.input; run(s.input) }

    private func run(_ rawInput: String?) {
        let input = (rawInput ?? model.omniboxInput).trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = input.lowercased()
        var url: String

        if lower == "help"     { url = dataURL(helpHTML) }
        else if lower == "settings" { url = dataURL(settingsHTML) }
        else if input.hasPrefix("@yt ")   { url = "https://www.youtube.com/results?search_query=\(encode(String(input.dropFirst(4))))" }
        else if input.hasPrefix("@wiki ") { url = "https://en.wikipedia.org/wiki/Special:Search?search=\(encode(String(input.dropFirst(6))))" }
        else if input.hasPrefix("@g ")    { url = "https://www.google.com/search?q=\(encode(String(input.dropFirst(3))))" }
        else if input.contains(".") && !input.contains(" ") { url = input.hasPrefix("http") ? input : "https://" + input }
        else { url = model.searchURL(for: input) }

        if model.omniboxOpensNewTab {
            model.openURLInNewTab(url)
        } else {
            model.openURLInCurrentTab(url)
        }
        model.omniboxOpensNewTab = false
        withAnimation(.spring()) { model.showOmnibox = false; model.omniboxInput = "" }
    }

    private func encode(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s }
    private func dataURL(_ html: String) -> String { "data:text/html," + (html.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") }

    private var helpHTML: String { """
    <html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
    <body style="font-family:-apple-system;padding:24px">
    <h2>Halo Browser Help</h2><p>Type a URL to open it, or search with standard queries.</p>
    <ul><li><b>@yt</b> search YouTube</li><li><b>@wiki</b> search Wikipedia</li>
    <li><b>@g</b> search Google</li><li><b>help</b> show this page</li>
    <li><b>settings</b> open settings page</li></ul>
    <h3>Tips</h3><ul><li>Drag tabs onto folders to organise them</li>
    <li>Star any page to pin it to Favorites</li>
    <li>Right-click tabs for more options</li></ul></body></html>
    """ }

    private var settingsHTML: String { """
    <html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
    <body style="font-family:-apple-system;padding:24px">
    <h2>Settings</h2><p>Use the gear icon in the sidebar to open Settings.</p>
    </body></html>
    """ }
}
