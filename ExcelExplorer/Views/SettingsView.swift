//
//  SettingsView.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var aiManager: AIBackendManager
    @AppStorage("defaultZoomLevel") private var defaultZoomLevel: Double = 100
    @AppStorage("autoSave") private var autoSave: Bool = true
    @AppStorage("anonymizeExports") private var anonymizeExports: Bool = false

    var body: some View {
        TabView {
            // AI Backend Settings
            AIBackendSettingsTab()
                .tabItem {
                    Label("AI Backend", systemImage: "brain.head.profile")
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
        .frame(width: 600, height: 500)
    }
}

// MARK: - AI Backend Settings Tab
struct AIBackendSettingsTab: View {
    @EnvironmentObject var aiManager: AIBackendManager
    @AppStorage("aiBackendURL") private var backendURL: String = "http://localhost:11434"
    @AppStorage("aiModel") private var model: String = "mistral"
    @AppStorage("aiTemperature") private var temperature: Double = 0.7
    @AppStorage("aiMaxTokens") private var maxTokens: Double = 2000

    var body: some View {
        Form {
            Section("AI Backend Configuration") {
                TextField("Backend URL", text: $backendURL)
                    .textFieldStyle(.roundedBorder)
                    .help("Default: http://localhost:11434 for Ollama")

                TextField("Model Name", text: $model)
                    .textFieldStyle(.roundedBorder)
                    .help("e.g., mistral, llama2, codellama")

                HStack {
                    Text("Temperature: \(temperature, specifier: "%.2f")")
                    Slider(value: $temperature, in: 0...2, step: 0.1)
                }

                HStack {
                    Text("Max Tokens: \(Int(maxTokens))")
                    Slider(value: $maxTokens, in: 100...8000, step: 100)
                }
            }

            Section("Supported Backends") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Ollama (http://localhost:11434)")
                    Text("• TinyLLM")
                    Text("• TinyChat")
                    Text("• OpenWebUI")
                    Text("• MLX")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Section {
                Button("Test AI Connection") {
                    Task {
                        await testAIConnection()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func testAIConnection() async {
        // Test the AI connection
        do {
            let response = try await aiManager.generate(
                prompt: "Hello, respond with 'OK' if you can hear me.",
                systemPrompt: "Respond briefly with just 'OK'.",
                temperature: 0.5,
                maxTokens: 50
            )
            print("✅ AI Connection successful: \(response)")
        } catch {
            print("❌ AI Connection failed: \(error)")
        }
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

            Text("Version 1.0.0")
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
