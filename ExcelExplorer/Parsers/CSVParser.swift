//
//  CSVParser.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  Adapted from SecurityViewer's CSVParser
//

import Foundation

class CSVParser {
    static func parseCSV(url: URL) async throws -> WorkbookData {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw ExcelError.parseError("CSV file is empty")
        }

        // Parse header row
        let headers = parseCSVLine(lines[0])

        // Create cells array
        var cellRows: [[CellData]] = []

        // Add header row
        var headerRow: [CellData] = []
        for (col, header) in headers.enumerated() {
            let reference = CellReference(column: col, row: 0)
            let cell = CellData(reference: reference, value: .string(header))
            cell.formatting.isBold = true
            headerRow.append(cell)
        }
        cellRows.append(headerRow)

        // Parse data rows
        for (rowIndex, line) in lines.dropFirst().enumerated() {
            let values = parseCSVLine(line)
            var row: [CellData] = []

            for (col, value) in values.enumerated() {
                let reference = CellReference(column: col, row: rowIndex + 1)
                let cellValue = parseCellValue(value)
                row.append(CellData(reference: reference, value: cellValue))
            }

            // Pad row if needed to match header count
            while row.count < headers.count {
                let reference = CellReference(column: row.count, row: rowIndex + 1)
                row.append(CellData(reference: reference, value: .empty))
            }

            cellRows.append(row)
        }

        // Create sheet
        let sheet = SheetData(name: "Sheet1", cells: cellRows)

        // Create workbook
        let filename = url.lastPathComponent
        let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        let workbook = WorkbookData(
            filename: filename,
            sheets: [sheet],
            metadata: FileMetadata(fileSize: fileSize.map { Int64($0) })
        )
        workbook.fileURL = url

        return workbook
    }

    // MARK: - CSV Line Parsing
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if char == "\"" {
                // Check if it's an escaped quote
                let nextIndex = line.index(after: i)
                if inQuotes && nextIndex < line.endIndex && line[nextIndex] == "\"" {
                    currentField.append("\"")
                    i = nextIndex
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }

            i = line.index(after: i)
        }

        // Add last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))

        return fields
    }

    private static func parseCellValue(_ value: String) -> CellValue {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return .empty
        }

        // Try number
        if let number = Double(trimmed) {
            return .number(number)
        }

        // Try boolean
        if trimmed.uppercased() == "TRUE" {
            return .bool(true)
        }
        if trimmed.uppercased() == "FALSE" {
            return .bool(false)
        }

        // Try date
        if let date = parseDate(trimmed) {
            return .date(date)
        }

        // Default to string
        return .string(trimmed)
    }

    private static func parseDate(_ value: String) -> Date? {
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
}
