//
//  WorkbookDataTests.swift
//  ExcelExplorerTests
//
//  Unit tests for WorkbookData model and FileMetadata
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import ExcelExplorer

final class WorkbookDataTests: XCTestCase {

    // MARK: - Initialization

    func testWorkbookDataInit() {
        let workbook = WorkbookData(filename: "test.xlsx")
        XCTAssertEqual(workbook.filename, "test.xlsx")
        XCTAssertTrue(workbook.sheets.isEmpty)
        XCTAssertTrue(workbook.embeddedImages.isEmpty)
        XCTAssertNil(workbook.fileURL)
    }

    func testWorkbookDataInitWithSheets() {
        let sheet1 = SheetData(name: "Sheet1", rows: 5, columns: 3)
        let sheet2 = SheetData(name: "Sheet2", rows: 5, columns: 3)
        let workbook = WorkbookData(filename: "multi.xlsx", sheets: [sheet1, sheet2])
        XCTAssertEqual(workbook.sheets.count, 2)
    }

    // MARK: - Sheet Access

    func testGetSheetByName() {
        let sheet = SheetData(name: "Revenue", rows: 5, columns: 3)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet])

        let found = workbook.getSheet(named: "Revenue")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Revenue")
    }

    func testGetSheetByNameNotFound() {
        let sheet = SheetData(name: "Revenue", rows: 5, columns: 3)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet])

        XCTAssertNil(workbook.getSheet(named: "Missing"))
    }

    func testGetSheetByIndex() {
        let sheet1 = SheetData(name: "Sheet1", rows: 5, columns: 3)
        let sheet2 = SheetData(name: "Sheet2", rows: 5, columns: 3)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet1, sheet2])

        XCTAssertEqual(workbook.getSheet(at: 0)?.name, "Sheet1")
        XCTAssertEqual(workbook.getSheet(at: 1)?.name, "Sheet2")
    }

    func testGetSheetByIndexOutOfBounds() {
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [])
        XCTAssertNil(workbook.getSheet(at: 0))
        XCTAssertNil(workbook.getSheet(at: -1))
    }

    // MARK: - Sheet Mutations

    func testAddSheet() {
        let workbook = WorkbookData(filename: "test.xlsx")
        XCTAssertEqual(workbook.sheets.count, 0)

        let sheet = SheetData(name: "NewSheet", rows: 5, columns: 3)
        workbook.addSheet(sheet)
        XCTAssertEqual(workbook.sheets.count, 1)
        XCTAssertEqual(workbook.sheets[0].name, "NewSheet")
    }

    func testRemoveSheet() {
        let sheet1 = SheetData(name: "Sheet1", rows: 5, columns: 3)
        let sheet2 = SheetData(name: "Sheet2", rows: 5, columns: 3)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet1, sheet2])

        workbook.removeSheet(at: 0)
        XCTAssertEqual(workbook.sheets.count, 1)
        XCTAssertEqual(workbook.sheets[0].name, "Sheet2")
    }

    func testRemoveSheetOutOfBoundsDoesNotCrash() {
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [])
        workbook.removeSheet(at: 0)
        workbook.removeSheet(at: -1)
        XCTAssertTrue(workbook.sheets.isEmpty)
    }

    // MARK: - FileMetadata Tests

    func testFileMetadataDefaults() {
        let meta = FileMetadata()
        XCTAssertNil(meta.createdDate)
        XCTAssertNil(meta.modifiedDate)
        XCTAssertNil(meta.author)
        XCTAssertNil(meta.lastModifiedBy)
        XCTAssertNil(meta.company)
        XCTAssertNil(meta.fileSize)
    }

    func testFileMetadataCustomValues() {
        let now = Date()
        let meta = FileMetadata(
            createdDate: now,
            modifiedDate: now,
            author: "Jordan Koch",
            lastModifiedBy: "Jordan Koch",
            company: "digitalnoise",
            fileSize: 1024
        )
        XCTAssertEqual(meta.author, "Jordan Koch")
        XCTAssertEqual(meta.company, "digitalnoise")
        XCTAssertEqual(meta.fileSize, 1024)
    }
}
