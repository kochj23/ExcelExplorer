//
//  SheetData.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import Foundation

class SheetData: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var cells: [[CellData]]
    @Published var charts: [ChartData] = []

    var rowCount: Int {
        cells.count
    }

    var columnCount: Int {
        cells.first?.count ?? 0
    }

    var headers: [String] {
        guard rowCount > 0 else { return [] }
        return cells[0].map { $0.displayValue }
    }

    init(name: String, rows: Int = 1000, columns: Int = 26) {
        self.name = name
        self.cells = []

        // Initialize empty cells
        for row in 0..<rows {
            var rowCells: [CellData] = []
            for col in 0..<columns {
                let reference = CellReference(column: col, row: row)
                rowCells.append(CellData(reference: reference))
            }
            cells.append(rowCells)
        }
    }

    init(name: String, cells: [[CellData]]) {
        self.name = name
        self.cells = cells
    }

    // MARK: - Cell Access
    func getCell(at reference: CellReference) -> CellData? {
        guard reference.row >= 0 && reference.row < rowCount,
              reference.column >= 0 && reference.column < columnCount else {
            return nil
        }
        return cells[reference.row][reference.column]
    }

    func getCell(row: Int, column: Int) -> CellData? {
        guard row >= 0 && row < rowCount,
              column >= 0 && column < columnCount else {
            return nil
        }
        return cells[row][column]
    }

    func setCell(at reference: CellReference, value: CellValue) {
        guard let cell = getCell(at: reference) else { return }
        cell.value = value
        NotificationCenter.default.post(name: .cellUpdated, object: reference)
    }

    func setCell(row: Int, column: Int, value: CellValue) {
        guard let cell = getCell(row: row, column: column) else { return }
        cell.value = value
        NotificationCenter.default.post(name: .cellUpdated, object: CellReference(column: column, row: row))
    }

    // MARK: - Row/Column Operations
    func insertRow(at index: Int) {
        var newRow: [CellData] = []
        for col in 0..<columnCount {
            let reference = CellReference(column: col, row: index)
            newRow.append(CellData(reference: reference))
        }
        cells.insert(newRow, at: index)

        // Update references for rows below
        for row in (index + 1)..<rowCount {
            for col in 0..<columnCount {
                cells[row][col].reference = CellReference(column: col, row: row)
            }
        }
    }

    func deleteRow(at index: Int) {
        guard index >= 0 && index < rowCount else { return }
        cells.remove(at: index)

        // Update references for rows below
        for row in index..<rowCount {
            for col in 0..<columnCount {
                cells[row][col].reference = CellReference(column: col, row: row)
            }
        }
    }

    func insertColumn(at index: Int) {
        for row in 0..<rowCount {
            let reference = CellReference(column: index, row: row)
            cells[row].insert(CellData(reference: reference), at: index)
        }

        // Update references for columns to the right
        for row in 0..<rowCount {
            for col in (index + 1)..<columnCount {
                cells[row][col].reference = CellReference(column: col, row: row)
            }
        }
    }

    func deleteColumn(at index: Int) {
        guard index >= 0 && index < columnCount else { return }
        for row in 0..<rowCount {
            cells[row].remove(at: index)
        }

        // Update references for columns to the right
        for row in 0..<rowCount {
            for col in index..<columnCount {
                cells[row][col].reference = CellReference(column: col, row: row)
            }
        }
    }

    // MARK: - Column Statistics
    func columnStats(_ columnIndex: Int) -> ColumnStatistics? {
        guard columnIndex >= 0 && columnIndex < columnCount else { return nil }

        var numbers: [Double] = []
        var nonEmptyCount = 0

        for row in 1..<rowCount { // Skip header row
            let cell = cells[row][columnIndex]
            if case .number(let num) = cell.value {
                numbers.append(num)
            }
            if case .empty = cell.value {
                // Skip
            } else {
                nonEmptyCount += 1
            }
        }

        return ColumnStatistics(
            count: nonEmptyCount,
            numbers: numbers
        )
    }
}

// MARK: - Column Statistics
struct ColumnStatistics {
    let count: Int
    let numbers: [Double]

    var sum: Double {
        numbers.reduce(0, +)
    }

    var average: Double {
        guard !numbers.isEmpty else { return 0 }
        return sum / Double(numbers.count)
    }

    var min: Double {
        numbers.min() ?? 0
    }

    var max: Double {
        numbers.max() ?? 0
    }

    var summary: String {
        guard !numbers.isEmpty else {
            return "Count: \(count)"
        }
        return "Count: \(count), Avg: \(String(format: "%.2f", average)), Min: \(String(format: "%.2f", min)), Max: \(String(format: "%.2f", max))"
    }
}

// MARK: - Chart Data
struct ChartData: Identifiable {
    let id = UUID()
    let title: String
    let type: ChartType
    let imageData: Data?

    enum ChartType: String {
        case bar
        case line
        case pie
        case scatter
        case area
    }
}
