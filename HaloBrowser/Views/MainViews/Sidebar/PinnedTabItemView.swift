//
//  PinnedTabItemView.swift
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

/// The individual favicon tile shown in the pinned strip
struct PinnedTabItemView: View {
    let tab: HaloTab
    let isActive: Bool
    let accentColor: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? accentColor.opacity(0.2) : Color.primary.opacity(0.07))
                    .frame(width: 40, height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(isActive ? accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5))

                AsyncImage(url: tab.faviconURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit().frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "globe").foregroundColor(.secondary)
                    }
                }
            }

//            /// Show a short display title below the favicon (same as Arc)
//            Text(tab.displayTitle)
//                .font(.system(size: 9))
//                .foregroundColor(.secondary)
//                .lineLimit(1)
//                .frame(width: 44)
        }
    }
}
