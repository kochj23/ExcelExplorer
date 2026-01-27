//
//  NotificationNames.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import Foundation

extension Notification.Name {
    // File operations
    static let openFile = Notification.Name("openFile")
    static let openSpecificFile = Notification.Name("openSpecificFile")
    static let saveFile = Notification.Name("saveFile")
    static let exportCSV = Notification.Name("exportCSV")
    static let exportPDF = Notification.Name("exportPDF")
    static let exportExcel = Notification.Name("exportExcel")

    // UI toggles
    static let toggleAIPanel = Notification.Name("toggleAIPanel")
    static let toggleChartsPanel = Notification.Name("toggleChartsPanel")

    // Edit operations - Quick Wins
    static let showFind = Notification.Name("showFind")
    static let findNext = Notification.Name("findNext")
    static let findPrevious = Notification.Name("findPrevious")
    static let selectAll = Notification.Name("selectAll")

    // View operations - Quick Wins
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let resetZoom = Notification.Name("resetZoom")

    // AI operations - Quick Wins
    static let naturalLanguageFormula = Notification.Name("naturalLanguageFormula")
    static let cleanData = Notification.Name("cleanData")

    // AI operations - Killer Features
    static let explainSpreadsheet = Notification.Name("explainSpreadsheet")
    static let findInsights = Notification.Name("findInsights")
    static let generateReport = Notification.Name("generateReport")
    static let enableVoiceCommands = Notification.Name("enableVoiceCommands")

    // Existing AI operations
    static let analyzeData = Notification.Name("analyzeData")
    static let generateChart = Notification.Name("generateChart")
    static let findPatterns = Notification.Name("findPatterns")
    static let predictValues = Notification.Name("predictValues")
    static let showAdvancedAI = Notification.Name("showAdvancedAI")

    // Data updates
    static let sheetChanged = Notification.Name("sheetChanged")
    static let cellUpdated = Notification.Name("cellUpdated")
    static let workbookLoaded = Notification.Name("workbookLoaded")
    static let cellSelected = Notification.Name("cellSelected")
}
