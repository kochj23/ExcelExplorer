//
//  ExportTests.swift
//  ExcelExplorerTests
//
//  Tests for CSV, XLSX, and PDF export pipelines
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import ExcelExplorer

final class ExportTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExcelExplorerTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - CSV Export

    func testCSVExportBasic() async throws {
        let sheet = createSampleSheet()
        let outputURL = tempDir.appendingPathComponent("output.csv")

        try await CSVExporter.export(sheet: sheet, to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let content = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertTrue(content.contains("Name"))
        XCTAssertTrue(content.contains("Alice"))
    }

    func testCSVExportAllSheets() async throws {
        let workbook = createSampleWorkbook()
        let outputURL = tempDir.appendingPathComponent("output_multi.csv")

        try await CSVExporter.exportAllSheets(workbook: workbook, to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testCSVExportEscapesCommas() async throws {
        let sheet = SheetData(name: "Test", rows: 2, columns: 2)
        sheet.cells[0][0].value = .string("Header1")
        sheet.cells[0][1].value = .string("Header2")
        sheet.cells[1][0].value = .string("value, with comma")
        sheet.cells[1][1].value = .string("normal")

        let outputURL = tempDir.appendingPathComponent("escaped.csv")
        try await CSVExporter.export(sheet: sheet, to: outputURL)

        let content = try String(contentsOf: outputURL, encoding: .utf8)
        // Commas in values should be quoted
        XCTAssertTrue(content.contains("\"value, with comma\""))
    }

    func testCSVExportEscapesQuotes() async throws {
        let sheet = SheetData(name: "Test", rows: 2, columns: 1)
        sheet.cells[0][0].value = .string("Header")
        sheet.cells[1][0].value = .string("say \"hello\"")

        let outputURL = tempDir.appendingPathComponent("quotes.csv")
        try await CSVExporter.export(sheet: sheet, to: outputURL)

        let content = try String(contentsOf: outputURL, encoding: .utf8)
        // Quotes should be escaped as double quotes
        XCTAssertTrue(content.contains("\"\"hello\"\""))
    }

    func testCSVExportEmptyWorkbookThrows() async {
        let workbook = WorkbookData(filename: "empty.xlsx")
        let outputURL = tempDir.appendingPathComponent("empty.csv")

        do {
            try await CSVExporter.exportAllSheets(workbook: workbook, to: outputURL)
            XCTFail("Should throw for empty workbook")
        } catch {
            XCTAssertTrue(error is ExportError)
        }
    }

    // MARK: - XLSX Export

    func testXLSXExportCreatesFile() async throws {
        let workbook = createSampleWorkbook()
        let outputURL = tempDir.appendingPathComponent("output.xlsx")

        try await ExcelWriter.writeXLSX(workbook: workbook, to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let fileSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int ?? 0
        XCTAssertGreaterThan(fileSize, 0, "XLSX file should not be empty")
    }

    func testXLSXExportIsZipFile() async throws {
        let workbook = createSampleWorkbook()
        let outputURL = tempDir.appendingPathComponent("zipcheck.xlsx")

        try await ExcelWriter.writeXLSX(workbook: workbook, to: outputURL)

        // XLSX is a ZIP file; check for ZIP magic bytes (PK)
        let data = try Data(contentsOf: outputURL)
        XCTAssertGreaterThan(data.count, 4)
        XCTAssertEqual(data[0], 0x50) // 'P'
        XCTAssertEqual(data[1], 0x4B) // 'K'
    }

    func testXLSXExportMultipleSheets() async throws {
        let sheet1 = createSampleSheet()
        let sheet2 = SheetData(name: "Sheet2", rows: 2, columns: 2)
        sheet2.cells[0][0].value = .string("X")
        sheet2.cells[0][1].value = .string("Y")
        sheet2.cells[1][0].value = .number(1)
        sheet2.cells[1][1].value = .number(2)

        let workbook = WorkbookData(filename: "multi.xlsx", sheets: [sheet1, sheet2])
        let outputURL = tempDir.appendingPathComponent("multi.xlsx")

        try await ExcelWriter.writeXLSX(workbook: workbook, to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testXLSXExportHandlesSpecialCharacters() async throws {
        let sheet = SheetData(name: "Special", rows: 2, columns: 1)
        sheet.cells[0][0].value = .string("Header")
        sheet.cells[1][0].value = .string("Contains <brackets> & \"quotes\" and 'apostrophes'")

        let workbook = WorkbookData(filename: "special.xlsx", sheets: [sheet])
        let outputURL = tempDir.appendingPathComponent("special.xlsx")

        // Should not crash - XML special chars must be escaped
        try await ExcelWriter.writeXLSX(workbook: workbook, to: outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testXLSXExportHandlesBooleans() async throws {
        let sheet = SheetData(name: "Bools", rows: 3, columns: 1)
        sheet.cells[0][0].value = .string("Active")
        sheet.cells[1][0].value = .bool(true)
        sheet.cells[2][0].value = .bool(false)

        let workbook = WorkbookData(filename: "bools.xlsx", sheets: [sheet])
        let outputURL = tempDir.appendingPathComponent("bools.xlsx")

        try await ExcelWriter.writeXLSX(workbook: workbook, to: outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testXLSXExportHandlesDates() async throws {
        let sheet = SheetData(name: "Dates", rows: 2, columns: 1)
        sheet.cells[0][0].value = .string("Date")
        sheet.cells[1][0].value = .date(Date())

        let workbook = WorkbookData(filename: "dates.xlsx", sheets: [sheet])
        let outputURL = tempDir.appendingPathComponent("dates.xlsx")

        try await ExcelWriter.writeXLSX(workbook: workbook, to: outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testXLSXExportHandlesFormulas() async throws {
        let sheet = SheetData(name: "Formulas", rows: 3, columns: 1)
        sheet.cells[0][0].value = .number(10)
        sheet.cells[1][0].value = .number(20)
        sheet.cells[2][0].value = .formula("=SUM(A1:A2)", result: .number(30))

        let workbook = WorkbookData(filename: "formulas.xlsx", sheets: [sheet])
        let outputURL = tempDir.appendingPathComponent("formulas.xlsx")

        try await ExcelWriter.writeXLSX(workbook: workbook, to: outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    // MARK: - PDF Export

    func testPDFExportCreatesFile() async throws {
        let sheet = createSampleSheet()
        let outputURL = tempDir.appendingPathComponent("output.pdf")

        try await PDFExporter.exportSheet(sheet, to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let fileSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int ?? 0
        XCTAssertGreaterThan(fileSize, 0)
    }

    func testPDFExportWorkbook() async throws {
        let workbook = createSampleWorkbook()
        let outputURL = tempDir.appendingPathComponent("workbook.pdf")

        try await PDFExporter.exportWorkbook(workbook, to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testPDFExportIsPDFFormat() async throws {
        let sheet = createSampleSheet()
        let outputURL = tempDir.appendingPathComponent("format.pdf")

        try await PDFExporter.exportSheet(sheet, to: outputURL)

        let data = try Data(contentsOf: outputURL)
        // PDF magic bytes: %PDF
        let header = String(data: data.prefix(4), encoding: .ascii)
        XCTAssertEqual(header, "%PDF")
    }

    // MARK: - ExportError

    func testExportErrorDescriptions() {
        XCTAssertEqual(ExportError.noData.localizedDescription, "No data to export")
        XCTAssertEqual(ExportError.fileWriteError.localizedDescription, "Failed to write file")
        XCTAssertTrue(ExportError.invalidFormat("test").localizedDescription.contains("test"))
        XCTAssertTrue(ExportError.fileSystemError("msg").localizedDescription.contains("msg"))
    }

    // MARK: - Round-Trip (CSV parse -> CSV export -> re-parse)

    func testCSVRoundTrip() async throws {
        // Create a temp CSV to avoid interrupted system call race condition
        let csvContent = "Name,Age,Score\nAlice,30,95.5\nBob,25,87\nCharlie,35,92.3\n"
        let inputURL = tempDir.appendingPathComponent("roundtrip_input.csv")
        try csvContent.write(to: inputURL, atomically: true, encoding: .utf8)

        // Parse original
        let workbook = try await CSVParser.parseCSV(url: inputURL)
        let sheet = workbook.sheets[0]

        // Export
        let outputURL = tempDir.appendingPathComponent("roundtrip.csv")
        try await CSVExporter.export(sheet: sheet, to: outputURL)

        // Re-parse
        let workbook2 = try await CSVParser.parseCSV(url: outputURL)
        let sheet2 = workbook2.sheets[0]

        // Compare
        XCTAssertEqual(sheet.headers, sheet2.headers)
        XCTAssertEqual(sheet.rowCount, sheet2.rowCount)
    }

    // MARK: - Helpers

    private func createSampleSheet() -> SheetData {
        let sheet = SheetData(name: "TestSheet", rows: 4, columns: 3)
        sheet.cells[0][0].value = .string("Name")
        sheet.cells[0][1].value = .string("Age")
        sheet.cells[0][2].value = .string("Score")
        sheet.cells[1][0].value = .string("Alice")
        sheet.cells[1][1].value = .number(30)
        sheet.cells[1][2].value = .number(95.5)
        sheet.cells[2][0].value = .string("Bob")
        sheet.cells[2][1].value = .number(25)
        sheet.cells[2][2].value = .number(87)
        sheet.cells[3][0].value = .string("Charlie")
        sheet.cells[3][1].value = .number(35)
        sheet.cells[3][2].value = .number(92.3)
        return sheet
    }

    private func createSampleWorkbook() -> WorkbookData {
        return WorkbookData(filename: "test.xlsx", sheets: [createSampleSheet()])
    }
}
