//
//  OmniboxIconView.swift
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

struct OmniboxIconView: View {
    let iconURL: URL?
    let fallbackSystemImage: String
    var body: some View {
        Group {
            if let url = iconURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase { img.resizable().scaledToFit() }
                    else { Image(systemName: fallbackSystemImage).foregroundColor(.secondary) }
                }
            } else {
                Image(systemName: fallbackSystemImage).foregroundColor(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }
}
