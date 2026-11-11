//
//  SettingsView.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import SwiftUI
import NovaAIKit

struct SettingsView: View {
    @AppStorage("defaultZoomLevel") private var defaultZoomLevel: Double = 100
    @AppStorage("autoSave") private var autoSave: Bool = true
    @AppStorage("anonymizeExports") private var anonymizeExports: Bool = false

    var body: some View {
        TabView {
            // AI (NovaAIKit): on/off, backend + model pickers, URLs, Keychain keys, test connection
            NovaAISettingsView(ai: AppAI.shared, footer: AppAI.settingsFooter)
                .tabItem {
                    Label("AI", systemImage: "brain.head.profile")
                }

            // General Settings
            GeneralSettingsTab(
                defaultZoomLevel: $defaultZoomLevel,
                autoSave: $autoSave,
                anonymizeExports: $anonymizeExports
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            // About Tab
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 620, height: 640)
    }
}

// MARK: - General Settings Tab
struct GeneralSettingsTab: View {
    @Binding var defaultZoomLevel: Double
    @Binding var autoSave: Bool
    @Binding var anonymizeExports: Bool

    var body: some View {
        Form {
            Section("Display") {
                HStack {
                    Text("Default Zoom: \(Int(defaultZoomLevel))%")
                    Slider(value: $defaultZoomLevel, in: 50...200, step: 10)
                }
            }

            Section("File Operations") {
                Toggle("Auto-save changes", isOn: $autoSave)
                    .help("Automatically save changes as you edit")
            }

            Section("Privacy") {
                Toggle("Anonymize data in exports", isOn: $anonymizeExports)
                    .help("Replace sensitive data with generic values when exporting")

                Text("When enabled, names, emails, and phone numbers will be replaced with generic values in PDF and CSV exports")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - About Tab
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tablecells")
                .font(.system(size: 80))
                .foregroundStyle(.cyan)

            Text("Excel Explorer")
                .font(.system(size: 32, weight: .bold))

            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("AI-Powered Spreadsheet Analysis")
                .font(.body)

            Divider()
                .padding(.horizontal, 50)

            VStack(alignment: .leading, spacing: 10) {
                Text("Created by Jordan Koch")
                Text("© 2026 All Rights Reserved")
                Text("Built with SwiftUI and CoreXLSX")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 20) {
                Link("GitHub", destination: URL(string: "https://github.com/kochj23/ExcelExplorer")!)
                    .buttonStyle(.bordered)

                Link("Report Issue", destination: URL(string: "https://github.com/kochj23/ExcelExplorer/issues")!)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
