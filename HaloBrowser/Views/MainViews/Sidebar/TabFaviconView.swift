//
//  TabFaviconView.swift
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

struct TabFaviconView: View {
    let url: URL?
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase { img.resizable().scaledToFit() }
                    else { Image(systemName: "globe").foregroundColor(.secondary) }
                }
            } else {
                Image(systemName: "globe").foregroundColor(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }
}
