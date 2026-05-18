//
//  CSVParserTests.swift
//  ExcelExplorerTests
//
//  Unit + integration tests for CSV parsing
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import ExcelExplorer

final class CSVParserTests: XCTestCase {

    // MARK: - Basic CSV Parsing

    func testParseSimpleCSV() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)

        XCTAssertEqual(workbook.filename, "sample.csv")
        XCTAssertEqual(workbook.sheets.count, 1)
        XCTAssertEqual(workbook.sheets[0].name, "Sheet1")
    }

    func testParseCSVHeaders() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        let headers = sheet.headers
        XCTAssertEqual(headers, ["Name", "Age", "Salary", "Department", "Active", "StartDate"])
    }

    func testParseCSVRowCount() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        // 1 header + 5 data rows
        XCTAssertEqual(sheet.rowCount, 6)
    }

    func testParseCSVColumnCount() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        XCTAssertEqual(sheet.columnCount, 6)
    }

    // MARK: - Cell Value Type Detection

    func testCSVStringDetection() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        // Row 1, Col 0 = "Alice" (string)
        if case .string(let name) = sheet.getCell(row: 1, column: 0)?.value {
            XCTAssertEqual(name, "Alice")
        } else {
            XCTFail("Expected string value for Name column")
        }
    }

    func testCSVNumberDetection() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        // Row 1, Col 1 = 30 (number)
        if case .number(let age) = sheet.getCell(row: 1, column: 1)?.value {
            XCTAssertEqual(age, 30)
        } else {
            XCTFail("Expected number value for Age column")
        }
    }

    func testCSVDecimalNumberDetection() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        // Row 1, Col 2 = 75000.50 (number with decimal)
        if case .number(let salary) = sheet.getCell(row: 1, column: 2)?.value {
            XCTAssertEqual(salary, 75000.50, accuracy: 0.01)
        } else {
            XCTFail("Expected number value for Salary column")
        }
    }

    func testCSVBooleanDetection() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        // Row 1, Col 4 = TRUE
        if case .bool(let active) = sheet.getCell(row: 1, column: 4)?.value {
            XCTAssertTrue(active)
        } else {
            XCTFail("Expected boolean value for Active column")
        }

        // Row 2, Col 4 = FALSE
        if case .bool(let active) = sheet.getCell(row: 2, column: 4)?.value {
            XCTAssertFalse(active)
        } else {
            XCTFail("Expected boolean value for Active column row 2")
        }
    }

    func testCSVDateDetection() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        // Row 1, Col 5 = "2020-01-15" (date)
        if case .date = sheet.getCell(row: 1, column: 5)?.value {
            // Date was parsed
        } else {
            XCTFail("Expected date value for StartDate column")
        }
    }

    func testCSVEmptyCellDetection() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        // Row 4 (Diana), Col 2 = empty salary
        if case .empty = sheet.getCell(row: 4, column: 2)?.value {
            // Correct: empty value
        } else {
            XCTFail("Expected empty value for Diana's salary")
        }
    }

    // MARK: - Quoted CSV

    func testParseQuotedCSV() async throws {
        let url = testDataURL("quoted.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        XCTAssertEqual(sheet.headers, ["Product", "Description", "Price", "Notes"])
    }

    func testCSVFieldWithComma() async throws {
        let url = testDataURL("quoted.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        // Row 1 description = "A simple, useful widget"
        if case .string(let desc) = sheet.getCell(row: 1, column: 1)?.value {
            XCTAssertTrue(desc.contains(","), "Comma should be preserved in quoted field")
        } else {
            XCTFail("Expected string for description")
        }
    }

    func testCSVFieldWithEscapedQuotes() async throws {
        let url = testDataURL("quoted.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        // Row 2 product = Widget "B" (escaped quotes)
        if case .string(let product) = sheet.getCell(row: 2, column: 0)?.value {
            XCTAssertTrue(product.contains("\""), "Escaped quotes should be preserved: \(product)")
        } else {
            XCTFail("Expected string for product")
        }
    }

    // MARK: - Empty CSV

    func testParseEmptyCSVThrows() async {
        let url = testDataURL("empty.csv")
        do {
            _ = try await CSVParser.parseCSV(url: url)
            XCTFail("Should throw for empty CSV")
        } catch {
            // Expected: empty CSV error
            XCTAssertTrue(error is ExcelError)
        }
    }

    // MARK: - Large CSV

    func testParseLargeCSV() async throws {
        let url = testDataURL("large_sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        // 1 header + 10000 data rows
        XCTAssertEqual(sheet.rowCount, 10001)
        XCTAssertEqual(sheet.columnCount, 4)
        XCTAssertEqual(sheet.headers, ["ID", "Value", "Category", "Score"])
    }

    func testLargeCSVPerformance() {
        let url = testDataURL("large_sample.csv")
        measure {
            let expectation = self.expectation(description: "Parse large CSV")
            Task {
                _ = try? await CSVParser.parseCSV(url: url)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10)
        }
    }

    // MARK: - File Metadata

    func testCSVFileMetadata() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)

        XCTAssertNotNil(workbook.metadata.fileSize)
        XCTAssertTrue(workbook.metadata.fileSize! > 0)
    }

    // MARK: - Header Row Formatting

    func testCSVHeaderRowIsBold() async throws {
        let url = testDataURL("sample.csv")
        let workbook = try await CSVParser.parseCSV(url: url)
        let sheet = workbook.sheets[0]

        // Header row cells should have bold formatting
        for col in 0..<sheet.columnCount {
            let cell = sheet.getCell(row: 0, column: col)
            XCTAssertTrue(cell?.formatting.isBold ?? false, "Header cell at column \(col) should be bold")
        }
    }

    // MARK: - Row Padding

    func testCSVRowPaddedToHeaderCount() async throws {
        // Create a CSV where data rows have fewer columns than header
        let csvContent = "A,B,C\n1,2\n4,5,6\n"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("padded_test.csv")
        try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let workbook = try await CSVParser.parseCSV(url: tempURL)
        let sheet = workbook.sheets[0]

        // Row 1 has only 2 values but should be padded to 3 columns
        XCTAssertEqual(sheet.cells[1].count, 3)
        if case .empty = sheet.cells[1][2].value {
            // Correct: padded with empty
        } else {
            XCTFail("Padded cell should be empty")
        }
    }

    // MARK: - Helpers

    private func testDataURL(_ filename: String) -> URL {
        let bundle = Bundle(for: type(of: self))
        if let url = bundle.url(forResource: filename.replacingOccurrences(of: ".csv", with: ""),
                                withExtension: "csv") {
            return url
        }
        // Fallback to direct path during development
        return URL(fileURLWithPath: "/Volumes/Data/xcode/ExcelExplorer/ExcelExplorerTests/TestData/\(filename)")
    }
}
