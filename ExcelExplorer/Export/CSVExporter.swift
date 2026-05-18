//
//  CSVExporter.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  Adapted from SecurityViewer's CSV export patterns
//

import Foundation

class CSVExporter {
    static func export(sheet: SheetData, to url: URL) async throws {
        var csv = ""

        // Add headers
        let headers = sheet.cells[0].map { $0.displayValue }
        csv += headers.map { escapeCSV($0) }.joined(separator: ",") + "\n"

        // Add data rows
        for row in 1..<sheet.rowCount {
            let rowData = sheet.cells[row].map { $0.displayValue }
            csv += rowData.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        }

        // Write to file atomically
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    static func exportAllSheets(workbook: WorkbookData, to url: URL) async throws {
        // For multiple sheets, we'll create a CSV file for each sheet
        // or combine them with sheet name headers

        // For now, export the first sheet only
        if let firstSheet = workbook.sheets.first {
            try await export(sheet: firstSheet, to: url)
        } else {
            throw ExportError.noData
        }
    }

    // MARK: - CSV Escaping (from SecurityViewer pattern)
    private static func escapeCSV(_ field: String) -> String {
        // If field contains comma, quote, or newline, wrap in quotes and escape internal quotes
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

// MARK: - Export Errors
enum ExportError: Error {
    case noData
    case fileWriteError
    case invalidFormat(String)
    case fileSystemError(String)

    var localizedDescription: String {
        switch self {
        case .noData:
            return "No data to export"
        case .fileWriteError:
            return "Failed to write file"
        case .invalidFormat(let message):
            return "Invalid export format: \(message)"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        }
    }
}
