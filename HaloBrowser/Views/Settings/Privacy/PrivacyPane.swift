//
//  PrivacyPane.swift
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: PANE: PRIVACY
// ─────────────────────────────────────────────────────────────────────────────
//
// ✅ WIRED:   adBlockLevel — already on BrowserSettings, saves immediately.
// ✅ WIRED:   "Clear all website data" button — calls WKWebsiteDataStore directly.
//
// 🔧 TO WIRE: httpsUpgrade  (easiest one — 3 lines of code)
//   ① Add to BrowserSettings:  var httpsUpgrade: Bool = true
//   ② In HaloTab.wake(), after `let newPage = WebPage()`:
//       newPage.configuration.upgradeKnownHostsToHTTPS = model.settings.httpsUpgrade
//      (You'll need to pass model/settings into HaloTab, or read from a shared singleton.)
//   ③ Replace @State httpsUpgrade below with $model.settings.httpsUpgrade
//      and add .onChange { _, _ in model.saveState() }
//
// 🔧 TO WIRE: blockThirdPartyCookies
//   ① Add to BrowserSettings:  var blockThirdPartyCookies: Bool = true
//   ② In HaloTab.wake(), inject a WKContentRuleList that blocks Set-Cookie on
//      cross-origin responses. This is the correct approach (vs. nonPersistent
//      data store which blocks ALL cookies including first-party):
//
//       let rule = """
//       [{"trigger":{"url-filter":".*","load-type":["third-party"]},
//         "action":{"type":"block-cookies"}}]
//       """
//       if model.settings.blockThirdPartyCookies,
//          let list = try? await WKContentRuleListStore.default()
//              .compileContentRuleList(forIdentifier: "block-3p-cookies",
//                                     encodedContentRuleList: rule) {
//           newPage.configuration.userContentController.add(list)
//       }
//
// 🔧 TO WIRE: fingerprintProtection
//   ① Add to BrowserSettings:  var fingerprintProtection: Bool = false
//   ② In HaloTab.wake(), inject a WKUserScript before the page loads:
//
//       if model.settings.fingerprintProtection {
//           let script = """
//           // Randomise canvas fingerprint
//           const origToDataURL = HTMLCanvasElement.prototype.toDataURL;
//           HTMLCanvasElement.prototype.toDataURL = function(type) {
//               const ctx = this.getContext('2d');
//               if (ctx) {
//                   const imgData = ctx.getImageData(0,0,this.width,this.height);
//                   for (let i = 0; i < imgData.data.length; i += 4) {
//                       imgData.data[i]   ^= Math.floor(Math.random() * 3);
//                       imgData.data[i+1] ^= Math.floor(Math.random() * 3);
//                       imgData.data[i+2] ^= Math.floor(Math.random() * 3);
//                   }
//                   ctx.putImageData(imgData, 0, 0);
//               }
//               return origToDataURL.apply(this, arguments);
//           };
//           """
//           let userScript = WKUserScript(source: script,
//                                         injectionTime: .atDocumentStart,
//                                         forMainFrameOnly: false)
//           newPage.configuration.userContentController.addUserScript(userScript)
//       }
// ─────────────────────────────────────────────────────────────────────────────

struct PrivacyPane: View {
    @Bindable var model: BrowserViewModel

    // 🔧 Replace these @State vars with $model.settings.* once added (see notes above)
    @State private var blockThirdPartyCookies = true
    @State private var httpsUpgrade = true
    @State private var fingerprintProtection = false
    @State private var showClearConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader(pane: .privacy)

            SettingsSection(title: "Ad Blocking") {
                SettingsRow("Block level",
                            description: "Off · Balanced (EasyList + EasyPrivacy) · Strict (all 6 lists)") {
                    Picker("", selection: $model.settings.adBlockLevel) {
                        Text("Off").tag(0)
                        Text("Balanced").tag(1)
                        Text("Strict").tag(2)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                    .onChange(of: model.settings.adBlockLevel) { _, _ in model.saveState() }
                }
            }

            SettingsSection(title: "Tracking & Cookies") {
                // 🔧 Replace with $model.settings.blockThirdPartyCookies
                SettingsRow("Block third-party cookies",
                            description: "Uses a content rule — keeps first-party cookies intact") {
                    Toggle("", isOn: $blockThirdPartyCookies).labelsHidden()
                }
                RowDivider()
                // 🔧 Replace with $model.settings.httpsUpgrade — then set
                //    newPage.configuration.upgradeKnownHostsToHTTPS in HaloTab.wake()
                SettingsRow("Upgrade HTTP to HTTPS automatically") {
                    Toggle("", isOn: $httpsUpgrade).labelsHidden()
                }
                RowDivider()
                // 🔧 Replace with $model.settings.fingerprintProtection — inject WKUserScript
                SettingsRow("Fingerprint protection",
                            description: "Randomises canvas & audio fingerprints") {
                    Toggle("", isOn: $fingerprintProtection).labelsHidden()
                }
            }

            SettingsSection(title: "Data") {
                SettingsRow("Clear all website data",
                            description: "Removes cookies, caches, localStorage, and IndexedDB") {
                    // ✅ This is fully wired — calls WKWebsiteDataStore directly
                    Button("Clear…") { showClearConfirm = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                        .confirmationDialog("Clear all website data?",
                                            isPresented: $showClearConfirm,
                                            titleVisibility: .visible) {
                            Button("Clear Everything", role: .destructive) {
                                WKWebsiteDataStore.default().removeData(
                                    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                                    modifiedSince: .distantPast) { }
                            }
                        } message: {
                            Text("This cannot be undone.")
                        }
                }
            }
        }
    }
}
