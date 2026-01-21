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
    static let saveFile = Notification.Name("saveFile")
    static let exportCSV = Notification.Name("exportCSV")
    static let exportPDF = Notification.Name("exportPDF")
    static let exportExcel = Notification.Name("exportExcel")

    // UI toggles
    static let toggleAIPanel = Notification.Name("toggleAIPanel")
    static let toggleChartsPanel = Notification.Name("toggleChartsPanel")

    // AI operations
    static let analyzeData = Notification.Name("analyzeData")
    static let generateChart = Notification.Name("generateChart")
    static let findPatterns = Notification.Name("findPatterns")
    static let predictValues = Notification.Name("predictValues")

    // Data updates
    static let sheetChanged = Notification.Name("sheetChanged")
    static let cellUpdated = Notification.Name("cellUpdated")
    static let workbookLoaded = Notification.Name("workbookLoaded")
}
