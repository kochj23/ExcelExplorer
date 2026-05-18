//
//  ExcelDataManagerTests.swift
//  ExcelExplorerTests
//
//  Unit tests for ExcelDataManager: value parsing, formula engine, sheet ops
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import ExcelExplorer

@MainActor
final class ExcelDataManagerTests: XCTestCase {

    var manager: ExcelDataManager!

    override func setUp() {
        super.setUp()
        manager = ExcelDataManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Value Parsing

    func testParseCellValueEmpty() {
        setupSheetWithData()
        manager.updateCell(row: 5, column: 0, value: "")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .empty = cell?.value {
            // Correct
        } else {
            XCTFail("Empty string should parse to .empty")
        }
    }

    func testParseCellValueNumber() {
        setupSheetWithData()
        manager.updateCell(row: 5, column: 0, value: "42")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .number(let num) = cell?.value {
            XCTAssertEqual(num, 42)
        } else {
            XCTFail("'42' should parse to .number")
        }
    }

    func testParseCellValueDecimalNumber() {
        setupSheetWithData()
        manager.updateCell(row: 5, column: 0, value: "3.14159")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .number(let num) = cell?.value {
            XCTAssertEqual(num, 3.14159, accuracy: 0.0001)
        } else {
            XCTFail("'3.14159' should parse to .number")
        }
    }

    func testParseCellValueBooleanTrue() {
        setupSheetWithData()
        manager.updateCell(row: 5, column: 0, value: "TRUE")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .bool(let val) = cell?.value {
            XCTAssertTrue(val)
        } else {
            XCTFail("'TRUE' should parse to .bool(true)")
        }
    }

    func testParseCellValueBooleanFalse() {
        setupSheetWithData()
        manager.updateCell(row: 5, column: 0, value: "false")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .bool(let val) = cell?.value {
            XCTAssertFalse(val)
        } else {
            XCTFail("'false' should parse to .bool(false)")
        }
    }

    func testParseCellValueBooleanCaseInsensitive() {
        setupSheetWithData()
        manager.updateCell(row: 5, column: 0, value: "True")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .bool(let val) = cell?.value {
            XCTAssertTrue(val)
        } else {
            XCTFail("'True' should parse to .bool(true)")
        }
    }

    func testParseCellValueString() {
        setupSheetWithData()
        manager.updateCell(row: 5, column: 0, value: "Hello World")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .string(let str) = cell?.value {
            XCTAssertEqual(str, "Hello World")
        } else {
            XCTFail("'Hello World' should parse to .string")
        }
    }

    func testParseCellValueDateYMD() {
        setupSheetWithData()
        manager.updateCell(row: 5, column: 0, value: "2026-01-15")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .date = cell?.value {
            // Correct: parsed as date
        } else {
            XCTFail("'2026-01-15' should parse to .date")
        }
    }

    func testParseCellValueDateMDY() {
        setupSheetWithData()
        manager.updateCell(row: 5, column: 0, value: "01/15/2026")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .date = cell?.value {
            // Correct: parsed as date
        } else {
            XCTFail("'01/15/2026' should parse to .date")
        }
    }

    // MARK: - Formula Evaluation

    func testFormulaSUM() {
        setupSheetWithData()
        // Set numbers in A1:A5
        for i in 1...5 {
            manager.currentSheet?.setCell(row: i, column: 0, value: .number(Double(i * 10)))
        }

        manager.updateCell(row: 6, column: 0, value: "=SUM(A2:A6)")

        let cell = manager.currentSheet?.getCell(row: 6, column: 0)
        if case .formula(let formula, let result) = cell?.value {
            XCTAssertEqual(formula, "=SUM(A2:A6)")
            if case .number(let sum) = result {
                XCTAssertEqual(sum, 150)
            } else {
                XCTFail("SUM result should be .number")
            }
        } else {
            XCTFail("'=SUM(A2:A6)' should parse to .formula")
        }
    }

    func testFormulaAVERAGE() {
        setupSheetWithData()
        for i in 1...4 {
            manager.currentSheet?.setCell(row: i, column: 0, value: .number(Double(i * 10)))
        }

        manager.updateCell(row: 5, column: 0, value: "=AVERAGE(A2:A5)")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .formula(_, let result) = cell?.value {
            if case .number(let avg) = result {
                XCTAssertEqual(avg, 25, accuracy: 0.01)
            } else {
                XCTFail("AVERAGE result should be .number")
            }
        } else {
            XCTFail("'=AVERAGE(A2:A5)' should parse to .formula")
        }
    }

    func testFormulaCOUNT() {
        setupSheetWithData()
        for i in 1...3 {
            manager.currentSheet?.setCell(row: i, column: 0, value: .number(Double(i)))
        }

        manager.updateCell(row: 4, column: 0, value: "=COUNT(A2:A4)")

        let cell = manager.currentSheet?.getCell(row: 4, column: 0)
        if case .formula(_, let result) = cell?.value {
            if case .number(let count) = result {
                XCTAssertEqual(count, 3)
            } else {
                XCTFail("COUNT result should be .number")
            }
        } else {
            XCTFail("'=COUNT(A2:A4)' should parse to .formula")
        }
    }

    func testFormulaMIN() {
        setupSheetWithData()
        manager.currentSheet?.setCell(row: 1, column: 0, value: .number(30))
        manager.currentSheet?.setCell(row: 2, column: 0, value: .number(10))
        manager.currentSheet?.setCell(row: 3, column: 0, value: .number(50))

        manager.updateCell(row: 4, column: 0, value: "=MIN(A2:A4)")

        let cell = manager.currentSheet?.getCell(row: 4, column: 0)
        if case .formula(_, let result) = cell?.value {
            if case .number(let min) = result {
                XCTAssertEqual(min, 10)
            } else {
                XCTFail("MIN result should be .number")
            }
        } else {
            XCTFail("'=MIN(A2:A4)' should parse to .formula")
        }
    }

    func testFormulaMAX() {
        setupSheetWithData()
        manager.currentSheet?.setCell(row: 1, column: 0, value: .number(30))
        manager.currentSheet?.setCell(row: 2, column: 0, value: .number(10))
        manager.currentSheet?.setCell(row: 3, column: 0, value: .number(50))

        manager.updateCell(row: 4, column: 0, value: "=MAX(A2:A4)")

        let cell = manager.currentSheet?.getCell(row: 4, column: 0)
        if case .formula(_, let result) = cell?.value {
            if case .number(let max) = result {
                XCTAssertEqual(max, 50)
            } else {
                XCTFail("MAX result should be .number")
            }
        } else {
            XCTFail("'=MAX(A2:A4)' should parse to .formula")
        }
    }

    func testFormulaUnknownReturnsError() {
        setupSheetWithData()
        manager.updateCell(row: 5, column: 0, value: "=VLOOKUP(A1,B:C,2)")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .formula(_, let result) = cell?.value {
            if case .string(let errorStr) = result {
                XCTAssertEqual(errorStr, "#ERROR")
            } else {
                XCTFail("Unknown formula should return #ERROR string")
            }
        } else {
            XCTFail("'=VLOOKUP(...)' should still parse as .formula")
        }
    }

    func testFormulaSUMEmptyRange() {
        setupSheetWithData()
        // All cells in range are empty
        manager.updateCell(row: 5, column: 0, value: "=SUM(B2:B4)")

        let cell = manager.currentSheet?.getCell(row: 5, column: 0)
        if case .formula(_, let result) = cell?.value {
            if case .number(let sum) = result {
                XCTAssertEqual(sum, 0)
            } else {
                XCTFail("SUM of empty range should be 0")
            }
        } else {
            XCTFail("Should parse as formula")
        }
    }

    // MARK: - Dirty Flag

    func testUpdateCellSetsDirtyFlag() {
        setupSheetWithData()
        XCTAssertFalse(manager.isDirty)

        manager.updateCell(row: 0, column: 0, value: "Changed")
        XCTAssertTrue(manager.isDirty)
    }

    // MARK: - Sheet Selection

    func testSelectSheetByIndex() {
        let sheet1 = SheetData(name: "Sheet1", rows: 5, columns: 3)
        let sheet2 = SheetData(name: "Sheet2", rows: 5, columns: 3)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet1, sheet2])
        manager.workbook = workbook
        manager.currentSheet = sheet1

        manager.selectSheet(at: 1)
        XCTAssertEqual(manager.currentSheet?.name, "Sheet2")
        XCTAssertEqual(manager.currentSheetIndex, 1)
    }

    func testSelectSheetByName() {
        let sheet1 = SheetData(name: "Revenue", rows: 5, columns: 3)
        let sheet2 = SheetData(name: "Expenses", rows: 5, columns: 3)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet1, sheet2])
        manager.workbook = workbook
        manager.currentSheet = sheet1

        manager.selectSheet(named: "Expenses")
        XCTAssertEqual(manager.currentSheet?.name, "Expenses")
        XCTAssertEqual(manager.currentSheetIndex, 1)
    }

    func testSelectSheetByInvalidIndexDoesNothing() {
        let sheet = SheetData(name: "Sheet1", rows: 5, columns: 3)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet])
        manager.workbook = workbook
        manager.currentSheet = sheet
        manager.currentSheetIndex = 0

        manager.selectSheet(at: 5)
        XCTAssertEqual(manager.currentSheet?.name, "Sheet1")
        XCTAssertEqual(manager.currentSheetIndex, 0)
    }

    // MARK: - File Loading (CSV Integration)

    func testLoadCSVFile() async throws {
        // Create temp CSV for testing (avoids interrupted system call during app init)
        let csvContent = "Name,Age\nAlice,30\nBob,25\n"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_load_\(UUID().uuidString).csv")
        try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        await manager.loadFile(from: tempURL)

        XCTAssertNotNil(manager.workbook)
        XCTAssertNotNil(manager.currentSheet)
        XCTAssertFalse(manager.isDirty)
        XCTAssertNil(manager.error)
    }

    func testLoadUnsupportedFormatSetsError() async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.numbers")
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        await manager.loadFile(from: tempURL)

        XCTAssertNotNil(manager.error)
        if case .unsupportedFormat = manager.error {
            // Expected
        } else {
            XCTFail("Should be unsupportedFormat error")
        }
    }

    func testLoadNonexistentFileSetsError() async {
        let url = URL(fileURLWithPath: "/nonexistent/file.csv")
        await manager.loadFile(from: url)

        XCTAssertNotNil(manager.error)
    }

    // MARK: - ExcelError

    func testExcelErrorDescriptions() {
        XCTAssertEqual(ExcelError.fileNotFound.localizedDescription, "File not found")
        XCTAssertTrue(ExcelError.unsupportedFormat("test").localizedDescription.contains("test"))
        XCTAssertEqual(ExcelError.corruptFile.localizedDescription, "The file is corrupt or cannot be read")
        XCTAssertEqual(ExcelError.noFileOpen.localizedDescription, "No file is currently open")
        XCTAssertTrue(ExcelError.parseError("details").localizedDescription.contains("details"))
        XCTAssertTrue(ExcelError.unknown("oops").localizedDescription.contains("oops"))
    }

    // MARK: - Helpers

    private func setupSheetWithData() {
        let sheet = SheetData(name: "TestSheet", rows: 10, columns: 10)
        sheet.cells[0][0].value = .string("Header")
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet])
        manager.workbook = workbook
        manager.currentSheet = sheet
    }
}
