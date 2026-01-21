//
//  ExcelDataManager.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import Foundation
import SwiftUI

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

        // If we can't evaluate, return empty
        return .string("#ERROR")
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

            // Extract all cells in range
            for row in startRef.row...endRef.row {
                for col in startRef.column...endRef.column {
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
        // Recalculate all formulas in the sheet
        for row in 0..<sheet.rowCount {
            for col in 0..<sheet.columnCount {
                if let cell = sheet.getCell(row: row, column: col),
                   case .formula(let formula, _) = cell.value {
                    let result = evaluateFormula(formula)
                    cell.value = .formula(formula, result: result)
                }
            }
        }
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
