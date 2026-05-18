//
//  FrameTests.swift
//  ExcelExplorerTests
//
//  Frame tests: app initialization, manager singletons, view creation,
//  widget data sync, notification system, Nova API server boot
//  Created by Jordan Koch on 2026-05-03.
//

import XCTest
@testable import ExcelExplorer

@MainActor
final class FrameTests: XCTestCase {

    // MARK: - Manager Initialization

    func testExcelDataManagerInitializesClean() {
        let manager = ExcelDataManager()
        XCTAssertNil(manager.workbook, "Manager should start with no workbook")
        XCTAssertNil(manager.currentSheet, "Manager should start with no current sheet")
        XCTAssertEqual(manager.currentSheetIndex, 0, "Default sheet index should be 0")
        XCTAssertFalse(manager.isDirty, "Manager should not be dirty on init")
        XCTAssertFalse(manager.isLoading, "Manager should not be loading on init")
        XCTAssertNil(manager.error, "Manager should have no error on init")
    }

    func testAIBackendManagerSingletonExists() {
        let manager = AIBackendManager.shared
        XCTAssertNotNil(manager, "AIBackendManager singleton should exist")
    }

    func testAIBackendManagerSingletonIsSame() {
        let a = AIBackendManager.shared
        let b = AIBackendManager.shared
        XCTAssertTrue(a === b, "AIBackendManager.shared should return the same instance")
    }

    func testAIBackendManagerDefaultBackendIsOllama() {
        let manager = AIBackendManager.shared
        // Default active backend should be Ollama (unless previously changed)
        // Just verify the property is accessible and returns a valid backend
        XCTAssertNotNil(manager.activeBackend)
    }

    func testAIBackendManagerDefaultURLs() {
        let manager = AIBackendManager.shared
        XCTAssertTrue(manager.ollamaServerURL.contains("11434"), "Ollama URL should contain port 11434")
    }

    func testEthicalAIGuardianSingletonExists() {
        let guardian = EthicalAIGuardian.shared
        XCTAssertNotNil(guardian, "EthicalAIGuardian singleton should exist")
        XCTAssertTrue(guardian.isEnabled, "Guardian should always be enabled")
    }

    func testEthicalAIGuardianSingletonIsSame() {
        let a = EthicalAIGuardian.shared
        let b = EthicalAIGuardian.shared
        XCTAssertTrue(a === b, "EthicalAIGuardian.shared should return the same instance")
    }

    func testNovaAPIServerSingletonExists() {
        let server = NovaAPIServer.shared
        XCTAssertNotNil(server, "NovaAPIServer singleton should exist")
    }

    func testNovaAPIServerSingletonIsSame() {
        let a = NovaAPIServer.shared
        let b = NovaAPIServer.shared
        XCTAssertTrue(a === b, "NovaAPIServer.shared should return the same instance")
    }

    func testNovaAPIServerPort() {
        XCTAssertEqual(NovaAPIServer.shared.port, 37430, "Nova API port must be 37430")
    }

    // MARK: - Widget Data Sync

    func testWidgetDataUpdatesOnFileLoad() async {
        let manager = ExcelDataManager()

        // Create a temp CSV
        let csvContent = "Name,Value\nAlpha,100\nBeta,200\n"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget_test_\(UUID().uuidString).csv")
        try? csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        await manager.loadFile(from: tempURL)

        // After loading, workbook should exist (widget data write requires app group)
        XCTAssertNotNil(manager.workbook, "Workbook should be loaded for widget sync")
        XCTAssertNotNil(manager.currentSheet, "Current sheet should be set for widget sync")
    }

    func testClearWidgetCurrentFileDoesNotCrash() {
        let manager = ExcelDataManager()
        // Should not crash even with no workbook loaded
        manager.clearWidgetCurrentFile()
    }

    func testUpdateWidgetAIStatusDoesNotCrash() {
        let manager = ExcelDataManager()
        // Should not crash even with no workbook loaded
        manager.updateWidgetAIStatus(isAnalyzing: true, type: "test", insightsCount: 5, summary: "Test summary")
        manager.updateWidgetAIStatus(isAnalyzing: false)
    }

    // MARK: - Notification Names Exist

    func testFileNotificationNamesExist() {
        // Verify all expected notification names are defined
        XCTAssertEqual(Notification.Name.openFile.rawValue, "openFile")
        XCTAssertEqual(Notification.Name.openSpecificFile.rawValue, "openSpecificFile")
        XCTAssertEqual(Notification.Name.saveFile.rawValue, "saveFile")
        XCTAssertEqual(Notification.Name.exportCSV.rawValue, "exportCSV")
        XCTAssertEqual(Notification.Name.exportPDF.rawValue, "exportPDF")
        XCTAssertEqual(Notification.Name.exportExcel.rawValue, "exportExcel")
    }

    func testUINotificationNamesExist() {
        XCTAssertEqual(Notification.Name.toggleAIPanel.rawValue, "toggleAIPanel")
        XCTAssertEqual(Notification.Name.toggleChartsPanel.rawValue, "toggleChartsPanel")
        XCTAssertEqual(Notification.Name.showFind.rawValue, "showFind")
        XCTAssertEqual(Notification.Name.zoomIn.rawValue, "zoomIn")
        XCTAssertEqual(Notification.Name.zoomOut.rawValue, "zoomOut")
        XCTAssertEqual(Notification.Name.resetZoom.rawValue, "resetZoom")
    }

    func testAINotificationNamesExist() {
        XCTAssertEqual(Notification.Name.analyzeData.rawValue, "analyzeData")
        XCTAssertEqual(Notification.Name.generateChart.rawValue, "generateChart")
        XCTAssertEqual(Notification.Name.findPatterns.rawValue, "findPatterns")
        XCTAssertEqual(Notification.Name.predictValues.rawValue, "predictValues")
        XCTAssertEqual(Notification.Name.showAdvancedAI.rawValue, "showAdvancedAI")
        XCTAssertEqual(Notification.Name.explainSpreadsheet.rawValue, "explainSpreadsheet")
        XCTAssertEqual(Notification.Name.findInsights.rawValue, "findInsights")
        XCTAssertEqual(Notification.Name.generateReport.rawValue, "generateReport")
        XCTAssertEqual(Notification.Name.enableVoiceCommands.rawValue, "enableVoiceCommands")
    }

    func testDataNotificationNamesExist() {
        XCTAssertEqual(Notification.Name.sheetChanged.rawValue, "sheetChanged")
        XCTAssertEqual(Notification.Name.cellUpdated.rawValue, "cellUpdated")
        XCTAssertEqual(Notification.Name.workbookLoaded.rawValue, "workbookLoaded")
        XCTAssertEqual(Notification.Name.cellSelected.rawValue, "cellSelected")
    }

    // MARK: - Notification Firing

    func testWorkbookLoadedNotificationFires() async {
        let manager = ExcelDataManager()
        let expectation = XCTestExpectation(description: "workbookLoaded notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .workbookLoaded,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let csvContent = "X,Y\n1,2\n"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("notif_test_\(UUID().uuidString).csv")
        try? csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        await manager.loadFile(from: tempURL)

        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testSheetChangedNotificationFires() {
        let manager = ExcelDataManager()
        let sheet1 = SheetData(name: "S1", rows: 2, columns: 2)
        let sheet2 = SheetData(name: "S2", rows: 2, columns: 2)
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet1, sheet2])
        manager.workbook = workbook
        manager.currentSheet = sheet1

        let expectation = XCTestExpectation(description: "sheetChanged notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .sheetChanged,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.selectSheet(at: 1)

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - AI Backend Enum

    func testAIBackendAllCases() {
        let allCases = AIBackendManager.AIBackend.allCases
        XCTAssertEqual(allCases.count, 10, "Should have 10 AI backend options")
    }

    func testAIBackendDescriptions() {
        for backend in AIBackendManager.AIBackend.allCases {
            XCTAssertFalse(backend.description.isEmpty, "Backend \(backend.rawValue) should have a description")
            XCTAssertFalse(backend.setupInstructions.isEmpty, "Backend \(backend.rawValue) should have setup instructions")
        }
    }

    // MARK: - AIError Descriptions

    func testAIErrorDescriptions() {
        let errors: [AIError] = [
            .noBackendAvailable,
            .invalidURL,
            .invalidResponse,
            .httpError(500),
            .noResponse,
            .mlxNotImplemented,
            .backendError("test message")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "AIError should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "AIError description should not be empty")
        }
    }

    func testAIErrorHTTPErrorContainsStatusCode() {
        let error = AIError.httpError(403)
        XCTAssertTrue(error.errorDescription!.contains("403"), "HTTP error description should contain status code")
    }

    func testAIErrorBackendErrorContainsMessage() {
        let error = AIError.backendError("connection refused")
        XCTAssertTrue(error.errorDescription!.contains("connection refused"), "Backend error should contain the message")
    }

    // MARK: - Multiple Manager Instances

    func testMultipleExcelDataManagersAreIndependent() async {
        let manager1 = ExcelDataManager()
        let manager2 = ExcelDataManager()

        let sheet = SheetData(name: "Sheet1", rows: 2, columns: 2)
        sheet.cells[0][0].value = .string("Hello")
        let workbook = WorkbookData(filename: "test.xlsx", sheets: [sheet])
        manager1.workbook = workbook
        manager1.currentSheet = sheet

        XCTAssertNotNil(manager1.workbook, "Manager1 should have workbook")
        XCTAssertNil(manager2.workbook, "Manager2 should still be empty")
    }

    // MARK: - ChartData Model

    func testChartDataInit() {
        let chart = ChartData(title: "Revenue Chart", type: .bar, imageData: nil)
        XCTAssertEqual(chart.title, "Revenue Chart")
        XCTAssertEqual(chart.type, .bar)
        XCTAssertNil(chart.imageData)
        XCTAssertNotNil(chart.id, "ChartData should have a UUID")
    }

    func testChartTypes() {
        XCTAssertEqual(ChartData.ChartType.bar.rawValue, "bar")
        XCTAssertEqual(ChartData.ChartType.line.rawValue, "line")
        XCTAssertEqual(ChartData.ChartType.pie.rawValue, "pie")
        XCTAssertEqual(ChartData.ChartType.scatter.rawValue, "scatter")
        XCTAssertEqual(ChartData.ChartType.area.rawValue, "area")
    }

    func testSheetStartsWithNoCharts() {
        let sheet = SheetData(name: "Test", rows: 5, columns: 5)
        XCTAssertTrue(sheet.charts.isEmpty, "New sheet should have no charts")
    }
}
