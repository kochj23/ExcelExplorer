//
//  ExcelExplorerApp.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  AI-powered Excel/spreadsheet viewer and editor for macOS
//

import SwiftUI

@main
struct ExcelExplorerApp: App {
    @StateObject private var dataManager = ExcelDataManager()
    @StateObject private var aiManager = AIBackendManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(aiManager)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Excel File...") {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu("File") {
                Button("Save") {
                    NotificationCenter.default.post(name: .saveFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Divider()

                Button("Export to CSV...") {
                    NotificationCenter.default.post(name: .exportCSV, object: nil)
                }

                Button("Export to PDF...") {
                    NotificationCenter.default.post(name: .exportPDF, object: nil)
                }

                Button("Export to Excel...") {
                    NotificationCenter.default.post(name: .exportExcel, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Toggle AI Panel") {
                    NotificationCenter.default.post(name: .toggleAIPanel, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Toggle Charts Panel") {
                    NotificationCenter.default.post(name: .toggleChartsPanel, object: nil)
                }
            }

            CommandMenu("AI") {
                Button("Analyze Data") {
                    NotificationCenter.default.post(name: .analyzeData, object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Button("Generate Chart") {
                    NotificationCenter.default.post(name: .generateChart, object: nil)
                }

                Button("Find Patterns") {
                    NotificationCenter.default.post(name: .findPatterns, object: nil)
                }

                Button("Predict Values") {
                    NotificationCenter.default.post(name: .predictValues, object: nil)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(aiManager)
        }
    }
}
