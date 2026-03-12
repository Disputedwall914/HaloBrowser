//
//  SpaceCard.swift
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

// MARK: - Space Card

/// A single space tile. Collapsed shows the badge + name + subtle controls.
/// Expanded (isEditing) reveals inline name/icon/colour editing.
struct SpaceCard: View {
    @Bindable var space: HaloSpace
    let isEditing: Bool
    let isDragging: Bool
    let canDelete: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onChanged: () -> Void

    @State private var isHovering = false
    @State private var editingName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Collapsed / always-visible header ────────────────────────
            Button(action: onTap) {
                VStack(spacing: 10) {
                    ZStack(alignment: .topTrailing) {
                        // Big colour badge
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(space.color.gradient)
                                .frame(width: 52, height: 52)
                            Image(systemName: space.iconName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        // Delete button — shown on hover or edit
                        if (isHovering || isEditing) && canDelete {
                            Button(action: onDelete) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                    }

                    Text(space.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            // ── Expanded edit panel ───────────────────────────────────────
            if isEditing {
                Divider().padding(.horizontal, 12)

                VStack(spacing: 10) {
                    // Name field
                    TextField("Space name", text: Binding(
                        get: { space.name },
                        set: { space.name = $0; onChanged() }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                    // Colour picker row
                    HStack {
                        Text("Colour")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { space.color },
                            set: { space.color = $0; onChanged() }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 28)
                    }

                    // Icon grid — compact 5-per-row
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5),
                        spacing: 4
                    ) {
                        ForEach(spaceIconOptions, id: \.self) { icon in
                            Button {
                                space.iconName = icon
                                onChanged()
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(space.iconName == icon ? space.color : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(space.iconName == icon
                                                  ? space.color.opacity(0.15)
                                                  : Color.primary.opacity(0.04))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(space.iconName == icon
                                                    ? space.color.opacity(0.4)
                                                    : Color.clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isEditing
                      ? space.color.opacity(0.07)
                      : Color(NSColor.controlBackgroundColor))
                .shadow(color: isEditing ? space.color.opacity(0.15) : Color.black.opacity(0.04),
                        radius: isEditing ? 8 : 3, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isEditing ? space.color.opacity(0.3) : Color.primary.opacity(0.07),
                        lineWidth: isEditing ? 1.5 : 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isEditing)
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
    }
}
