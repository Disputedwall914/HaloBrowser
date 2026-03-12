//
//  BrowserContentView.swift
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

struct BrowserContentView: View {
    @Bindable var model: BrowserViewModel

    var body: some View {
        ZStack {
            platformWindowBackgroundColor.ignoresSafeArea()

            if let tab = model.activeTab, let page = tab.page {
                /// iOS 26 / macOS 15 API: WebView(page:) renders the given WebPage directly
                WebView(page)
                    .cornerRadius(12)
                    .padding(8)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            } else if model.activeTab?.isSleeping == true {
                VStack {
                    ProgressView()
                    Text("Waking Tab…").foregroundColor(.secondary).padding(.top)
                }.onAppear { model.activeTab?.wake() }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "globe").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("Open a new tab to begin").foregroundColor(.secondary)
                }
            }
        }
    }
}
