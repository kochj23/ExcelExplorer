//
//  ExcelDataManager.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import Foundation
import SwiftUI
import WidgetKit

@MainActor
class ExcelDataManager: ObservableObject {
    @Published var workbook: WorkbookData?
    @Published var currentSheet: SheetData?
    @Published var currentSheetIndex: Int = 0
    @Published var isDirty: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: ExcelError?

    private var fileURL: URL?

    // MARK: - File Operations
    func loadFile(from url: URL) async {
        isLoading = true
        error = nil

        do {
            // Determine file type and parse accordingly
            let fileExtension = url.pathExtension.lowercased()

            switch fileExtension {
            case "xlsx":
                workbook = try await ExcelParser.parseXLSX(url: url)
            case "xls":
                workbook = try await ExcelParser.parseXLS(url: url)
            case "csv":
                workbook = try await CSVParser.parseCSV(url: url)
            case "numbers":
                // For now, show error that Numbers is not yet supported
                throw ExcelError.unsupportedFormat("Numbers format not yet supported")
            default:
                throw ExcelError.unsupportedFormat("Unsupported file format: \(fileExtension)")
            }

            workbook?.fileURL = url
            fileURL = url

            // Set current sheet to first sheet
            if let firstSheet = workbook?.sheets.first {
                currentSheet = firstSheet
                currentSheetIndex = 0
            }

            isDirty = false

            NotificationCenter.default.post(name: .workbookLoaded, object: workbook)

            // Update widget data
            updateWidgetData()

        } catch {
            self.error = error as? ExcelError ?? .unknown(error.localizedDescription)
        }

        isLoading = false
    }

    func saveFile() async {
        guard let workbook = workbook, let url = fileURL else {
            error = .noFileOpen
            return
        }

        isLoading = true

        do {
            // Create temp file for atomic write
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(url.pathExtension)

            // Write based on format
            let fileExtension = url.pathExtension.lowercased()
            switch fileExtension {
            case "xlsx":
                try await ExcelWriter.writeXLSX(workbook: workbook, to: tempURL)
            case "csv":
                if let sheet = currentSheet {
                    try await CSVExporter.export(sheet: sheet, to: tempURL)
                }
            default:
                throw ExcelError.unsupportedFormat("Cannot save to format: \(fileExtension)")
            }

            // Move to final location
            try FileManager.default.replaceItemAt(url, withItemAt: tempURL)

            isDirty = false

        } catch {
            self.error = error as? ExcelError ?? .unknown(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Sheet Operations
    func selectSheet(at index: Int) {
        guard let sheet = workbook?.getSheet(at: index) else { return }
        currentSheet = sheet
        currentSheetIndex = index
        NotificationCenter.default.post(name: .sheetChanged, object: index)
    }

    func selectSheet(named name: String) {
        guard let sheet = workbook?.getSheet(named: name),
              let index = workbook?.sheets.firstIndex(where: { $0.name == name }) else { return }
        currentSheet = sheet
        currentSheetIndex = index
        NotificationCenter.default.post(name: .sheetChanged, object: index)
    }

    // MARK: - Cell Operations
    func updateCell(at reference: CellReference, value: String) {
        guard let sheet = currentSheet else { return }

        // Parse value
        let cellValue = parseCellValue(value)

        // Update cell
        sheet.setCell(at: reference, value: cellValue)

        // Mark as dirty
        isDirty = true

        // If it's a formula, recalculate
        if value.starts(with: "=") {
            recalculateFormulas(in: sheet)
        }
    }

    func updateCell(row: Int, column: Int, value: String) {
        let reference = CellReference(column: column, row: row)
        updateCell(at: reference, value: value)
    }

    // MARK: - Value Parsing
    private func parseCellValue(_ value: String) -> CellValue {
        // Empty
        if value.isEmpty {
            return .empty
        }

        // Formula
        if value.starts(with: "=") {
            let result = evaluateFormula(value)
            return .formula(value, result: result)
        }

        // Boolean
        if value.uppercased() == "TRUE" {
            return .bool(true)
        }
        if value.uppercased() == "FALSE" {
            return .bool(false)
        }

        // Number
        if let number = Double(value) {
            return .number(number)
        }

        // Date (try various formats)
        if let date = parseDate(value) {
            return .date(date)
        }

        // Default to string
        return .string(value)
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy/MM/dd"]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    // MARK: - Formula Evaluation (Basic)
    private func evaluateFormula(_ formula: String) -> CellValue {
        let formulaUpper = formula.uppercased()

        // Remove leading "="
        let formulaBody = String(formula.dropFirst())

        // SUM
        if formulaUpper.starts(with: "=SUM(") {
            return evaluateSUM(formulaBody)
        }

        // AVERAGE
        if formulaUpper.starts(with: "=AVERAGE(") || formulaUpper.starts(with: "=AVG(") {
            return evaluateAVERAGE(formulaBody)
        }

        // COUNT
        if formulaUpper.starts(with: "=COUNT(") {
            return evaluateCOUNT(formulaBody)
        }

        // MIN
        if formulaUpper.starts(with: "=MIN(") {
            return evaluateMIN(formulaBody)
        }

        // MAX
        if formulaUpper.starts(with: "=MAX(") {
            return evaluateMAX(formulaBody)
        }

        // Extract the function name (text before the opening parenthesis) for the error message
        let functionName: String
        if let parenIdx = formulaBody.firstIndex(of: "(") {
            functionName = String(formulaBody[formulaBody.startIndex..<parenIdx]).trimmingCharacters(in: .whitespaces).uppercased()
        } else {
            functionName = formulaBody.trimmingCharacters(in: .whitespaces).uppercased()
        }
        return .string("#NAME? \(functionName)")
    }

    private func evaluateSUM(_ formula: String) -> CellValue {
        let numbers = extractNumbersFromRange(formula)
        let sum = numbers.reduce(0, +)
        return .number(sum)
    }

    private func evaluateAVERAGE(_ formula: String) -> CellValue {
        let numbers = extractNumbersFromRange(formula)
        guard !numbers.isEmpty else { return .number(0) }
        let avg = numbers.reduce(0, +) / Double(numbers.count)
        return .number(avg)
    }

    private func evaluateCOUNT(_ formula: String) -> CellValue {
        let numbers = extractNumbersFromRange(formula)
        return .number(Double(numbers.count))
    }

    private func evaluateMIN(_ formula: String) -> CellValue {
        let numbers = extractNumbersFromRange(formula)
        guard let min = numbers.min() else { return .number(0) }
        return .number(min)
    }

    private func evaluateMAX(_ formula: String) -> CellValue {
        let numbers = extractNumbersFromRange(formula)
        guard let max = numbers.max() else { return .number(0) }
        return .number(max)
    }

    /// Maximum number of cells a single formula range may span.
    /// Prevents runaway iteration on absurdly large ranges (e.g., A1:ZZ999999).
    private static let maxRangeCells = 100_000

    private func extractNumbersFromRange(_ formula: String) -> [Double] {
        // Extract range like "A1:A10" from "SUM(A1:A10)"
        var numbers: [Double] = []

        // Remove function name and parentheses
        var rangeStr = formula
        if let openParen = rangeStr.firstIndex(of: "("), let closeParen = rangeStr.lastIndex(of: ")") {
            rangeStr = String(rangeStr[rangeStr.index(after: openParen)..<closeParen])
        }

        // Check if it's a range (A1:A10)
        if rangeStr.contains(":") {
            let parts = rangeStr.split(separator: ":")
            guard parts.count == 2,
                  let startRef = CellReference(excelNotation: String(parts[0])),
                  let endRef = CellReference(excelNotation: String(parts[1])),
                  let sheet = currentSheet else {
                return []
            }

            // Extract all cells in range (handle reversed ranges safely)
            let minRow = min(startRef.row, endRef.row)
            let maxRow = max(startRef.row, endRef.row)
            let minCol = min(startRef.column, endRef.column)
            let maxCol = max(startRef.column, endRef.column)

            // Guard against excessively large ranges that could freeze the UI
            let rangeCellCount = (maxRow - minRow + 1) * (maxCol - minCol + 1)
            guard rangeCellCount <= Self.maxRangeCells else {
                NSLog("[ExcelDataManager] Range too large (%d cells, max %d) — returning empty", rangeCellCount, Self.maxRangeCells)
                return []
            }

            for row in minRow...maxRow {
                for col in minCol...maxCol {
                    if let cell = sheet.getCell(row: row, column: col),
                       case .number(let num) = cell.value {
                        numbers.append(num)
                    }
                }
            }
        } else {
            // Single cell reference
            if let ref = CellReference(excelNotation: rangeStr),
               let cell = currentSheet?.getCell(at: ref),
               case .number(let num) = cell.value {
                numbers.append(num)
            }
        }

        return numbers
    }

    private func recalculateFormulas(in sheet: SheetData) {
        // Only recalculate cells that actually contain formulas — skip plain data
        // cells entirely. The inner `case .formula` guard is checked first, so
        // non-formula cells cost only a pattern-match (no evaluation work).
        for row in sheet.cells {
            for cell in row {
                guard case .formula(let formula, _) = cell.value else { continue }
                let result = evaluateFormula(formula)
                cell.value = .formula(formula, result: result)
            }
        }
    }

    // MARK: - Widget Integration

    /// App Group identifier for widget data sharing
    private let appGroupIdentifier = "group.com.jkoch.excelexplorer"

    /// Update widget with current file data
    func updateWidgetData() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        // Build recent file entry
        if let workbook = workbook, let url = fileURL {
            var recentFiles = loadRecentFiles(from: defaults)

            // Get file size
            var fileSize: Int64 = 0
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                fileSize = size
            }

            // Create recent file entry
            let recentFile: [String: Any] = [
                "id": UUID().uuidString,
                "filename": workbook.filename,
                "filePath": url.path,
                "lastOpened": Date().timeIntervalSince1970,
                "rowCount": currentSheet?.rowCount ?? 0,
                "columnCount": currentSheet?.columnCount ?? 0,
                "sheetCount": workbook.sheets.count,
                "fileSize": fileSize
            ]

            // Remove existing entry for same path
            recentFiles.removeAll { ($0["filePath"] as? String) == url.path }

            // Add new entry at start
            recentFiles.insert(recentFile, at: 0)

            // Keep max 10 entries
            if recentFiles.count > 10 {
                recentFiles = Array(recentFiles.prefix(10))
            }

            // Save recent files
            defaults.set(recentFiles, forKey: "ExcelExplorerRecentFiles")

            // Save current file stats
            let currentStats: [String: Any] = [
                "filename": workbook.filename,
                "rowCount": currentSheet?.rowCount ?? 0,
                "columnCount": currentSheet?.columnCount ?? 0,
                "sheetCount": workbook.sheets.count,
                "cellCount": (currentSheet?.rowCount ?? 0) * (currentSheet?.columnCount ?? 0),
                "hasFormulas": hasFormulas(),
                "hasCharts": currentSheet?.charts.isEmpty == false,
                "lastModified": Date().timeIntervalSince1970
            ]
            defaults.set(currentStats, forKey: "ExcelExplorerCurrentFile")

            defaults.synchronize()

            // Reload widget timelines
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Load recent files from shared defaults
    private func loadRecentFiles(from defaults: UserDefaults) -> [[String: Any]] {
        return defaults.array(forKey: "ExcelExplorerRecentFiles") as? [[String: Any]] ?? []
    }

    /// Check if current sheet has formulas
    private func hasFormulas() -> Bool {
        guard let sheet = currentSheet else { return false }
        for row in 0..<min(sheet.rowCount, 100) {  // Check first 100 rows for performance
            for col in 0..<min(sheet.columnCount, 26) {
                if let cell = sheet.getCell(row: row, column: col),
                   case .formula = cell.value {
                    return true
                }
            }
        }
        return false
    }

    /// Clear widget data when file is closed
    func clearWidgetCurrentFile() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.removeObject(forKey: "ExcelExplorerCurrentFile")
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Update AI analysis status in widget
    func updateWidgetAIStatus(isAnalyzing: Bool, type: String? = nil, insightsCount: Int = 0, summary: String? = nil) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        let aiStatus: [String: Any] = [
            "isAnalyzing": isAnalyzing,
            "lastAnalysisDate": isAnalyzing ? 0 : Date().timeIntervalSince1970,
            "insightsCount": insightsCount,
            "analysisType": type ?? "",
            "summary": summary ?? ""
        ]
        defaults.set(aiStatus, forKey: "ExcelExplorerAIStatus")
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Excel Errors
enum ExcelError: Error {
    case fileNotFound
    case unsupportedFormat(String)
    case corruptFile
    case noFileOpen
    case parseError(String)
    case unknown(String)

    var localizedDescription: String {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        case .corruptFile:
            return "The file is corrupt or cannot be read"
        case .noFileOpen:
            return "No file is currently open"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}
