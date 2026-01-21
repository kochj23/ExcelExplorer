//
//  ContentView.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: ExcelDataManager
    @State private var showAIPanel = true
    @State private var showChartsPanel = false
    @State private var showSettings = false

    var body: some View {
        HSplitView {
            // Main spreadsheet view
            VStack(spacing: 0) {
                if let workbook = dataManager.workbook {
                    // Formula bar
                    FormulaBar()
                        .frame(height: 40)

                    // Spreadsheet grid
                    SpreadsheetGridView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Sheet tabs at bottom
                    SheetTabBar()
                        .frame(height: 40)
                } else {
                    // Welcome screen
                    WelcomeView()
                }
            }
            .frame(minWidth: 600)

            // AI conversation panel (right sidebar)
            if showAIPanel {
                AIConversationView()
                    .frame(width: 400)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: openFile) {
                    Label("Open", systemImage: "folder.badge.plus")
                }

                Button(action: saveFile) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(dataManager.workbook == nil || !dataManager.isDirty)

                Divider()

                Button(action: { showAIPanel.toggle() }) {
                    Label("AI Chat", systemImage: "brain.head.profile")
                }

                Button(action: { showChartsPanel.toggle() }) {
                    Label("Charts", systemImage: "chart.bar")
                }

                Divider()

                Button(action: { showSettings.toggle() }) {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFile)) { _ in
            openFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
            saveFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleAIPanel)) { _ in
            showAIPanel.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleChartsPanel)) { _ in
            showChartsPanel.toggle()
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText, .spreadsheet]
        panel.allowsOtherFileTypes = true

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await dataManager.loadFile(from: url)
            }
        }
    }

    private func saveFile() {
        Task {
            await dataManager.saveFile()
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "tablecells")
                .font(.system(size: 80))
                .foregroundStyle(.cyan)

            Text("Excel Explorer")
                .font(.system(size: 42, weight: .bold))

            Text("AI-Powered Spreadsheet Analysis")
                .font(.title3)
                .foregroundColor(.secondary)

            VStack(spacing: 15) {
                FeatureRow(icon: "doc.badge.plus", title: "Open Excel Files", description: "Support for .xlsx, .xls, .csv, and more")
                FeatureRow(icon: "pencil", title: "Edit Anywhere", description: "Full editing capabilities with formulas")
                FeatureRow(icon: "brain.head.profile", title: "AI Analysis", description: "Ask questions about your data")
                FeatureRow(icon: "chart.bar.xaxis", title: "Generate Charts", description: "AI-powered visualizations")
                FeatureRow(icon: "square.and.arrow.up", title: "Export Options", description: "CSV, PDF, and Excel formats")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.1))
            )

            Button(action: {
                NotificationCenter.default.post(name: .openFile, object: nil)
            }) {
                Label("Open Excel File", systemImage: "folder.badge.plus")
                    .font(.title3)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(60)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.cyan)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}
