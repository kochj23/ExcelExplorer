//
//  ExcelWriter.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  Updated: 2026-01-27 - Implemented XLSX export
//

import Foundation

class ExcelWriter {
    /// Write workbook to XLSX format
    static func writeXLSX(workbook: WorkbookData, to url: URL) async throws {
        print("[ExcelWriter] Starting XLSX export to: \(url.lastPathComponent)")

        // Create temporary directory for XLSX structure
        let tempDir = createTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Build shared strings table
        let sharedStrings = buildSharedStrings(from: workbook)

        // Create XLSX directory structure
        try createXLSXStructure(at: tempDir, workbook: workbook, sharedStrings: sharedStrings)

        // Create ZIP archive (XLSX is a ZIP file)
        try await zipDirectory(tempDir, to: url)

        print("[ExcelWriter] ✅ XLSX export complete")
    }

    // MARK: - XLSX Structure Creation

    private static func createXLSXStructure(at baseURL: URL, workbook: WorkbookData, sharedStrings: [String]) throws {
        let fm = FileManager.default

        // Create directory structure
        try fm.createDirectory(at: baseURL.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        try fm.createDirectory(at: baseURL.appendingPathComponent("xl/_rels"), withIntermediateDirectories: true)
        try fm.createDirectory(at: baseURL.appendingPathComponent("xl/worksheets"), withIntermediateDirectories: true)

        // Write [Content_Types].xml
        try writeContentTypes(to: baseURL, sheetCount: workbook.sheets.count)

        // Write _rels/.rels
        try writeRootRels(to: baseURL)

        // Write xl/_rels/workbook.xml.rels
        try writeWorkbookRels(to: baseURL, sheetCount: workbook.sheets.count)

        // Write xl/workbook.xml
        try writeWorkbook(to: baseURL, workbook: workbook)

        // Write xl/sharedStrings.xml
        try writeSharedStrings(to: baseURL, strings: sharedStrings)

        // Write xl/styles.xml
        try writeStyles(to: baseURL)

        // Write each worksheet
        for (index, sheet) in workbook.sheets.enumerated() {
            try writeWorksheet(to: baseURL, sheet: sheet, index: index + 1, sharedStrings: sharedStrings)
        }
    }

    // MARK: - Shared Strings

    private static func buildSharedStrings(from workbook: WorkbookData) -> [String] {
        var strings = Set<String>()

        for sheet in workbook.sheets {
            for row in sheet.cells {
                for cell in row {
                    if case .string(let text) = cell.value, !text.isEmpty {
                        strings.insert(text)
                    }
                }
            }
        }

        return Array(strings).sorted()
    }

    // MARK: - XML Writers

    private static func writeContentTypes(to baseURL: URL, sheetCount: Int) throws {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        """

        for i in 1...sheetCount {
            xml += """

              <Override PartName="/xl/worksheets/sheet\(i).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            """
        }

        xml += """

          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
          <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        </Types>
        """

        try xml.write(to: baseURL.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
    }

    private static func writeRootRels(to baseURL: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """

        try xml.write(to: baseURL.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
    }

    private static func writeWorkbookRels(to baseURL: URL, sheetCount: Int) throws {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        """

        for i in 1...sheetCount {
            xml += """

              <Relationship Id="rId\(i)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet\(i).xml"/>
            """
        }

        xml += """

          <Relationship Id="rId\(sheetCount + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
          <Relationship Id="rId\(sheetCount + 2)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
        </Relationships>
        """

        try xml.write(to: baseURL.appendingPathComponent("xl/_rels/workbook.xml.rels"), atomically: true, encoding: .utf8)
    }

    private static func writeWorkbook(to baseURL: URL, workbook: WorkbookData) throws {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
        """

        for (index, sheet) in workbook.sheets.enumerated() {
            let sheetId = index + 1
            xml += """

            <sheet name="\(xmlEscape(sheet.name))" sheetId="\(sheetId)" r:id="rId\(sheetId)"/>
            """
        }

        xml += """

          </sheets>
        </workbook>
        """

        try xml.write(to: baseURL.appendingPathComponent("xl/workbook.xml"), atomically: true, encoding: .utf8)
    }

    private static func writeSharedStrings(to baseURL: URL, strings: [String]) throws {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(strings.count)" uniqueCount="\(strings.count)">
        """

        for string in strings {
            xml += """

            <si><t>\(xmlEscape(string))</t></si>
            """
        }

        xml += """

        </sst>
        """

        try xml.write(to: baseURL.appendingPathComponent("xl/sharedStrings.xml"), atomically: true, encoding: .utf8)
    }

    private static func writeStyles(to baseURL: URL) throws {
        // Basic styles XML - just enough to make Excel happy
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <numFmts count="0"/>
          <fonts count="1">
            <font><sz val="11"/><name val="Calibri"/></font>
          </fonts>
          <fills count="2">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
          </fills>
          <borders count="1">
            <border><left/><right/><top/><bottom/><diagonal/></border>
          </borders>
          <cellXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
          </cellXfs>
        </styleSheet>
        """

        try xml.write(to: baseURL.appendingPathComponent("xl/styles.xml"), atomically: true, encoding: .utf8)
    }

    private static func writeWorksheet(to baseURL: URL, sheet: SheetData, index: Int, sharedStrings: [String]) throws {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
        """

        for (rowIndex, row) in sheet.cells.enumerated() where rowIndex < 1048576 {
            let rowNum = rowIndex + 1
            xml += """

            <row r="\(rowNum)">
            """

            for (colIndex, cell) in row.enumerated() where colIndex < 16384 {
                let cellRef = columnLetter(colIndex) + String(rowNum)

                switch cell.value {
                case .string(let text) where !text.isEmpty:
                    if let stringIndex = sharedStrings.firstIndex(of: text) {
                        xml += """

                        <c r="\(cellRef)" t="s"><v>\(stringIndex)</v></c>
                        """
                    }
                case .number(let num):
                    xml += """

                        <c r="\(cellRef)"><v>\(num)</v></c>
                    """
                case .bool(let bool):
                    xml += """

                        <c r="\(cellRef)" t="b"><v>\(bool ? 1 : 0)</v></c>
                    """
                case .date(let date):
                    // Excel stores dates as numbers (days since 1900-01-01)
                    let excelDate = date.timeIntervalSince1970 / 86400 + 25569
                    xml += """

                        <c r="\(cellRef)"><v>\(excelDate)</v></c>
                    """
                case .formula(let formula, _):
                    xml += """

                        <c r="\(cellRef)"><f>\(xmlEscape(formula))</f></c>
                    """
                default:
                    break
                }
            }

            xml += """

            </row>
            """
        }

        xml += """

          </sheetData>
        </worksheet>
        """

        try xml.write(to: baseURL.appendingPathComponent("xl/worksheets/sheet\(index).xml"), atomically: true, encoding: .utf8)
    }

    // MARK: - ZIP Creation

    private static func zipDirectory(_ sourceURL: URL, to destinationURL: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", "-X", destinationURL.path, "."]
        process.currentDirectoryURL = sourceURL

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExportError.zipFailed("Failed to create XLSX archive")
        }
    }

    // MARK: - Helper Functions

    private static func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private static func columnLetter(_ index: Int) -> String {
        var column = index
        var result = ""

        repeat {
            result = String(UnicodeScalar(65 + (column % 26))!) + result
            column = column / 26 - 1
        } while column >= 0

        return result
    }

    private static func xmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Export Errors

extension ExportError {
    static func zipFailed(_ message: String) -> ExportError {
        return .fileSystemError(message)
    }
}
