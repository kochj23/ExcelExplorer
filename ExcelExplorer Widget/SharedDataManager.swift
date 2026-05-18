//
//  SharedDataManager.swift
//  ExcelExplorer Widget
//
//  Created by Jordan Koch on 2026-02-04.
//  Manages shared data between main app and widget via App Group
//

import Foundation
import WidgetKit

/// Manages reading and writing widget data via App Group container
final class SharedDataManager {

    /// Shared singleton instance
    static let shared = SharedDataManager()

    /// Key for storing widget data in UserDefaults
    private let widgetDataKey = "ExcelExplorerWidgetData"

    /// Key for storing recent files
    private let recentFilesKey = "ExcelExplorerRecentFiles"

    /// Maximum number of recent files to store
    private let maxRecentFiles = 10

    /// UserDefaults suite using App Group
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// File URL for shared container
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// JSON encoder with date formatting
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// JSON decoder with date formatting
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {}

    // MARK: - Read Operations

    /// Load widget data from shared container
    func loadWidgetData() -> ExcelExplorerWidgetData {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: widgetDataKey) else {
            return .empty
        }

        do {
            return try decoder.decode(ExcelExplorerWidgetData.self, from: data)
        } catch {
            print("SharedDataManager: Failed to decode widget data: \(error)")
            return .empty
        }
    }

    /// Load recent files from shared container
    func loadRecentFiles() -> [RecentFile] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: recentFilesKey) else {
            return []
        }

        do {
            return try decoder.decode([RecentFile].self, from: data)
        } catch {
            print("SharedDataManager: Failed to decode recent files: \(error)")
            return []
        }
    }

    // MARK: - Write Operations (Called from Main App)

    /// Save complete widget data to shared container
    func saveWidgetData(_ widgetData: ExcelExplorerWidgetData) {
        guard let defaults = sharedDefaults else {
            print("SharedDataManager: App Group not available")
            return
        }

        do {
            let data = try encoder.encode(widgetData)
            defaults.set(data, forKey: widgetDataKey)
            defaults.synchronize()

            // Trigger widget reload
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("SharedDataManager: Failed to encode widget data: \(error)")
        }
    }

    /// Add a file to recent files list
    func addRecentFile(_ file: RecentFile) {
        var recentFiles = loadRecentFiles()

        // Remove existing entry for same file path
        recentFiles.removeAll { $0.filePath == file.filePath }

        // Add new entry at beginning
        recentFiles.insert(file, at: 0)

        // Trim to max count
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }

        // Save
        saveRecentFiles(recentFiles)
    }

    /// Save recent files list
    func saveRecentFiles(_ files: [RecentFile]) {
        guard let defaults = sharedDefaults else { return }

        do {
            let data = try encoder.encode(files)
            defaults.set(data, forKey: recentFilesKey)
            defaults.synchronize()

            // Update widget data and reload
            var widgetData = loadWidgetData()
            widgetData = ExcelExplorerWidgetData(
                recentFiles: files,
                currentFileStats: widgetData.currentFileStats,
                aiStatus: widgetData.aiStatus,
                lastUpdated: Date()
            )
            saveWidgetData(widgetData)
        } catch {
            print("SharedDataManager: Failed to save recent files: \(error)")
        }
    }

    /// Update current file statistics
    func updateCurrentFileStats(_ stats: CurrentFileStats) {
        var widgetData = loadWidgetData()
        widgetData = ExcelExplorerWidgetData(
            recentFiles: widgetData.recentFiles,
            currentFileStats: stats,
            aiStatus: widgetData.aiStatus,
            lastUpdated: Date()
        )
        saveWidgetData(widgetData)
    }

    /// Update AI analysis status
    func updateAIStatus(_ status: AIAnalysisStatus) {
        var widgetData = loadWidgetData()
        widgetData = ExcelExplorerWidgetData(
            recentFiles: widgetData.recentFiles,
            currentFileStats: widgetData.currentFileStats,
            aiStatus: status,
            lastUpdated: Date()
        )
        saveWidgetData(widgetData)
    }

    /// Clear current file (when file is closed)
    func clearCurrentFile() {
        updateCurrentFileStats(CurrentFileStats())
        updateAIStatus(AIAnalysisStatus())
    }

    // MARK: - Utility

    /// Clear all widget data (for debugging/reset)
    func clearAllData() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: widgetDataKey)
        defaults.removeObject(forKey: recentFilesKey)
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Request widget timeline reload
    func reloadWidgetTimeline() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Main App Integration Extension

extension SharedDataManager {

    /// Called when a workbook is opened in the main app
    func workbookOpened(filename: String, filePath: String, rowCount: Int, columnCount: Int, sheetCount: Int, fileSize: Int64) {
        // Add to recent files
        let recentFile = RecentFile(
            filename: filename,
            filePath: filePath,
            lastOpened: Date(),
            rowCount: rowCount,
            columnCount: columnCount,
            sheetCount: sheetCount,
            fileSize: fileSize
        )
        addRecentFile(recentFile)

        // Update current file stats
        let stats = CurrentFileStats(
            filename: filename,
            rowCount: rowCount,
            columnCount: columnCount,
            sheetCount: sheetCount,
            cellCount: rowCount * columnCount,
            hasFormulas: false,  // Will be updated separately
            hasCharts: false,    // Will be updated separately
            lastModified: Date()
        )
        updateCurrentFileStats(stats)
    }

    /// Called when AI analysis starts
    func aiAnalysisStarted(type: String) {
        let status = AIAnalysisStatus(
            isAnalyzing: true,
            lastAnalysisDate: nil,
            insightsCount: 0,
            analysisType: type,
            summary: nil
        )
        updateAIStatus(status)
    }

    /// Called when AI analysis completes
    func aiAnalysisCompleted(type: String, insightsCount: Int, summary: String?) {
        let status = AIAnalysisStatus(
            isAnalyzing: false,
            lastAnalysisDate: Date(),
            insightsCount: insightsCount,
            analysisType: type,
            summary: summary
        )
        updateAIStatus(status)
    }

    /// Called when the workbook is closed
    func workbookClosed() {
        clearCurrentFile()
    }
}
