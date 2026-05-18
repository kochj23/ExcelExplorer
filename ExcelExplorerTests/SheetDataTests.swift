//
//  SheetDataTests.swift
//  ExcelExplorerTests
//
//  Unit tests for SheetData model: grid operations, row/column ops, stats
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import ExcelExplorer

final class SheetDataTests: XCTestCase {

    // MARK: - Initialization

    func testSheetDataInitWithDefaults() {
        let sheet = SheetData(name: "Sheet1")
        XCTAssertEqual(sheet.name, "Sheet1")
        XCTAssertEqual(sheet.rowCount, 1000)
        XCTAssertEqual(sheet.columnCount, 26)
    }

    func testSheetDataInitWithCustomSize() {
        let sheet = SheetData(name: "Small", rows: 5, columns: 3)
        XCTAssertEqual(sheet.rowCount, 5)
        XCTAssertEqual(sheet.columnCount, 3)
    }

    func testSheetDataInitWithCells() {
        let cells = createTestCells(rows: 3, cols: 2)
        let sheet = SheetData(name: "Test", cells: cells)
        XCTAssertEqual(sheet.rowCount, 3)
        XCTAssertEqual(sheet.columnCount, 2)
    }

    // MARK: - Cell Access

    func testGetCellAtReference() {
        let sheet = SheetData(name: "Test", rows: 5, columns: 5)
        sheet.cells[2][3].value = .string("Found")

        let ref = CellReference(column: 3, row: 2)
        let cell = sheet.getCell(at: ref)
        XCTAssertNotNil(cell)
        XCTAssertEqual(cell?.displayValue, "Found")
    }

    func testGetCellByRowColumn() {
        let sheet = SheetData(name: "Test", rows: 5, columns: 5)
        sheet.cells[1][2].value = .number(42)

        let cell = sheet.getCell(row: 1, column: 2)
        XCTAssertNotNil(cell)
        if case .number(let num) = cell?.value {
            XCTAssertEqual(num, 42)
        } else {
            XCTFail("Expected number value")
        }
    }

    func testGetCellOutOfBoundsReturnsNil() {
        let sheet = SheetData(name: "Test", rows: 5, columns: 5)
        XCTAssertNil(sheet.getCell(row: -1, column: 0))
        XCTAssertNil(sheet.getCell(row: 0, column: -1))
        XCTAssertNil(sheet.getCell(row: 5, column: 0))
        XCTAssertNil(sheet.getCell(row: 0, column: 5))
    }

    func testGetCellAtReferenceOutOfBoundsReturnsNil() {
        let sheet = SheetData(name: "Test", rows: 5, columns: 5)
        let ref = CellReference(column: 10, row: 10)
        XCTAssertNil(sheet.getCell(at: ref))
    }

    // MARK: - Cell Mutation

    func testSetCellAtReference() {
        let sheet = SheetData(name: "Test", rows: 5, columns: 5)
        let ref = CellReference(column: 1, row: 1)
        sheet.setCell(at: ref, value: .string("Updated"))

        XCTAssertEqual(sheet.getCell(at: ref)?.displayValue, "Updated")
    }

    func testSetCellByRowColumn() {
        let sheet = SheetData(name: "Test", rows: 5, columns: 5)
        sheet.setCell(row: 2, column: 3, value: .number(99))

        if case .number(let num) = sheet.getCell(row: 2, column: 3)?.value {
            XCTAssertEqual(num, 99)
        } else {
            XCTFail("Expected number value")
        }
    }

    func testSetCellOutOfBoundsDoesNotCrash() {
        let sheet = SheetData(name: "Test", rows: 5, columns: 5)
        let ref = CellReference(column: 100, row: 100)
        // Should not crash
        sheet.setCell(at: ref, value: .string("Nope"))
        XCTAssertNil(sheet.getCell(at: ref))
    }

    // MARK: - Headers

    func testHeadersFromFirstRow() {
        let sheet = SheetData(name: "Test", rows: 3, columns: 3)
        sheet.cells[0][0].value = .string("Name")
        sheet.cells[0][1].value = .string("Age")
        sheet.cells[0][2].value = .string("City")

        let headers = sheet.headers
        XCTAssertEqual(headers, ["Name", "Age", "City"])
    }

    func testHeadersEmptySheet() {
        let cells: [[CellData]] = []
        let sheet = SheetData(name: "Empty", cells: cells)
        XCTAssertTrue(sheet.headers.isEmpty)
    }

    // MARK: - Row Operations

    func testInsertRow() {
        let sheet = SheetData(name: "Test", rows: 3, columns: 2)
        sheet.cells[0][0].value = .string("Header")
        sheet.cells[1][0].value = .string("Row1")
        sheet.cells[2][0].value = .string("Row2")

        let initialRowCount = sheet.rowCount
        sheet.insertRow(at: 1)

        XCTAssertEqual(sheet.rowCount, initialRowCount + 1)
        XCTAssertEqual(sheet.cells[0][0].displayValue, "Header")
        // Inserted row should be empty
        XCTAssertEqual(sheet.cells[1][0].displayValue, "")
        // Original row 1 shifted down
        XCTAssertEqual(sheet.cells[2][0].displayValue, "Row1")
    }

    func testDeleteRow() {
        let sheet = SheetData(name: "Test", rows: 3, columns: 2)
        sheet.cells[0][0].value = .string("Header")
        sheet.cells[1][0].value = .string("Row1")
        sheet.cells[2][0].value = .string("Row2")

        let initialRowCount = sheet.rowCount
        sheet.deleteRow(at: 1)

        XCTAssertEqual(sheet.rowCount, initialRowCount - 1)
        XCTAssertEqual(sheet.cells[0][0].displayValue, "Header")
        XCTAssertEqual(sheet.cells[1][0].displayValue, "Row2")
    }

    func testDeleteRowOutOfBoundsDoesNotCrash() {
        let sheet = SheetData(name: "Test", rows: 3, columns: 2)
        sheet.deleteRow(at: -1)
        sheet.deleteRow(at: 100)
        XCTAssertEqual(sheet.rowCount, 3)
    }

    // MARK: - Column Operations

    func testInsertColumn() {
        let sheet = SheetData(name: "Test", rows: 2, columns: 2)
        sheet.cells[0][0].value = .string("A")
        sheet.cells[0][1].value = .string("B")

        let initialColumnCount = sheet.columnCount
        sheet.insertColumn(at: 1)

        XCTAssertEqual(sheet.columnCount, initialColumnCount + 1)
        XCTAssertEqual(sheet.cells[0][0].displayValue, "A")
        XCTAssertEqual(sheet.cells[0][1].displayValue, "")  // inserted
        XCTAssertEqual(sheet.cells[0][2].displayValue, "B")
    }

    func testDeleteColumn() {
        let sheet = SheetData(name: "Test", rows: 2, columns: 3)
        sheet.cells[0][0].value = .string("A")
        sheet.cells[0][1].value = .string("B")
        sheet.cells[0][2].value = .string("C")

        sheet.deleteColumn(at: 1)

        XCTAssertEqual(sheet.columnCount, 2)
        XCTAssertEqual(sheet.cells[0][0].displayValue, "A")
        XCTAssertEqual(sheet.cells[0][1].displayValue, "C")
    }

    func testDeleteColumnOutOfBoundsDoesNotCrash() {
        let sheet = SheetData(name: "Test", rows: 2, columns: 3)
        sheet.deleteColumn(at: -1)
        sheet.deleteColumn(at: 100)
        XCTAssertEqual(sheet.columnCount, 3)
    }

    // MARK: - Column Statistics

    func testColumnStatsWithNumbers() {
        let sheet = SheetData(name: "Test", rows: 6, columns: 1)
        sheet.cells[0][0].value = .string("Values")  // header
        sheet.cells[1][0].value = .number(10)
        sheet.cells[2][0].value = .number(20)
        sheet.cells[3][0].value = .number(30)
        sheet.cells[4][0].value = .number(40)
        sheet.cells[5][0].value = .number(50)

        let stats = sheet.columnStats(0)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats!.numbers.count, 5)
        XCTAssertEqual(stats!.sum, 150)
        XCTAssertEqual(stats!.average, 30)
        XCTAssertEqual(stats!.min, 10)
        XCTAssertEqual(stats!.max, 50)
    }

    func testColumnStatsWithMixedTypes() {
        let sheet = SheetData(name: "Test", rows: 4, columns: 1)
        sheet.cells[0][0].value = .string("Header")
        sheet.cells[1][0].value = .number(10)
        sheet.cells[2][0].value = .string("Not a number")
        sheet.cells[3][0].value = .number(20)

        let stats = sheet.columnStats(0)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats!.numbers.count, 2)
        XCTAssertEqual(stats!.count, 3) // 3 non-empty cells (excluding header)
    }

    func testColumnStatsOutOfBoundsReturnsNil() {
        let sheet = SheetData(name: "Test", rows: 2, columns: 2)
        XCTAssertNil(sheet.columnStats(-1))
        XCTAssertNil(sheet.columnStats(2))
    }

    func testColumnStatsEmptyColumn() {
        let sheet = SheetData(name: "Test", rows: 5, columns: 1)
        sheet.cells[0][0].value = .string("Header")
        // All other cells are empty

        let stats = sheet.columnStats(0)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats!.numbers.count, 0)
        XCTAssertEqual(stats!.count, 0)
        XCTAssertEqual(stats!.sum, 0)
        XCTAssertEqual(stats!.average, 0)
    }

    // MARK: - ColumnStatistics Summary

    func testColumnStatisticsSummaryWithNumbers() {
        let stats = ColumnStatistics(count: 5, numbers: [10, 20, 30, 40, 50])
        let summary = stats.summary
        XCTAssertTrue(summary.contains("Count: 5"))
        XCTAssertTrue(summary.contains("Avg: 30.00"))
        XCTAssertTrue(summary.contains("Min: 10.00"))
        XCTAssertTrue(summary.contains("Max: 50.00"))
    }

    func testColumnStatisticsSummaryEmpty() {
        let stats = ColumnStatistics(count: 3, numbers: [])
        XCTAssertEqual(stats.summary, "Count: 3")
    }

    // MARK: - Helpers

    private func createTestCells(rows: Int, cols: Int) -> [[CellData]] {
        var cells: [[CellData]] = []
        for row in 0..<rows {
            var rowCells: [CellData] = []
            for col in 0..<cols {
                let ref = CellReference(column: col, row: row)
                rowCells.append(CellData(reference: ref))
            }
            cells.append(rowCells)
        }
        return cells
    }
}
