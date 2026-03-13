//
//  BrowserTopBarView.swift
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

// MARK: - Top Bar
// ─────────────────────────────────────────────────────────────────────────────
// Design:
//   • Background only covers this VStack column — sidebar stays clean
//   • Lock icon is INSIDE the pill, left-aligned, zero gap to the text
//   • Tapping the lock opens a site info popover (not a tooltip)
//   • Hair-line bottom border, .bar material
// ─────────────────────────────────────────────────────────────────────────────
 
struct BrowserTopBarView: View {
    @Bindable var model: BrowserViewModel
    @State private var isHoveringURL = false
    @State private var showSiteInfo = false   // controls the lock popover
 
    var body: some View {
        HStack(spacing: 0) {
 
            Spacer()
 
            // ── Combined lock + URL pill ──────────────────────────────────
            // The lock button and the URL button share one visual container
            // so they look like a single fused control.
            HStack(spacing: 0) {
 
                // Lock — tapping opens site info popover
                Button {
                    showSiteInfo.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: connectionIconName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(connectionColor)
                    }
                    .padding(.leading, 11)
                    .padding(.trailing, 7)
                    .frame(height: 30)
                    // Right-side divider line between lock and text
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 0.5)
                            .padding(.vertical, 6)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSiteInfo, arrowEdge: .bottom) {
                    SiteInfoPopover(
                        url: activeURL,
                        connectionIconName: connectionIconName,
                        connectionColor: connectionColor,
                        connectionLabel: connectionLabel,
                        isPresented: $showSiteInfo
                    )
                }
 
                // URL — tapping opens omnibox
                Button {
                    model.omniboxInput = activeURLString
                    model.omniboxOpensNewTab = false
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        model.showOmnibox = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        // Favicon
                        if let favURL = model.activeTab?.faviconURL {
                            AsyncImage(url: favURL) { phase in
                                if case .success(let img) = phase {
                                    img.resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                        .clipShape(RoundedRectangle(cornerRadius: 2))
                                }
                            }
                        }
 
                        Text(displayText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 12)
                    .frame(height: 30)
                    .frame(minWidth: 180, maxWidth: 400)
                    .contentShape(Rectangle())  // ← add this
                }
                .buttonStyle(.plain)
            }
            // The whole fused pill gets one shared background + shape
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHoveringURL
                          ? Color.primary.opacity(0.09)
                          : Color.primary.opacity(0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(isHoveringURL ? 0.13 : 0.0), lineWidth: 1)
            }
            .animation(.easeInOut(duration: 0.12), value: isHoveringURL)
            #if os(macOS)
            .onHover { isHoveringURL = $0 }
            #endif
 
            Spacer()
 
            // ── Right: star + wordmark ────────────────────────────────────
            HStack(spacing: 4) {
                Button {
                    model.togglePinActiveTab()
                } label: {
                    Image(systemName: model.isActiveTabPinned ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(model.isActiveTabPinned
                                         ? Color.yellow
                                         : Color.secondary.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(model.isActiveTabPinned
                                         ? Color.yellow.opacity(0.12)
                                         : Color.clear)
                        )
                        .animation(.spring(response: 0.25, dampingFraction: 0.6),
                                   value: model.isActiveTabPinned)
                }
                .buttonStyle(.plain)
                .help(model.isActiveTabPinned ? "Unpin tab" : "Pin to Favourites")
 
                Text("Halo")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .padding(.trailing, 16)
            }
        }
        .frame(height: 48)
        // Material + hairline — only covers THIS column, not the sidebar
        .background(.bar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 0.5)
        }
    }
 
    // MARK: - Helpers
 
    private var activeURL: URL? {
        model.activeTab?.page?.url ?? model.activeTab?.currentURL
    }
    private var activeURLString: String { activeURL?.absoluteString ?? "" }
 
    private var displayText: String {
        guard let url = activeURL, let host = url.host, !host.isEmpty else { return "New Tab" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
 
    private var connectionIconName: String {
        switch activeURL?.scheme?.lowercased() {
        case "https": return "lock.fill"
        case "http":  return "exclamationmark.triangle.fill"
        default:      return "globe"
        }
    }
 
    private var connectionColor: Color {
        switch activeURL?.scheme?.lowercased() {
        case "https": return .green.opacity(0.85)
        case "http":  return .orange
        default:      return .secondary
        }
    }
 
    private var connectionLabel: String {
        switch activeURL?.scheme?.lowercased() {
        case "https": return "Connection is secure"
        case "http":  return "Connection is not secure"
        default:      return "No page loaded"
        }
    }
}
 
 
// MARK: - Site Info Popover
// ─────────────────────────────────────────────────────────────────────────────
// Opens when the user taps the lock icon.
// Shows: domain, full URL, connection status, certificate indicator, cookies.
// ─────────────────────────────────────────────────────────────────────────────
 
private struct SiteInfoPopover: View {
    let url: URL?
    let connectionIconName: String
    let connectionColor: Color
    let connectionLabel: String
    @Binding var isPresented: Bool
 
    // Derived
    private var host: String {
        guard let h = url?.host else { return "—" }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }
    private var fullURL: String { url?.absoluteString ?? "—" }
    private var scheme: String  { url?.scheme?.uppercased() ?? "—" }
    private var isSecure: Bool  { url?.scheme?.lowercased() == "https" }
 
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
 
            // ── Header ────────────────────────────────────────────────────
            HStack(spacing: 10) {
                // Big status icon
                ZStack {
                    Circle()
                        .fill(connectionColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: connectionIconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(connectionColor)
                }
 
                VStack(alignment: .leading, spacing: 2) {
                    Text(host)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(connectionLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(connectionColor)
                }
 
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
 
            Divider()
 
            // ── Info rows ─────────────────────────────────────────────────
            VStack(spacing: 0) {
                InfoRow(
                    icon: "doc.text",
                    iconColor: .blue,
                    label: "Protocol",
                    value: scheme
                )
 
                Divider().padding(.leading, 40)
 
                InfoRow(
                    icon: isSecure ? "checkmark.shield.fill" : "xmark.shield.fill",
                    iconColor: isSecure ? .green : .orange,
                    label: "Certificate",
                    value: isSecure ? "Valid" : "None"
                )
 
                Divider().padding(.leading, 40)
 
                InfoRow(
                    icon: "link",
                    iconColor: .secondary,
                    label: "URL",
                    value: fullURL,
                    isURL: true
                )
            }
            .padding(.vertical, 4)
 
            Divider()
 
            // ── Footer actions ────────────────────────────────────────────
            HStack(spacing: 0) {
                // Copy URL
                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(fullURL, forType: .string)
                    #else
                    UIPasteboard.general.string = fullURL
                    #endif
                    isPresented = false
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
 
                Divider().frame(height: 30)
 
                // Reload
                Button {
                    isPresented = false
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
        }
        .frame(width: 300)
#if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
#else
        .background(Color(uiColor: .systemBackground))
#endif
    }
}
 
// A single labelled row inside the popover
private struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var isURL: Bool = false
 
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 20, alignment: .center)
                .padding(.leading, 12)
 
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
 
            Text(value)
                .font(isURL
                      ? .system(size: 11, design: .monospaced)
                      : .system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(isURL ? 2 : 1)
                .truncationMode(.middle)
 
            Spacer()
        }
        .padding(.vertical, 9)
        .padding(.trailing, 12)
    }
}
