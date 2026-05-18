//
//  CellDataTests.swift
//  ExcelExplorerTests
//
//  Unit tests for CellData, CellValue, CellReference, and CellFormatting
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import ExcelExplorer

final class CellDataTests: XCTestCase {

    // MARK: - CellReference Tests

    func testCellReferenceFromColumnRow() {
        let ref = CellReference(column: 0, row: 0)
        XCTAssertEqual(ref.column, 0)
        XCTAssertEqual(ref.row, 0)
        XCTAssertEqual(ref.excelNotation, "A1")
    }

    func testCellReferenceExcelNotationSingleLetter() {
        XCTAssertEqual(CellReference(column: 0, row: 0).excelNotation, "A1")
        XCTAssertEqual(CellReference(column: 1, row: 0).excelNotation, "B1")
        XCTAssertEqual(CellReference(column: 25, row: 0).excelNotation, "Z1")
    }

    func testCellReferenceExcelNotationDoubleLetter() {
        XCTAssertEqual(CellReference(column: 26, row: 0).excelNotation, "AA1")
        XCTAssertEqual(CellReference(column: 27, row: 0).excelNotation, "AB1")
        XCTAssertEqual(CellReference(column: 51, row: 0).excelNotation, "AZ1")
        XCTAssertEqual(CellReference(column: 52, row: 0).excelNotation, "BA1")
    }

    func testCellReferenceExcelNotationRowOffset() {
        XCTAssertEqual(CellReference(column: 0, row: 9).excelNotation, "A10")
        XCTAssertEqual(CellReference(column: 2, row: 99).excelNotation, "C100")
    }

    func testCellReferenceFromExcelNotation() {
        let ref = CellReference(excelNotation: "A1")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.column, 0)
        XCTAssertEqual(ref?.row, 0)
    }

    func testCellReferenceFromExcelNotationMultiLetter() {
        let ref = CellReference(excelNotation: "AA1")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.column, 26)
        XCTAssertEqual(ref?.row, 0)
    }

    func testCellReferenceFromExcelNotationZ1() {
        let ref = CellReference(excelNotation: "Z1")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.column, 25)
        XCTAssertEqual(ref?.row, 0)
    }

    func testCellReferenceFromExcelNotationLargeRow() {
        let ref = CellReference(excelNotation: "B500")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.column, 1)
        XCTAssertEqual(ref?.row, 499)
    }

    func testCellReferenceInvalidNotationReturnsNil() {
        XCTAssertNil(CellReference(excelNotation: ""))
        XCTAssertNil(CellReference(excelNotation: "123"))
        XCTAssertNil(CellReference(excelNotation: "a1"))  // lowercase
        XCTAssertNil(CellReference(excelNotation: "A"))    // no row number
        XCTAssertNil(CellReference(excelNotation: "1A"))   // wrong order
    }

    func testCellReferenceHashable() {
        let ref1 = CellReference(column: 0, row: 0)
        let ref2 = CellReference(column: 0, row: 0)
        let ref3 = CellReference(column: 1, row: 0)

        XCTAssertEqual(ref1, ref2)
        XCTAssertNotEqual(ref1, ref3)

        var set = Set<CellReference>()
        set.insert(ref1)
        set.insert(ref2)
        XCTAssertEqual(set.count, 1)
    }

    func testCellReferenceRoundTrip() {
        // Column 0-25 (A-Z)
        for col in 0...25 {
            let original = CellReference(column: col, row: 5)
            let notation = original.excelNotation
            let parsed = CellReference(excelNotation: notation)
            XCTAssertNotNil(parsed, "Failed to parse notation: \(notation)")
            XCTAssertEqual(parsed?.column, col, "Column mismatch for \(notation)")
            XCTAssertEqual(parsed?.row, 5, "Row mismatch for \(notation)")
        }
    }

    // MARK: - CellValue Tests

    func testCellValueEmpty() {
        let value = CellValue.empty
        XCTAssertEqual(value.displayValue, "")
        XCTAssertEqual(value.rawValue, "")
    }

    func testCellValueString() {
        let value = CellValue.string("Hello World")
        XCTAssertEqual(value.displayValue, "Hello World")
        XCTAssertEqual(value.rawValue, "Hello World")
    }

    func testCellValueNumberInteger() {
        let value = CellValue.number(42.0)
        XCTAssertEqual(value.displayValue, "42")
        XCTAssertEqual(value.rawValue, "42.0")
    }

    func testCellValueNumberDecimal() {
        let value = CellValue.number(3.14)
        XCTAssertEqual(value.displayValue, "3.14")
    }

    func testCellValueBoolTrue() {
        let value = CellValue.bool(true)
        XCTAssertEqual(value.displayValue, "TRUE")
        XCTAssertEqual(value.rawValue, "TRUE")
    }

    func testCellValueBoolFalse() {
        let value = CellValue.bool(false)
        XCTAssertEqual(value.displayValue, "FALSE")
        XCTAssertEqual(value.rawValue, "FALSE")
    }

    func testCellValueDate() {
        let date = Date(timeIntervalSince1970: 0) // 1970-01-01
        let value = CellValue.date(date)
        XCTAssertFalse(value.displayValue.isEmpty, "Date display value should not be empty")
    }

    func testCellValueFormulaDisplaysResult() {
        let value = CellValue.formula("=SUM(A1:A5)", result: .number(150))
        XCTAssertEqual(value.displayValue, "150")
        XCTAssertEqual(value.rawValue, "=SUM(A1:A5)")
    }

    func testCellValueFormulaWithEmptyResult() {
        let value = CellValue.formula("=SUM(A1:A5)", result: .empty)
        XCTAssertEqual(value.displayValue, "")
        XCTAssertEqual(value.rawValue, "=SUM(A1:A5)")
    }

    func testCellValueEquatable() {
        XCTAssertEqual(CellValue.empty, CellValue.empty)
        XCTAssertEqual(CellValue.string("test"), CellValue.string("test"))
        XCTAssertEqual(CellValue.number(42), CellValue.number(42))
        XCTAssertEqual(CellValue.bool(true), CellValue.bool(true))
        XCTAssertNotEqual(CellValue.string("a"), CellValue.string("b"))
        XCTAssertNotEqual(CellValue.number(1), CellValue.number(2))
    }

    // MARK: - CellData Tests

    func testCellDataInit() {
        let ref = CellReference(column: 0, row: 0)
        let cell = CellData(reference: ref, value: .string("Test"))
        XCTAssertEqual(cell.reference, ref)
        XCTAssertEqual(cell.displayValue, "Test")
    }

    func testCellDataDefaultsToEmpty() {
        let ref = CellReference(column: 0, row: 0)
        let cell = CellData(reference: ref)
        XCTAssertEqual(cell.value, CellValue.empty)
        XCTAssertEqual(cell.displayValue, "")
    }

    func testCellDataIsFormula() {
        let ref = CellReference(column: 0, row: 0)

        let formulaCell = CellData(reference: ref, value: .formula("=SUM(A1:A5)", result: .number(10)))
        XCTAssertTrue(formulaCell.isFormula)

        let textCell = CellData(reference: ref, value: .string("Hello"))
        XCTAssertFalse(textCell.isFormula)

        let emptyCell = CellData(reference: ref)
        XCTAssertFalse(emptyCell.isFormula)
    }

    func testCellDataDefaultFormatting() {
        let ref = CellReference(column: 0, row: 0)
        let cell = CellData(reference: ref)
        XCTAssertFalse(cell.formatting.isBold)
        XCTAssertFalse(cell.formatting.isItalic)
        XCTAssertEqual(cell.formatting.fontSize, 12)
        XCTAssertNil(cell.formatting.textColor)
        XCTAssertNil(cell.formatting.backgroundColor)
    }

    // MARK: - CellFormatting Tests

    func testCellFormattingDefaults() {
        let formatting = CellFormatting()
        XCTAssertFalse(formatting.isBold)
        XCTAssertFalse(formatting.isItalic)
        XCTAssertEqual(formatting.fontSize, 12)
        XCTAssertEqual(formatting.alignment, .left)
        XCTAssertNil(formatting.numberFormat)
    }

    func testCellFormattingCustomValues() {
        var formatting = CellFormatting()
        formatting.isBold = true
        formatting.isItalic = true
        formatting.fontSize = 16
        formatting.textColor = "#FF0000"
        formatting.alignment = .center

        XCTAssertTrue(formatting.isBold)
        XCTAssertTrue(formatting.isItalic)
        XCTAssertEqual(formatting.fontSize, 16)
        XCTAssertEqual(formatting.textColor, "#FF0000")
        XCTAssertEqual(formatting.alignment, .center)
    }

    // MARK: - CellValue Codable Tests

    func testCellValueCodableRoundTrip() throws {
        let values: [CellValue] = [
            .empty,
            .string("Hello"),
            .number(42.5),
            .bool(true),
            .formula("=SUM(A1:A5)", result: .number(100))
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for value in values {
            let data = try encoder.encode(value)
            let decoded = try decoder.decode(CellValue.self, from: data)
            XCTAssertEqual(decoded, value, "Codable round-trip failed for \(value)")
        }
    }

    func testCellReferenceCodableRoundTrip() throws {
        let ref = CellReference(column: 5, row: 10)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(ref)
        let decoded = try decoder.decode(CellReference.self, from: data)
        XCTAssertEqual(decoded, ref)
    }
}
