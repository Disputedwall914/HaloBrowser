//
//  AddSpaceSheet.swift
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

// MARK: - Add Space Sheet

/// Full-screen sheet with a large, satisfying space builder.
/// Opens from the "New Space" button in SpacesPane.
struct AddSpaceSheet: View {
    @Bindable var model: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedIcon: String = "sparkles"
    @State private var selectedColor: Color = BrowserViewModel.randomSpaceColor()

    // Haptic-style animated state for the preview badge
    @State private var badgeBounce: Bool = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canAdd: Bool { !trimmedName.isEmpty }

    var body: some View {
        VStack(spacing: 0) {

            // ── Title bar ────────────────────────────────────────────────
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Text("New Space")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button("Add") {
                    guard canAdd else { return }
                    model.addSpace(name: trimmedName, iconName: selectedIcon, color: selectedColor)
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(canAdd ? .accentColor : .secondary)
                .disabled(!canAdd)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(spacing: 28) {

                    // ── Big animated preview ─────────────────────────────
                    VStack(spacing: 12) {
                        ZStack {
                            // Soft glow behind the badge
                            Circle()
                                .fill(selectedColor.opacity(0.18))
                                .frame(width: 90, height: 90)
                                .blur(radius: 12)

                            RoundedRectangle(cornerRadius: 24)
                                .fill(selectedColor.gradient)
                                .frame(width: 80, height: 80)
                                .shadow(color: selectedColor.opacity(0.4), radius: 12, x: 0, y: 6)
                                .scaleEffect(badgeBounce ? 1.08 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: badgeBounce)

                            Image(systemName: selectedIcon)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.white)
                                .scaleEffect(badgeBounce ? 1.08 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: badgeBounce)
                        }
                        .onTapGesture {
                            // Tap the preview to trigger bounce animation
                            badgeBounce = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { badgeBounce = false }
                        }

                        Text(trimmedName.isEmpty ? "Space Name" : trimmedName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(trimmedName.isEmpty ? .secondary : .primary)
                            .animation(.easeInOut(duration: 0.15), value: trimmedName)
                    }
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity)

                    // ── Name ─────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Name")
                        TextField("e.g. Work, Personal, Research…", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                            // Bounce the preview whenever name changes
                            .onChange(of: name) { _, _ in
                                badgeBounce = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { badgeBounce = false }
                            }
                    }

                    // ── Colour ───────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Colour")

                        // Quick colour swatches
                        HStack(spacing: 8) {
                            ForEach(BrowserViewModel.availableColors, id: \.self) { color in
                                Button {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                        selectedColor = color
                                    }
                                    badgeBounce = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { badgeBounce = false }
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Circle().stroke(Color.white, lineWidth: 2.5)
                                                .opacity(selectedColor == color ? 1 : 0)
                                        )
                                        .overlay(
                                            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                        )
                                        .scaleEffect(selectedColor == color ? 1.15 : 1.0)
                                        .animation(.spring(response: 0.2, dampingFraction: 0.6),
                                                   value: selectedColor == color)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            // Full colour picker for custom colours
                            ColorPicker("Custom", selection: $selectedColor, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 26, height: 26)
                        }
                    }

                    // ── Icon ─────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Icon")

                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(spaceIconOptions, id: \.self) { icon in
                                Button {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                        selectedIcon = icon
                                    }
                                    badgeBounce = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { badgeBounce = false }
                                } label: {
                                    VStack(spacing: 5) {
                                        Image(systemName: icon)
                                            .font(.system(size: 18))
                                            .foregroundColor(selectedIcon == icon ? selectedColor : .primary.opacity(0.6))
                                            .frame(height: 22)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIcon == icon
                                                  ? selectedColor.opacity(0.12)
                                                  : Color(NSColor.controlBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedIcon == icon
                                                    ? selectedColor.opacity(0.4)
                                                    : Color.primary.opacity(0.06),
                                                    lineWidth: selectedIcon == icon ? 1.5 : 1)
                                    )
                                    .scaleEffect(selectedIcon == icon ? 1.04 : 1.0)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.6),
                                               value: selectedIcon == icon)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // ── Add button (also at bottom for ergonomics) ────────
                    Button {
                        guard canAdd else { return }
                        model.addSpace(name: trimmedName, iconName: selectedIcon, color: selectedColor)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15))
                            Text("Add Space")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(canAdd ? selectedColor.gradient : Color.secondary.opacity(0.2).gradient)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: canAdd ? selectedColor.opacity(0.35) : .clear,
                                radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAdd)
                    .animation(.easeInOut(duration: 0.2), value: canAdd)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 500, height: 620)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
