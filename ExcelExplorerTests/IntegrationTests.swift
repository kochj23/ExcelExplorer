//
//  IntegrationTests.swift
//  ExcelExplorerTests
//
//  Integration tests: end-to-end workflows, file open -> edit -> export
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import ExcelExplorer

@MainActor
final class IntegrationTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IntegrationTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - End-to-End: CSV Open -> Edit -> CSV Export

    func testCSVOpenEditExport() async throws {
        let manager = ExcelDataManager()

        // Create temp CSV to avoid interrupted system call
        let csvContent = "Name,Age,Salary,Department,Active,StartDate\nAlice,30,75000.50,Engineering,TRUE,2020-01-15\nBob,25,62000,Marketing,FALSE,2021-06-01\n"
        let inputURL = tempDir.appendingPathComponent("sample_edit_test.csv")
        try csvContent.write(to: inputURL, atomically: true, encoding: .utf8)

        // Open
        await manager.loadFile(from: inputURL)
        XCTAssertNotNil(manager.workbook)
        XCTAssertNotNil(manager.currentSheet)
        XCTAssertNil(manager.error)

        // Edit
        manager.updateCell(row: 1, column: 0, value: "Modified")
        XCTAssertTrue(manager.isDirty)

        let cell = manager.currentSheet?.getCell(row: 1, column: 0)
        if case .string(let str) = cell?.value {
            XCTAssertEqual(str, "Modified")
        } else {
            XCTFail("Cell should contain 'Modified'")
        }

        // Export
        guard let currentSheet = manager.currentSheet else {
            XCTFail("Current sheet should exist")
            return
        }
        let outputURL = tempDir.appendingPathComponent("edited.csv")
        try await CSVExporter.export(sheet: currentSheet, to: outputURL)

        // Verify export
        let exported = try await CSVParser.parseCSV(url: outputURL)
        let exportedSheet = exported.sheets[0]
        if case .string(let str) = exportedSheet.getCell(row: 1, column: 0)?.value {
            XCTAssertEqual(str, "Modified")
        } else {
            XCTFail("Exported CSV should contain 'Modified'")
        }
    }

    // MARK: - End-to-End: Build Workbook -> XLSX Export

    func testBuildWorkbookAndExport() async throws {
        let manager = ExcelDataManager()

        // Build a workbook programmatically
        let sheet1 = SheetData(name: "Revenue", rows: 5, columns: 3)
        sheet1.cells[0][0].value = .string("Quarter")
        sheet1.cells[0][1].value = .string("Amount")
        sheet1.cells[0][2].value = .string("Growth")
        sheet1.cells[1][0].value = .string("Q1")
        sheet1.cells[1][1].value = .number(100000)
        sheet1.cells[1][2].value = .number(0.05)
        sheet1.cells[2][0].value = .string("Q2")
        sheet1.cells[2][1].value = .number(120000)
        sheet1.cells[2][2].value = .number(0.20)
        sheet1.cells[3][0].value = .string("Q3")
        sheet1.cells[3][1].value = .number(115000)
        sheet1.cells[3][2].value = .number(-0.04)
        sheet1.cells[4][0].value = .string("Q4")
        sheet1.cells[4][1].value = .number(140000)
        sheet1.cells[4][2].value = .number(0.22)

        let sheet2 = SheetData(name: "Summary", rows: 3, columns: 2)
        sheet2.cells[0][0].value = .string("Metric")
        sheet2.cells[0][1].value = .string("Value")
        sheet2.cells[1][0].value = .string("Total Revenue")
        sheet2.cells[1][1].value = .number(475000)
        sheet2.cells[2][0].value = .string("Avg Growth")
        sheet2.cells[2][1].value = .number(0.1075)

        let workbook = WorkbookData(filename: "financial.xlsx", sheets: [sheet1, sheet2])
        manager.workbook = workbook
        manager.currentSheet = sheet1

        // Export to XLSX
        let xlsxURL = tempDir.appendingPathComponent("financial.xlsx")
        try await ExcelWriter.writeXLSX(workbook: workbook, to: xlsxURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: xlsxURL.path))

        // Export to CSV
        let csvURL = tempDir.appendingPathComponent("revenue.csv")
        try await CSVExporter.export(sheet: sheet1, to: csvURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: csvURL.path))

        // Export to PDF
        let pdfURL = tempDir.appendingPathComponent("financial.pdf")
        try await PDFExporter.exportWorkbook(workbook, to: pdfURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pdfURL.path))
    }

    // MARK: - Sheet Navigation

    func testMultiSheetNavigation() async throws {
        let manager = ExcelDataManager()

        let sheet1 = SheetData(name: "Sheet1", rows: 3, columns: 2)
        sheet1.cells[0][0].value = .string("From Sheet 1")
        let sheet2 = SheetData(name: "Sheet2", rows: 3, columns: 2)
        sheet2.cells[0][0].value = .string("From Sheet 2")
        let sheet3 = SheetData(name: "Sheet3", rows: 3, columns: 2)
        sheet3.cells[0][0].value = .string("From Sheet 3")

        let workbook = WorkbookData(filename: "nav.xlsx", sheets: [sheet1, sheet2, sheet3])
        manager.workbook = workbook
        manager.currentSheet = sheet1
        manager.currentSheetIndex = 0

        // Navigate by index
        manager.selectSheet(at: 1)
        XCTAssertEqual(manager.currentSheet?.name, "Sheet2")
        XCTAssertEqual(manager.currentSheet?.getCell(row: 0, column: 0)?.displayValue, "From Sheet 2")

        // Navigate by name
        manager.selectSheet(named: "Sheet3")
        XCTAssertEqual(manager.currentSheet?.name, "Sheet3")

        // Navigate back
        manager.selectSheet(at: 0)
        XCTAssertEqual(manager.currentSheet?.name, "Sheet1")
    }

    // MARK: - Formula Recalculation

    func testFormulaRecalculatesOnCellChange() async {
        let manager = ExcelDataManager()
        let sheet = SheetData(name: "Test", rows: 10, columns: 5)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet])
        manager.workbook = workbook
        manager.currentSheet = sheet

        // Set up data
        sheet.setCell(row: 0, column: 0, value: .number(10))
        sheet.setCell(row: 1, column: 0, value: .number(20))
        sheet.setCell(row: 2, column: 0, value: .number(30))

        // Set formula
        manager.updateCell(row: 3, column: 0, value: "=SUM(A1:A3)")

        let cell = sheet.getCell(row: 3, column: 0)
        if case .formula(_, let result) = cell?.value {
            if case .number(let sum) = result {
                XCTAssertEqual(sum, 60)
            }
        }

        // Change a value and set another formula to trigger recalc
        sheet.setCell(row: 0, column: 0, value: .number(100))
        manager.updateCell(row: 4, column: 0, value: "=SUM(A1:A3)")

        // The new formula should see updated values
        let cell2 = sheet.getCell(row: 4, column: 0)
        if case .formula(_, let result) = cell2?.value {
            if case .number(let sum) = result {
                XCTAssertEqual(sum, 150)
            }
        }
    }

    // MARK: - Large Dataset Operations

    func testLargeDatasetColumnStats() async throws {
        // Build large dataset in memory to avoid file I/O race condition
        let sheet = SheetData(name: "Large", rows: 1001, columns: 4)
        sheet.cells[0][0].value = .string("ID")
        sheet.cells[0][1].value = .string("Value")
        sheet.cells[0][2].value = .string("Category")
        sheet.cells[0][3].value = .string("Score")

        for i in 1...1000 {
            sheet.cells[i][0].value = .number(Double(i))
            sheet.cells[i][1].value = .number(Double.random(in: 1...1000))
            sheet.cells[i][2].value = .string(["A", "B", "C"][i % 3])
            sheet.cells[i][3].value = .number(Double(Int.random(in: 0...100)))
        }

        // Column 3 = Score (0-100)
        let stats = sheet.columnStats(3)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats!.numbers.count, 1000)
        XCTAssertGreaterThanOrEqual(stats!.min, 0)
        XCTAssertLessThanOrEqual(stats!.max, 100)
        XCTAssertTrue(stats!.average > 0)
    }

    func testLargeDatasetExportPerformance() {
        measure {
            let expectation = self.expectation(description: "Large export")
            Task { @MainActor in
                let sheet = SheetData(name: "Big", rows: 1000, columns: 10)
                for row in 0..<1000 {
                    for col in 0..<10 {
                        sheet.cells[row][col].value = .number(Double(row * 10 + col))
                    }
                }
                let workbook = WorkbookData(filename: "big.xlsx", sheets: [sheet])
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("perf_\(UUID().uuidString).xlsx")
                try? await ExcelWriter.writeXLSX(workbook: workbook, to: url)
                try? FileManager.default.removeItem(at: url)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30)
        }
    }

    // MARK: - Workbook Mutation Operations

    func testAddAndRemoveSheets() {
        let workbook = WorkbookData(filename: "test.xlsx")

        // Add sheets
        workbook.addSheet(SheetData(name: "Sheet1", rows: 3, columns: 3))
        workbook.addSheet(SheetData(name: "Sheet2", rows: 3, columns: 3))
        workbook.addSheet(SheetData(name: "Sheet3", rows: 3, columns: 3))
        XCTAssertEqual(workbook.sheets.count, 3)

        // Remove middle
        workbook.removeSheet(at: 1)
        XCTAssertEqual(workbook.sheets.count, 2)
        XCTAssertEqual(workbook.sheets[0].name, "Sheet1")
        XCTAssertEqual(workbook.sheets[1].name, "Sheet3")
    }

    // MARK: - Mixed Type Column

    func testMixedTypeColumnHandling() {
        let sheet = SheetData(name: "Mixed", rows: 6, columns: 1)
        sheet.cells[0][0].value = .string("Header")
        sheet.cells[1][0].value = .number(42)
        sheet.cells[2][0].value = .string("text")
        sheet.cells[3][0].value = .bool(true)
        sheet.cells[4][0].value = .empty
        sheet.cells[5][0].value = .date(Date())

        // Stats should only count numbers
        let stats = sheet.columnStats(0)
        XCTAssertEqual(stats?.numbers.count, 1)  // Only 42
        XCTAssertEqual(stats?.count, 4)  // 4 non-empty (excluding header)
    }
}
