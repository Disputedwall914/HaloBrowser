//
//  SpacesPane.swift
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

// MARK: - SpacesPane
// ─────────────────────────────────────────────────────────────────────────────
// Features:
//   • Card grid layout — each space gets its own tile
//   • Drag to reorder — uses .onDrag / .onDrop with live animated reorder
//   • Tap a card to enter edit mode inline (name, icon, colour)
//   • "New Space" floats as a separate + button that opens an AddSpaceSheet
//   • Delete button appears on the card (disabled when only 1 space left)
// ─────────────────────────────────────────────────────────────────────────────

let spaceIconOptions: [String] = [
    "person", "person.2", "briefcase", "globe", "sparkles",
    "book.closed", "hammer", "heart", "bolt", "leaf",
    "gamecontroller", "music.note", "cart", "airplane", "house",
    "paintbrush", "camera", "flask", "theatermasks", "graduationcap",
    "dumbbell", "fork.knife", "car", "moon.stars", "sun.max"
]

// MARK: - Spaces Pane

struct SpacesPane: View {
    @Bindable var model: BrowserViewModel

    /// Which space card is currently open for editing
    @State private var editingSpaceId: UUID? = nil

    /// Drag-and-drop state
    @State private var draggingSpaceId: UUID? = nil

    /// Controls the Add Space sheet
    @State private var showAddSheet = false

    private let columns = [
        GridItem(.flexible(), alignment: .top),
        GridItem(.flexible(), alignment: .top),
        GridItem(.flexible(), alignment: .top)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header row ──────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    PaneHeader(pane: .spaces)
                        //.font(.system(size: 22, weight: .bold))
//                    Text("\(model.spaces.count) space\(model.spaces.count == 1 ? "" : "s")")
//                        .font(.system(size: 12))
//                        .foregroundColor(.secondary)
                }

                Spacer()

                // New Space button — opens the sheet
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("New Space")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.tint.opacity(0.12))
                    .foregroundStyle(.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(.tint.opacity(0.25), lineWidth: 1))
                    
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)

            // ── Space card grid ─────────────────────────────────────────
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(model.spaces) { space in
                    SpaceCard(
                        space: space,
                        isEditing: editingSpaceId == space.id,
                        isDragging: draggingSpaceId == space.id,
                        canDelete: model.spaces.count > 1,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                editingSpaceId = editingSpaceId == space.id ? nil : space.id
                            }
                        },
                        onDelete: { model.removeSpace(space) },
                        onChanged: { model.saveState() }
                    )
                    // Drag source — carries the space's UUID as a string
                    .onDrag {
                        draggingSpaceId = space.id
                        return NSItemProvider(object: space.id.uuidString as NSString)
                    }
                    // Drop target — reorder live as you drag over
                    .onDrop(of: [.text], delegate: SpaceDropDelegate(
                        model: model,
                        targetSpace: space,
                        draggingSpaceId: $draggingSpaceId
                    ))
                    // Dim the card that's being dragged
                    .opacity(draggingSpaceId == space.id ? 0.4 : 1)
                    .scaleEffect(draggingSpaceId == space.id ? 0.96 : 1)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8),
                               value: draggingSpaceId)
                }
            }

            // Subtle drag hint shown only when there are 2+ spaces
            if model.spaces.count > 1 {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 10))
                    Text("Drag cards to reorder spaces")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, 12)
            }
        }
        // ── Add Space sheet ─────────────────────────────────────────────
        .sheet(isPresented: $showAddSheet) {
            AddSpaceSheet(model: model)
        }
    }
}
