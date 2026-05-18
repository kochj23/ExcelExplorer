//
//  WidgetData.swift
//  ExcelExplorer Widget
//
//  Created by Jordan Koch on 2026-02-04.
//  Data models for widget extension
//

import Foundation
import WidgetKit

/// App Group identifier for sharing data between main app and widget
let appGroupIdentifier = "group.com.jkoch.excelexplorer"

// MARK: - Widget Data Models

/// Information about a recently opened file
struct RecentFile: Codable, Identifiable, Hashable {
    let id: UUID
    let filename: String
    let filePath: String
    let lastOpened: Date
    let rowCount: Int
    let columnCount: Int
    let sheetCount: Int
    let fileSize: Int64

    init(id: UUID = UUID(), filename: String, filePath: String, lastOpened: Date = Date(),
         rowCount: Int, columnCount: Int, sheetCount: Int, fileSize: Int64 = 0) {
        self.id = id
        self.filename = filename
        self.filePath = filePath
        self.lastOpened = lastOpened
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.sheetCount = sheetCount
        self.fileSize = fileSize
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastOpened, relativeTo: Date())
    }

    var statsDescription: String {
        return "\(rowCount.formatted()) rows x \(columnCount) cols"
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

/// AI analysis status for the current file
struct AIAnalysisStatus: Codable {
    let isAnalyzing: Bool
    let lastAnalysisDate: Date?
    let insightsCount: Int
    let analysisType: String?
    let summary: String?

    init(isAnalyzing: Bool = false, lastAnalysisDate: Date? = nil,
         insightsCount: Int = 0, analysisType: String? = nil, summary: String? = nil) {
        self.isAnalyzing = isAnalyzing
        self.lastAnalysisDate = lastAnalysisDate
        self.insightsCount = insightsCount
        self.analysisType = analysisType
        self.summary = summary
    }

    var statusText: String {
        if isAnalyzing {
            return "Analyzing..."
        } else if let date = lastAnalysisDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last: \(formatter.localizedString(for: date, relativeTo: Date()))"
        }
        return "Not analyzed"
    }
}

/// Current file statistics for the widget
struct CurrentFileStats: Codable {
    let filename: String?
    let rowCount: Int
    let columnCount: Int
    let sheetCount: Int
    let cellCount: Int
    let hasFormulas: Bool
    let hasCharts: Bool
    let lastModified: Date?

    init(filename: String? = nil, rowCount: Int = 0, columnCount: Int = 0,
         sheetCount: Int = 0, cellCount: Int = 0, hasFormulas: Bool = false,
         hasCharts: Bool = false, lastModified: Date? = nil) {
        self.filename = filename
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.sheetCount = sheetCount
        self.cellCount = cellCount
        self.hasFormulas = hasFormulas
        self.hasCharts = hasCharts
        self.lastModified = lastModified
    }

    var isFileOpen: Bool {
        filename != nil
    }

    var statsText: String {
        guard isFileOpen else { return "No file open" }
        return "\(rowCount.formatted()) x \(columnCount)"
    }
}

/// Complete widget data structure
struct ExcelExplorerWidgetData: Codable {
    let recentFiles: [RecentFile]
    let currentFileStats: CurrentFileStats
    let aiStatus: AIAnalysisStatus
    let lastUpdated: Date

    init(recentFiles: [RecentFile] = [],
         currentFileStats: CurrentFileStats = CurrentFileStats(),
         aiStatus: AIAnalysisStatus = AIAnalysisStatus(),
         lastUpdated: Date = Date()) {
        self.recentFiles = recentFiles
        self.currentFileStats = currentFileStats
        self.aiStatus = aiStatus
        self.lastUpdated = lastUpdated
    }

    /// Sample data for widget previews
    static var preview: ExcelExplorerWidgetData {
        let recentFiles = [
            RecentFile(filename: "Q4_Sales_Report.xlsx", filePath: "/Documents/Q4_Sales_Report.xlsx",
                      lastOpened: Date().addingTimeInterval(-3600), rowCount: 1250, columnCount: 12, sheetCount: 3, fileSize: 245000),
            RecentFile(filename: "Employee_Data.xlsx", filePath: "/Documents/Employee_Data.xlsx",
                      lastOpened: Date().addingTimeInterval(-86400), rowCount: 500, columnCount: 8, sheetCount: 2, fileSize: 125000),
            RecentFile(filename: "Budget_2026.xlsx", filePath: "/Documents/Budget_2026.xlsx",
                      lastOpened: Date().addingTimeInterval(-172800), rowCount: 200, columnCount: 15, sheetCount: 5, fileSize: 89000)
        ]

        let currentStats = CurrentFileStats(
            filename: "Q4_Sales_Report.xlsx",
            rowCount: 1250,
            columnCount: 12,
            sheetCount: 3,
            cellCount: 15000,
            hasFormulas: true,
            hasCharts: true,
            lastModified: Date().addingTimeInterval(-1800)
        )

        let aiStatus = AIAnalysisStatus(
            isAnalyzing: false,
            lastAnalysisDate: Date().addingTimeInterval(-3600),
            insightsCount: 5,
            analysisType: "Pattern Detection",
            summary: "Found 3 trends, 2 anomalies"
        )

        return ExcelExplorerWidgetData(
            recentFiles: recentFiles,
            currentFileStats: currentStats,
            aiStatus: aiStatus,
            lastUpdated: Date()
        )
    }

    /// Empty state data
    static var empty: ExcelExplorerWidgetData {
        ExcelExplorerWidgetData()
    }
}

// MARK: - Widget Timeline Entry

struct ExcelExplorerEntry: TimelineEntry {
    let date: Date
    let data: ExcelExplorerWidgetData

    init(date: Date = Date(), data: ExcelExplorerWidgetData = .empty) {
        self.date = date
        self.data = data
    }
}

// MARK: - Deep Link Actions

enum WidgetDeepLink {
    case openApp
    case openFile(path: String)
    case openRecent
    case startAnalysis

    var url: URL? {
        switch self {
        case .openApp:
            return URL(string: "excelexplorer://")
        case .openFile(let path):
            let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
            return URL(string: "excelexplorer://open?path=\(encoded)")
        case .openRecent:
            return URL(string: "excelexplorer://recent")
        case .startAnalysis:
            return URL(string: "excelexplorer://analyze")
        }
    }
}
