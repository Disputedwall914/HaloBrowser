//
//  extension.swift
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

// MARK: - Platform Color Helper
/// Returns the platform-appropriate window background color
var platformWindowBackgroundColor: Color {
    #if os(macOS)
    return Color(NSColor.windowBackgroundColor)
    #else
    return Color(UIColor.systemBackground)
    #endif
}

// MARK: - Color <-> PersistedColor Conversion
/// Extends Color so we can convert to/from our Codable PersistedColor struct
extension Color {
    init(persisted: PersistedColor) {
        self = Color(.sRGB, red: persisted.red, green: persisted.green, blue: persisted.blue, opacity: persisted.alpha)
    }

    var persistedColor: PersistedColor {
        #if os(macOS)
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.black
        return PersistedColor(red: Double(nsColor.redComponent),
                              green: Double(nsColor.greenComponent),
                              blue: Double(nsColor.blueComponent),
                              alpha: Double(nsColor.alphaComponent))
        #else
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return PersistedColor(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
        #endif
    }
}
