//
//  ExcelParser.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  Full XLSX parsing using CoreXLSX
//

import Foundation
import CoreXLSX

class ExcelParser {
    // MARK: - Parse XLSX
    static func parseXLSX(url: URL) async throws -> WorkbookData {
        // Open XLSX file using CoreXLSX
        guard let file = XLSXFile(filepath: url.path) else {
            throw ExcelError.corruptFile
        }

        // Verify workbook exists
        guard (try? file.parseWorkbooks().first) != nil else {
            throw ExcelError.parseError("Could not find workbook in XLSX file")
        }

        // Get worksheet paths
        let worksheetPaths = try file.parseWorksheetPaths()
        var sheets: [SheetData] = []

        // Parse each worksheet
        for path in worksheetPaths {
            let name = path.components(separatedBy: "/").last?.replacingOccurrences(of: ".xml", with: "") ?? "Sheet"
            let worksheet = try file.parseWorksheet(at: path)
            let sheetData = try parseWorksheet(worksheet: worksheet, name: name, file: file)
            sheets.append(sheetData)
        }

        // Create workbook
        let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        let workbook = WorkbookData(
            filename: url.lastPathComponent,
            sheets: sheets,
            metadata: FileMetadata(fileSize: fileSize.map { Int64($0) })
        )
        workbook.fileURL = url

        return workbook
    }

    // MARK: - Parse Worksheet
    private static func parseWorksheet(
        worksheet: Worksheet,
        name: String,
        file: XLSXFile
    ) throws -> SheetData {
        guard let sharedStrings = try? file.parseSharedStrings() else {
            throw ExcelError.parseError("Could not parse shared strings")
        }

        // Determine sheet dimensions
        let rows = worksheet.data?.rows ?? []
        var maxRow = 0
        var maxCol = 0

        for row in rows {
            let rowIndex = row.reference
            maxRow = max(maxRow, Int(rowIndex))

            for cell in row.cells {
                let col = cell.reference.column.value
                if let colNum = columnLetterToNumber(col) {
                    maxCol = max(maxCol, colNum)
                }
            }
        }

        // Create empty cells array
        let rowCount = max(maxRow + 1, 100)
        let columnCount = max(maxCol + 1, 26)

        var cellsArray: [[CellData]] = []
        for row in 0..<rowCount {
            var rowCells: [CellData] = []
            for col in 0..<columnCount {
                let reference = CellReference(column: col, row: row)
                rowCells.append(CellData(reference: reference))
            }
            cellsArray.append(rowCells)
        }

        // Fill in actual cell values
        for row in rows {
            let rowIndex = row.reference
            let rowIdx = Int(rowIndex) - 1

            for cell in row.cells {
                let col = cell.reference.column.value
                guard let colIdx = columnLetterToNumber(col) else { continue }

                guard rowIdx >= 0, rowIdx < rowCount, colIdx >= 0, colIdx < columnCount else { continue }

                // Parse cell value
                let cellValue = parseCellValue(cell: cell, sharedStrings: sharedStrings)
                cellsArray[rowIdx][colIdx].value = cellValue

                // Parse formatting if available
                if cell.styleIndex != nil {
                    // Basic formatting support
                    cellsArray[rowIdx][colIdx].formatting = CellFormatting()
                }
            }
        }

        return SheetData(name: name, cells: cellsArray)
    }

    // MARK: - Helper: Convert Column Letter to Number
    private static func columnLetterToNumber(_ column: String) -> Int? {
        var result = 0
        for char in column.uppercased() {
            guard let value = char.asciiValue, value >= 65, value <= 90 else {
                return nil
            }
            result = result * 26 + Int(value - 64)
        }
        return result - 1 // Convert to 0-indexed
    }

    // MARK: - Parse Cell Value
    private static func parseCellValue(cell: Cell, sharedStrings: SharedStrings) -> CellValue {
        // Handle formulas
        if let formula = cell.formula {
            let formulaString = "=\(formula.value ?? "")"
            // For now, we'll store the formula but won't calculate it
            return .formula(formulaString, result: .empty)
        }

        // Handle values
        guard let value = cell.value else {
            return .empty
        }

        // Determine cell type
        if let cellType = cell.type {
            switch cellType {
            case .sharedString:
                // Look up string in shared strings table
                if let stringIndex = Int(value), stringIndex < sharedStrings.items.count {
                    let sharedString = sharedStrings.items[stringIndex]
                    let text = sharedString.text ?? ""
                    return .string(text)
                }
                return .string(value)

            case .string:
                return .string(value)

            case .bool:
                return .bool(value == "1" || value.lowercased() == "true")

            case .date:
                // Excel dates are stored as numbers (days since 1900-01-01)
                if let dateNumber = Double(value) {
                    let date = excelDateToDate(dateNumber)
                    return .date(date)
                }
                return .string(value)

            case .error:
                return .string("#ERROR")

            @unknown default:
                // Handle any future cell types
                if let number = Double(value) {
                    return .number(number)
                }
                return .string(value)
            }
        }

        // No explicit type - try to infer
        if let number = Double(value) {
            return .number(number)
        } else if value.lowercased() == "true" || value.lowercased() == "false" {
            return .bool(value.lowercased() == "true")
        } else {
            return .string(value)
        }
    }

    // MARK: - Excel Date Conversion
    private static func excelDateToDate(_ excelDate: Double) -> Date {
        // Excel dates are stored as days since January 1, 1900
        // But Excel incorrectly treats 1900 as a leap year
        let baseDate = Date(timeIntervalSince1970: -2209161600) // 1900-01-01
        let adjustedDays = excelDate - 1 // Excel is 1-indexed
        return baseDate.addingTimeInterval(adjustedDays * 86400)
    }

    // MARK: - Parse XLS (Legacy Format)
    static func parseXLS(url: URL) async throws -> WorkbookData {
        // Legacy .xls format (Binary Excel format)
        // This is complex and would require a specialized library

        let errorMessage = """
        Legacy .xls file format detected.

        Please convert to .xlsx or .csv:
        1. Open in Excel or Numbers
        2. File → Save As
        3. Choose 'Excel Workbook (.xlsx)' or 'CSV'
        4. Open the converted file in Excel Explorer

        Note: .xls is a binary format that requires specialized parsing.
        """

        throw ExcelError.unsupportedFormat(errorMessage)
    }
}
