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

            CommandMenu("Edit") {
                Button("Find in Sheet...") {
                    NotificationCenter.default.post(name: .showFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    NotificationCenter.default.post(name: .findNext, object: nil)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    NotificationCenter.default.post(name: .findPrevious, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Divider()

                Button("Select All") {
                    NotificationCenter.default.post(name: .selectAll, object: nil)
                }
                .keyboardShortcut("a", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Zoom") {
                    NotificationCenter.default.post(name: .resetZoom, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("Toggle AI Panel") {
                    NotificationCenter.default.post(name: .toggleAIPanel, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Toggle Charts Panel") {
                    NotificationCenter.default.post(name: .toggleChartsPanel, object: nil)
                }
            }

            CommandMenu("AI") {
                Button("🧠 Explain This Spreadsheet") {
                    NotificationCenter.default.post(name: .explainSpreadsheet, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("💎 Find Insights") {
                    NotificationCenter.default.post(name: .findInsights, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("📊 Generate Report") {
                    NotificationCenter.default.post(name: .generateReport, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button("🧹 Clean My Data") {
                    NotificationCenter.default.post(name: .cleanData, object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("📝 Natural Language Formula...") {
                    NotificationCenter.default.post(name: .naturalLanguageFormula, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("Advanced AI Features...") {
                    NotificationCenter.default.post(name: .showAdvancedAI, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Divider()

                Button("Analyze Data") {
                    NotificationCenter.default.post(name: .analyzeData, object: nil)
                }

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
