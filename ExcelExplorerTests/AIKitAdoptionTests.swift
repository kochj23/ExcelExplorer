//
//  AIKitAdoptionTests.swift
//  ExcelExplorerTests
//
//  ExcelExplorer's contract with NovaAIKit, in the seven test categories (security, performance, retry, unit,
//  integration, functional, frame/UI state). NovaAIKit's own suite covers backends, transport and the Keychain;
//  these tests cover the app: every AI feature still works with AI off or offline, validators reject nonsense,
//  keys live under com.jkoch.excelexplorer.*, legacy settings/keys migrate, and no old AI client is left.
//  Never touches the real Keychain or network: in-memory settings/key stores and a stub URLProtocol.
//

import XCTest
import SwiftUI
import NovaAIKit
@testable import ExcelExplorer

// MARK: - Shared helpers

enum AITestSupport {
    /// Repo root, from this file's location (no hardcoded checkout path).
    static let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    static var appSources: URL { repoRoot.appendingPathComponent("ExcelExplorer") }

    @MainActor
    static func makeAI(_ settings: NovaAISettings = NovaAISettings(), keys: NovaAIMemoryKeyStore = NovaAIMemoryKeyStore(),
                       protocolClass: AnyClass = RefuseAllProtocol.self, freshInstall: Bool = false) -> NovaAI {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [protocolClass]
        var s = settings
        s.timeout = 5
        // freshInstall: nothing saved yet (what the one-time legacy import expects).
        return NovaAI(configuration: NovaAIConfiguration(appID: AppAI.appID, appName: AppAI.appName),
                      storage: freshInstall ? NovaAIMemoryStorage() : NovaAIMemoryStorage(s), keyStore: keys,
                      session: URLSession(configuration: cfg), sleep: { _ in })
    }

    /// A throwaway UserDefaults suite; `cleanup` removes its domain and the plist file it leaves behind.
    static func tempDefaults() -> (defaults: UserDefaults, cleanup: () -> Void) {
        let suite = "ExcelExplorerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (defaults, {
            defaults.removePersistentDomain(forName: suite)
            let plist = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Preferences/\(suite).plist")
            try? FileManager.default.removeItem(at: plist)
        })
    }

    /// Settings pinned to Ollama so the stub only sees `/api/chat`.
    static var ollamaOnly: NovaAISettings { NovaAISettings(backend: .ollama) }

    /// A small sales sheet: Region (text), Product (text), Sales (numeric), Units (numeric).
    static func salesSheet() -> SheetData {
        let rows: [[CellValue]] = [
            [.string("Region"), .string("Product"), .string("Sales"), .string("Units")],
            [.string("West"), .string("Widget"), .number(100), .number(10)],
            [.string("East"), .string("Widget"), .number(150), .number(14)],
            [.string("West"), .string("Gadget"), .number(200), .number(21)],
            [.string("South"), .string("Gadget"), .number(260), .number(25)],
            [.string("East"), .string("Gizmo"), .number(310), .number(30)],
            [.string("West"), .string("Gizmo"), .number(390), .number(41)],
        ]
        let sheet = SheetData(name: "Sales", rows: rows.count, columns: 4)
        for (r, row) in rows.enumerated() {
            for (c, v) in row.enumerated() { sheet.setCell(row: r, column: c, value: v) }
        }
        return sheet
    }

    static func workbook() -> WorkbookData {
        WorkbookData(filename: "sales.xlsx", sheets: [salesSheet()])
    }
}

/// Fails every request (backend down).
final class RefuseAllProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)) }
    override func stopLoading() {}
}

/// Answers Ollama `/api/chat` with scripted replies (a status code or reply text), in order; the last repeats.
final class ScriptedOllamaProtocol: URLProtocol {
    enum Step { case status(Int), reply(String) }
    private static let lock = NSLock()
    nonisolated(unsafe) private static var steps: [Step] = []
    nonisolated(unsafe) private static var calls = 0

    static func script(_ s: [Step]) { lock.lock(); steps = s; calls = 0; lock.unlock() }
    static var callCount: Int { lock.lock(); defer { lock.unlock() }; return calls }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        let isChat = request.url?.path.hasSuffix("/api/chat") == true
        var step = Step.status(404)
        if isChat {
            step = Self.steps.isEmpty ? .status(500) : Self.steps[min(Self.calls, Self.steps.count - 1)]
            Self.calls += 1
        }
        Self.lock.unlock()
        let url = request.url ?? URL(string: "http://localhost")!
        switch step {
        case .status(let code):
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("{}".utf8))
        case .reply(let text):
            let body = try! JSONSerialization.data(withJSONObject: [
                "model": "test-model", "message": ["role": "assistant", "content": text], "done": true,
            ] as [String: Any])
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                                                  headerFields: ["Content-Type": "application/json"])!,
                                cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

// MARK: - Security

final class AIKitSecurityTests: XCTestCase {
    func testKeychainServiceNames() {
        let c = NovaAIConfiguration(appID: "excelexplorer", appName: "Excel Explorer")
        XCTAssertEqual(c.keychainService(for: .openRouter), "com.jkoch.excelexplorer.openrouter")
        XCTAssertEqual(c.keychainService(for: .openAI), "com.jkoch.excelexplorer.openai")
        XCTAssertEqual(NovaAIConfiguration.keychainAccount, "apiKey")
    }

    @MainActor
    func testLegacyKeychainItemsMoveAndObsoleteSecretsAreDeleted() {
        let old = AppAI.legacyKeychainService
        let store = NovaAIMemoryKeyStore()
        store.write("sk-legacy-openai", service: old, account: NovaAILegacySettings.openAIKeyKeys[0])
        store.write("aws-secret", service: old, account: "AIBackend_AWS_SecretKey")
        store.write("g-key", service: old, account: "AIBackend_GoogleCloud_Key")
        store.write("sk-or-legacy", service: AppAI.legacyOpenRouterService, account: "apiKey")
        let ai = AITestSupport.makeAI(keys: store)
        let (defaults, cleanup) = AITestSupport.tempDefaults()
        defer { cleanup() }

        AppAI.migrateLegacy(ai, defaults: defaults)

        XCTAssertTrue(ai.hasAPIKey(for: .openAI))
        XCTAssertTrue(ai.hasAPIKey(for: .openRouter))
        XCTAssertNil(store.read(service: old, account: NovaAILegacySettings.openAIKeyKeys[0]), "old OpenAI item deleted after verified copy")
        XCTAssertNil(store.read(service: AppAI.legacyOpenRouterService, account: "apiKey"))
        XCTAssertNil(store.read(service: old, account: "AIBackend_AWS_SecretKey"), "removed backend's secret deleted")
        XCTAssertNil(store.read(service: old, account: "AIBackend_GoogleCloud_Key"))
    }

    @MainActor
    func testPlaintextKeysLeaveUserDefaults() {
        let (defaults, cleanup) = AITestSupport.tempDefaults()
        defer { cleanup() }
        defaults.set("sk-plaintext", forKey: NovaAILegacySettings.openAIKeyKeys[0])
        defaults.set("azure", forKey: "AIBackend_Azure_Key")
        defaults.set(["prompt log"], forKey: "AIGuardian_UsageLog")
        let ai = AITestSupport.makeAI()

        AppAI.migrateLegacy(ai, defaults: defaults)

        XCTAssertNil(defaults.object(forKey: NovaAILegacySettings.openAIKeyKeys[0]))
        XCTAssertNil(defaults.object(forKey: "AIBackend_Azure_Key"))
        XCTAssertNil(defaults.object(forKey: "AIGuardian_UsageLog"))
        XCTAssertTrue(ai.hasAPIKey(for: .openAI), "the plaintext key now lives in the (in-memory) Keychain")
    }

    @MainActor
    func testKeyIsNeverSentOverPlainHTTP() async {
        let keys = NovaAIMemoryKeyStore()
        var s = NovaAISettings(backend: .openAI)
        s.setURL("http://example.invalid/v1", for: .openAI)
        let ai = AITestSupport.makeAI(s, keys: keys)
        ai.setAPIKey("sk-test", for: .openAI)
        do {
            _ = try await ai.complete(NovaAIRequest(prompt: "hi"))
            XCTFail("expected insecureTransport")
        } catch {
            XCTAssertEqual(error as? NovaAIError, .insecureTransport("example.invalid"))
        }
    }

    func testAnalysisValidatorRejectsCode() {
        XCTAssertThrowsError(try ExcelAIValidators.analysisText("Run:\n```python\nimport pandas as pd\n```"))
        XCTAssertThrowsError(try ExcelAIValidators.analysisText("Use df.groupby('region')"))
        XCTAssertEqual(try ExcelAIValidators.analysisText("  West leads with 690 in sales. "), "West leads with 690 in sales.")
    }

    func testVoiceFileInfoStripsPaths() throws {
        let f = try ExcelAIValidators.fileInfo(FileInfo(filename: "../../etc/passwd.xlsx", location: "/etc", fileType: "exe"))
        XCTAssertEqual(f.filename, "passwd.xlsx")
        XCTAssertNil(f.location)
        XCTAssertNil(f.fileType)
    }
}

// MARK: - Performance

final class AIKitPerformanceTests: XCTestCase {
    @MainActor
    func testAIOffAnswersImmediately() async {
        let ai = AITestSupport.makeAI(NovaAISettings(enabled: false))
        let analyzer = AIDataAnalyzer(ai: ai)
        let sheet = AITestSupport.salesSheet()
        let start = Date()
        for _ in 0..<50 { _ = await analyzer.summarizeSheet(sheet) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0, "built-in fallback must not wait on the network")
    }

    func testBuiltInAnalysisScalesToLargeSheets() {
        let sheet = SheetData(name: "Big", rows: 2001, columns: 3)
        sheet.setCell(row: 0, column: 0, value: .string("Group"))
        sheet.setCell(row: 0, column: 1, value: .string("A"))
        sheet.setCell(row: 0, column: 2, value: .string("B"))
        for r in 1...2000 {
            sheet.setCell(row: r, column: 0, value: .string("g\(r % 7)"))
            sheet.setCell(row: r, column: 1, value: .number(Double(r)))
            sheet.setCell(row: r, column: 2, value: .number(Double(r * 2)))
        }
        measure {
            _ = BuiltInAnalysis.summary(sheet)
            _ = BuiltInAnalysis.patterns(sheet)
        }
    }

    @MainActor
    func testOfflineFallbackDoesNotHang() async {
        let ai = AITestSupport.makeAI(AITestSupport.ollamaOnly)
        let start = Date()
        let r = await AIDataAnalyzer(ai: ai).findPatterns(AITestSupport.salesSheet())
        XCTAssertFalse(r.isAI)
        XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    }
}

// MARK: - Retry

final class AIKitRetryTests: XCTestCase {
    @MainActor
    func testTransientServerErrorIsRetried() async {
        ScriptedOllamaProtocol.script([.status(503), .reply("West leads with 690 in sales.")])
        let ai = AITestSupport.makeAI(AITestSupport.ollamaOnly, protocolClass: ScriptedOllamaProtocol.self)
        let r = await AIDataAnalyzer(ai: ai).summarizeSheet(AITestSupport.salesSheet())
        XCTAssertTrue(r.isAI)
        XCTAssertEqual(r.value, "West leads with 690 in sales.")
        XCTAssertEqual(ScriptedOllamaProtocol.callCount, 2)
    }

    @MainActor
    func testRejectedReplyIsAskedOnceMoreThenFallsBack() async {
        ScriptedOllamaProtocol.script([.reply("```python\nimport pandas\n```")])
        let ai = AITestSupport.makeAI(AITestSupport.ollamaOnly, protocolClass: ScriptedOllamaProtocol.self)
        let r = await AIDataAnalyzer(ai: ai).summarizeSheet(AITestSupport.salesSheet())
        XCTAssertFalse(r.isAI)
        XCTAssertEqual(ScriptedOllamaProtocol.callCount, 2, "one re-ask with the complaint, then the built-in result")
        if case .fallback(.validationFailed) = r.source {} else { XCTFail("expected validationFailed, got \(r.source)") }
    }

    @MainActor
    func testRejectedChartIsCorrectedOnRetry() async {
        ScriptedOllamaProtocol.script([
            .reply(#"{"chartType":"bar","xColumn":"Nope","yColumn":"Sales","reasoning":"x"}"#),
            .reply(#"{"chartType":"BAR","xColumn":"region","yColumn":"Sales","reasoning":"by region"}"#),
        ])
        let ai = AITestSupport.makeAI(AITestSupport.ollamaOnly, protocolClass: ScriptedOllamaProtocol.self)
        let r = await AIDataAnalyzer(ai: ai).suggestChart(AITestSupport.salesSheet())
        XCTAssertTrue(r.isAI)
        XCTAssertEqual(r.value.xColumn, "Region", "case-insensitive match clamps to the real header")
        XCTAssertEqual(r.value.chartType, "bar")
    }
}

// MARK: - Unit

final class AIKitUnitTests: XCTestCase {
    func testBackendCatalog() {
        XCTAssertEqual(NovaAIBackend.allCases.count, 9)
        for b in NovaAIBackend.allCases {
            XCTAssertFalse(b.displayName.isEmpty)
            XCTAssertFalse(b.summary.isEmpty)
        }
        XCTAssertTrue(NovaAISettings().url(for: .ollama).contains("11434"))
        XCTAssertEqual(NovaAISettings().backend, .auto)
    }

    func testFormulaValidator() throws {
        XCTAssertEqual(try ExcelAIValidators.formula("Formula:\n`=SUM(B:B)`"), "=SUM(B:B)")
        XCTAssertThrowsError(try ExcelAIValidators.formula("You can sum column B"))
        XCTAssertThrowsError(try ExcelAIValidators.formula("=SUM((B:B)"))
        XCTAssertThrowsError(try ExcelAIValidators.formula("=CONCAT(\"a)"))
    }

    func testChartValidatorClampsAndRejects() throws {
        let v = ExcelAIValidators.chart(headers: ["Region", "Sales"], numeric: ["Sales"])
        let ok = try v(ChartSuggestion(chartType: "donut", xColumn: "region", yColumn: "count", reasoning: "**why**"))
        XCTAssertEqual(ok.chartType, "bar")
        XCTAssertEqual(ok.xColumn, "Region")
        XCTAssertEqual(ok.reasoning, "why")
        XCTAssertThrowsError(try v(ChartSuggestion(chartType: "bar", xColumn: "Region", yColumn: "Region", reasoning: "")))
        XCTAssertThrowsError(try v(ChartSuggestion(chartType: "bar", xColumn: "Missing", yColumn: "Sales", reasoning: "")))
    }

    func testPivotValidatorKeepsOnlyRealColumns() throws {
        let v = ExcelAIValidators.pivot(headers: ["Region", "Sales"])
        let spec = try v(PivotSpec(rowDimensions: ["region", "Ghost"], columnDimensions: ["Ghost"],
                                   values: [.init(column: "Sales", aggregation: .sum), .init(column: "Ghost", aggregation: .max)]))
        XCTAssertEqual(spec.rowDimensions, ["Region"])
        XCTAssertEqual(spec.columnDimensions, [])
        XCTAssertEqual(spec.values.map(\.column), ["Sales"])
        XCTAssertThrowsError(try v(PivotSpec(rowDimensions: ["Ghost"], columnDimensions: [], values: [.init(column: "Sales", aggregation: .sum)])))
    }

    func testThemeAndInsightAndActionValidators() throws {
        let themes = try ExcelAIValidators.themes(total: 10)([
            Theme(name: "Price", count: 99, sentiment: "angry"), Theme(name: "price", count: 1, sentiment: "positive"),
            Theme(name: " ", count: 1, sentiment: "neutral"),
        ])
        XCTAssertEqual(themes.count, 1)
        XCTAssertEqual(themes[0].count, 10)
        XCTAssertEqual(themes[0].sentiment, "neutral")
        let insights = try ExcelAIValidators.insights([InsightJSON(insight: "x", importance: "URGENT", evidence: nil)])
        XCTAssertEqual(insights[0].importance, "medium")
        XCTAssertThrowsError(try ExcelAIValidators.actionPlan(ActionPlanJSON(action: "rm -rf", parameters: [:], reasoning: "")))
        XCTAssertEqual(try ExcelAIValidators.actionPlan(ActionPlanJSON(action: "Pivot", parameters: [:], reasoning: "")).action, "pivot")
    }

    func testForecastValidatorRejectsInventedFigures() {
        let v = ExcelAIValidators.forecastText(source: "Forecasted values: 410.50, 431.25")
        XCTAssertNoThrow(try v("Values rise to 431.25 over the next periods."))
        XCTAssertThrowsError(try v("Values rise to 999.99."))
    }

    func testBuiltInRules() {
        let sheet = AITestSupport.salesSheet()
        XCTAssertEqual(BuiltInAnalysis.numericColumns(sheet).map(\.name), ["Sales", "Units"])
        XCTAssertEqual(BuiltInAnalysis.formula(for: "total of Sales", headers: sheet.headers), "=SUM(C:C)")
        XCTAssertEqual(BuiltInAnalysis.formula(for: "average of column d", headers: sheet.headers), "=AVERAGE(D:D)")
        XCTAssertNil(BuiltInAnalysis.formula(for: "make it pretty", headers: sheet.headers))
        XCTAssertEqual(BuiltInAnalysis.columnLetter(27), "AB")
        let pivot = BuiltInAnalysis.pivotSpec(query: "average Units by Product", sheet: sheet)
        XCTAssertEqual(pivot?.rowDimensions.first, "Product")
        XCTAssertEqual(pivot?.values.first?.column, "Units")
        XCTAssertEqual(pivot?.values.first?.aggregation, .average)
        XCTAssertEqual(ActionableAI.ruleBasedAction(for: "plot sales"), .visualize)
        XCTAssertEqual(VoiceCommandHandler.ruleBasedFileInfo("open sales.xlsx from downloads").filename, "sales.xlsx")
    }
}

// MARK: - Integration

final class AIKitIntegrationTests: XCTestCase {
    @MainActor
    func testValidAIReplyIsUsedAndLabelled() async {
        ScriptedOllamaProtocol.script([.reply("Sales rise steadily from 100 to 390.")])
        let ai = AITestSupport.makeAI(AITestSupport.ollamaOnly, protocolClass: ScriptedOllamaProtocol.self)
        let r = await AIDataAnalyzer(ai: ai).queryData("trend?", sheet: AITestSupport.salesSheet())
        XCTAssertTrue(r.isAI)
        XCTAssertTrue(r.source.detailLabel.hasPrefix("AI · Ollama"))
        XCTAssertEqual(ai.status.state, .online)
    }

    @MainActor
    func testPivotFromAIBuildsTable() async {
        ScriptedOllamaProtocol.script([.reply(#"{"rowDimensions":["Region"],"columnDimensions":[],"values":[{"column":"Sales","aggregation":"sum"}]}"#)])
        let ai = AITestSupport.makeAI(AITestSupport.ollamaOnly, protocolClass: ScriptedOllamaProtocol.self)
        let builder = SmartPivotBuilder(ai: ai)
        let table = await builder.buildPivotTable(query: "total sales by region", sheet: AITestSupport.salesSheet())
        XCTAssertEqual(table?.spec.rowDimensions, ["Region"])
        XCTAssertEqual(builder.lastSource?.isAI, true)
    }

    @MainActor
    func testLegacySettingsMigrate() {
        let (defaults, cleanup) = AITestSupport.tempDefaults()
        defer { cleanup() }
        defaults.set("Ollama", forKey: "AIBackend_Active")
        defaults.set("http://studio.local:11434", forKey: "AIBackend_OllamaURL")
        defaults.set("qwen3:8b", forKey: "AIBackend_OllamaModel")
        defaults.set("http://nova.local:18792", forKey: "LLM_novaGatewayURL")
        defaults.set("openai/gpt-4o", forKey: "LLM_selectedOpenRouterModel")
        defaults.set(true, forKey: "LLM_useAllLocalModels")
        let ai = AITestSupport.makeAI(freshInstall: true)

        AppAI.migrateLegacy(ai, defaults: defaults)

        XCTAssertEqual(ai.settings.backend, .ollama)
        XCTAssertEqual(ai.settings.url(for: .ollama), "http://studio.local:11434")
        XCTAssertEqual(ai.settings.model(for: .ollama), "qwen3:8b")
        XCTAssertEqual(ai.settings.url(for: .novaGateway), "http://nova.local:18792")
        XCTAssertEqual(ai.settings.model(for: .openRouter), "openai/gpt-4o")
        XCTAssertNil(defaults.object(forKey: "LLM_useAllLocalModels"), "balancer keys removed")

        // Idempotent: a second run changes nothing.
        let before = ai.settings
        AppAI.migrateLegacy(ai, defaults: defaults)
        XCTAssertEqual(ai.settings, before)
    }

    func testImageGenerationKeepsItsOwnServers() {
        let (defaults, cleanup) = AITestSupport.tempDefaults()
        defer { cleanup() }
        defaults.set("http://comfy.local:8188", forKey: "AIBackend_ComfyUIURL")
        let e = ImageBackendEndpoints(defaults: defaults)
        XCTAssertEqual(e.comfyUIServerURL, "http://comfy.local:8188")
        XCTAssertEqual(e.automatic1111ServerURL, "http://localhost:7860")
    }
}

// MARK: - Functional

final class AIKitFunctionalTests: XCTestCase {
    /// Feature 1+2: AI off → every AI feature still produces its built-in result, and nothing is sent.
    @MainActor
    func testEveryFeatureWorksWithAIOff() async {
        ScriptedOllamaProtocol.script([.reply("should not be called")])
        let ai = AITestSupport.makeAI(NovaAISettings(enabled: false), protocolClass: ScriptedOllamaProtocol.self)
        await assertEveryFeatureFallsBack(ai, expectedReason: .disabled)
        XCTAssertEqual(ScriptedOllamaProtocol.callCount, 0)
        XCTAssertEqual(ai.status.state, .off)
    }

    /// Feature 2+7: every backend down → built-in result, no hang.
    @MainActor
    func testEveryFeatureFallsBackWhenOffline() async {
        let ai = AITestSupport.makeAI(AITestSupport.ollamaOnly)
        await assertEveryFeatureFallsBack(ai, expectedReason: nil)
    }

    @MainActor
    private func assertEveryFeatureFallsBack(_ ai: NovaAI, expectedReason: NovaAIFallbackReason?, line: UInt = #line) async {
        let sheet = AITestSupport.salesSheet()
        let analyzer = AIDataAnalyzer(ai: ai)

        for r in [await analyzer.queryData("what are the totals?", sheet: sheet), await analyzer.summarizeSheet(sheet),
                  await analyzer.findPatterns(sheet), await analyzer.predictValues(sheet)] {
            XCTAssertFalse(r.isAI, line: line)
            XCTAssertFalse(r.value.isEmpty, line: line)
            if let expectedReason { XCTAssertEqual(r.source, .fallback(expectedReason), line: line) }
        }
        let summary = await analyzer.summarizeSheet(sheet)
        XCTAssertTrue(summary.value.contains("Sales"), line: line)
        let column = try? await analyzer.explainColumn(sheet, columnIndex: 2)
        XCTAssertEqual(column?.isAI, false, line: line)

        let chart = await analyzer.suggestChart(sheet)
        XCTAssertFalse(chart.isAI, line: line)
        XCTAssertTrue(sheet.headers.contains(chart.value.xColumn), line: line)
        XCTAssertTrue(["Sales", "Units", "count"].contains(chart.value.yColumn), line: line)

        let pivot = await SmartPivotBuilder(ai: ai).buildPivotTable(query: "total sales by region", sheet: sheet)
        XCTAssertEqual(pivot?.spec.rowDimensions.first, "Region", line: line)
        XCTAssertEqual(pivot?.spec.values.first?.column, "Sales", line: line)

        let action = await ActionableAI(ai: ai).executeCommand("chart the sales", sheet: sheet)
        XCTAssertEqual(action.action, .visualize, line: line)
        XCTAssertTrue(action.success, line: line)

        let formula = await NaturalLanguageFormula(ai: ai).convertToFormula("sum of Units", context: sheet)
        XCTAssertEqual(formula.formula, "=SUM(D:D)", line: line)
        let explanation = await NaturalLanguageFormula(ai: ai).explainFormula("=SUM(D:D)")
        XCTAssertFalse(explanation.isEmpty, line: line)

        let forecast = await PredictiveAnalytics(ai: ai).generateForecast(data: [1, 2, 3, 4, 5], labels: ["a", "b", "c", "d", "e"])
        XCTAssertNotNil(forecast?.interpretation, line: line)
        XCTAssertTrue(forecast?.interpretation.contains("Built-in") ?? false, line: line)

        let discovery = RelationshipDiscovery(ai: ai)
        await discovery.discoverRelationships(workbook: AITestSupport.workbook())
        XCTAssertNil(discovery.error, line: line)

        let explainer = SpreadsheetExplainer(ai: ai)
        let explained = await explainer.explainSpreadsheet(workbook: AITestSupport.workbook())
        XCTAssertTrue(explained.contains("sales.xlsx"), line: line)
        let insights = await explainer.findInsights(sheet: sheet)
        XCTAssertFalse(insights.isEmpty, line: line)
        let report = await explainer.generateReport(workbook: AITestSupport.workbook())
        XCTAssertFalse(report.isEmpty, line: line)
    }

    @MainActor
    func testSentimentWorksWithAIOff() async {
        let sheet = SheetData(name: "Reviews", rows: 5, columns: 1)
        sheet.setCell(row: 0, column: 0, value: .string("Comment"))
        sheet.setCell(row: 1, column: 0, value: .string("Great price and great delivery"))
        sheet.setCell(row: 2, column: 0, value: .string("Terrible delivery, broken box"))
        sheet.setCell(row: 3, column: 0, value: .string("Price was fair, delivery fine"))
        sheet.setCell(row: 4, column: 0, value: .string("Love the price"))
        let ai = AITestSupport.makeAI(NovaAISettings(enabled: false))
        let analysis = await SentimentAnalyzer(ai: ai).analyzeTextColumn(sheet: sheet, columnIndex: 0)
        XCTAssertEqual(analysis?.totalEntries, 4)
        XCTAssertFalse(analysis?.themes.isEmpty ?? true, "keyword themes stand in for AI themes")
        XCTAssertTrue(analysis?.summary.contains("4 entries") ?? false)
    }
}

// MARK: - Frame / UI state

final class AIKitFrameTests: XCTestCase {
    @MainActor
    func testAppAISingletonAndConfiguration() {
        XCTAssertTrue(AppAI.shared === AppAI.shared)
        XCTAssertEqual(AppAI.shared.configuration.appID, "excelexplorer")
        XCTAssertFalse(AppAI.settingsFooter.isEmpty)
    }

    @MainActor
    func testStatusReflectsToggle() {
        let ai = AITestSupport.makeAI()
        ai.isEnabled = false
        XCTAssertEqual(ai.status.state, .off)
        ai.isEnabled = true
        XCTAssertEqual(ai.status.state, .unknown)
        XCTAssertEqual(NovaAIStatusIndicator.color(.off), .gray)
    }

    @MainActor
    func testOfflineCallMarksStatusOffline() async {
        let ai = AITestSupport.makeAI(AITestSupport.ollamaOnly)
        _ = await AIDataAnalyzer(ai: ai).summarizeSheet(AITestSupport.salesSheet())
        XCTAssertEqual(ai.status.state, .offline)
        XCTAssertEqual(ai.status.lastSource?.isAI, false)
    }

    func testSourceLabels() {
        XCTAssertEqual(NovaAISource.fallback(.disabled).detailLabel, "Built-in analysis (AI is off)")
        XCTAssertEqual(NovaAISource.fallback(.unavailable("x")).detailLabel, "Built-in analysis (AI unavailable)")
        XCTAssertTrue(NovaAISource.ai(backend: .ollama, model: "m").detailLabel.contains("Ollama"))
        let r = NovaAIResult(value: "Body", source: .fallback(.disabled))
        XCTAssertEqual(r.labeled, "Body\n\n— Built-in analysis (AI is off)")
    }

    @MainActor
    func testViewsBuild() {
        for view in [AnyView(SettingsView()), AnyView(AISettingsSheet()),
                     AnyView(AIStatusHeader(showAISettings: .constant(false))),
                     AnyView(AIConversationView().environmentObject(ExcelDataManager()))] {
            let controller = NSHostingController(rootView: view)
            let size = controller.sizeThatFits(in: CGSize(width: 1300, height: 900))
            XCTAssertGreaterThan(size.width, 0)
        }
    }

    /// No old AI client code is left in the app's sources.
    func testNoLegacyAIClientInSources() throws {
        let fm = FileManager.default
        // Built by concatenation so this file doesn't match the ADOPTION.md leftover grep itself.
        let banned = ["AIBackend" + "Manager", "EthicalAI" + "Guardian", "AIBackend" + "StatusMenu", "OPENAI_" + "API_KEY",
                      "LLMBackendManager", "OpenRouterProvider", "UnifiedAICapabilities"]
        guard let e = fm.enumerator(at: AITestSupport.appSources, includingPropertiesForKeys: nil) else {
            return XCTFail("cannot list sources at \(AITestSupport.appSources.path)")
        }
        var scanned = 0
        for case let url as URL in e where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8).replacingOccurrences(of: "migrateFromLegacy" + "AIBackend" + "Manager", with: "")
            scanned += 1
            for b in banned { XCTAssertFalse(text.contains(b), "\(url.lastPathComponent) still references \(b)") }
        }
        XCTAssertGreaterThan(scanned, 20)
    }
}
