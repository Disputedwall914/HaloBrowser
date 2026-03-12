//
//  BrowserView.swift
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


// MARK: - Main Layout
// ─────────────────────────────────────────────────────────────────────────────
// The bar is now rendered ONLY above the web content column, not spanning the
// full window width. The sidebar has its own header and needs no bar.
//
// Structure:
//   HStack {
//     SidebarView          ← no top bar, owns its own header
//     VStack {
//       BrowserTopBarView  ← sits only above the web content
//       BrowserContentView
//     }
//   }
// ─────────────────────────────────────────────────────────────────────────────


struct BrowserView: View {
    @State private var model = BrowserViewModel()
    @State private var showSettings: Bool = false
    @Environment(\.scenePhase) private var scenePhase
 
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Sidebar — full height, owns its own header, no top bar
                SidebarView(model: model, showSettings: $showSettings)
                    .frame(width: 260)
                    .background(.ultraThinMaterial)
                    .background(model.activeSpace.color.opacity(0.12))
 
                // Web content column — bar sits only here
                VStack(spacing: 0) {
                    BrowserTopBarView(model: model)
                    BrowserContentView(model: model)
                }
            }
 
            // Omnibox overlay
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
        .sheet(isPresented: $showSettings) { BrowserSettingsView(model: model) }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { model.saveState() }
        }
    }
}
