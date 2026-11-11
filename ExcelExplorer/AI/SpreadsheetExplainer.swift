//
//  SpreadsheetExplainer.swift
//  ExcelExplorer
//
//  AI-powered spreadsheet documentation generator
//  Created by Jordan Koch on 2026-01-27
//

import Foundation
import NovaAIKit

@MainActor
class SpreadsheetExplainer: ObservableObject {
    @Published var isProcessing = false
    @Published var lastExplanation: String?
    /// Where the last insights came from.
    @Published var lastInsightsSource: NovaAISource?

    private let ai: NovaAI

    init(ai: NovaAI? = nil) {
        self.ai = ai ?? AppAI.shared
    }

    /// Generate comprehensive explanation of spreadsheet
    func explainSpreadsheet(workbook: WorkbookData) async -> String {
        isProcessing = true
        defer { isProcessing = false }

        let prompt = """
        Analyze this Excel spreadsheet and provide a comprehensive explanation:

        Filename: \(workbook.filename)
        Sheets: \(workbook.sheets.count)
        Sheet Names: \(workbook.sheets.map { $0.name }.joined(separator: ", "))

        Data Overview:
        \(generateDataOverview(workbook: workbook))

        Please provide:
        1. Purpose: What is this spreadsheet for?
        2. Key Data: What data does it contain?
        3. Structure: How is it organized?
        4. Insights: Any notable patterns or relationships?
        5. Suggestions: Improvements or best practices

        Be concise but comprehensive.
        """

        let builtIn = BuiltInAnalysis.workbookOverview(workbook)
        let explanation = await ai.ask(prompt, system: "You are a data analyst expert at explaining spreadsheets clearly.",
                                       temperature: 0.4, maxTokens: 1000) { builtIn }.labeled
        lastExplanation = explanation
        return explanation
    }

    /// Find insights in data
    func findInsights(sheet: SheetData) async -> [Insight] {
        isProcessing = true
        defer { isProcessing = false }

        let prompt = """
        Analyze this dataset and find interesting insights:

        Sheet: \(sheet.name)
        Columns: \(sheet.headers.joined(separator: ", "))
        Rows: \(sheet.rowCount)

        Sample data:
        \(generateSampleData(sheet: sheet))

        Find insights such as:
        - Patterns and trends
        - Correlations between columns
        - Outliers or anomalies
        - Data quality issues
        - Potential relationships

        Respond with JSON array of insights:
        [{"insight": "description", "importance": "high|medium|low", "evidence": "supporting data"}]
        """

        let builtIn = Self.builtInInsights(sheet)
        let result = await ai.structured(
            [InsightJSON].self,
            NovaAIRequest(prompt: prompt, system: "You are a data scientist finding valuable insights.",
                          temperature: 0.5, maxTokens: 800),
            validate: ExcelAIValidators.insights
        ) { builtIn }
        lastInsightsSource = result.source
        return result.value.map { Insight(insight: $0.insight, importance: $0.importance ?? "medium", evidence: $0.evidence ?? "") }
    }

    /// Built-in insights: patterns and data-quality findings from the sheet's statistics.
    static func builtInInsights(_ sheet: SheetData) -> [InsightJSON] {
        let lines = NovaAIText.listItems(BuiltInAnalysis.patterns(sheet)).filter { !$0.hasSuffix(":") }
            + NovaAIText.listItems(BuiltInAnalysis.dataQuality(sheet)).filter { !$0.hasSuffix(":") && !$0.hasSuffix(": 0") }
        return lines.prefix(10).map { InsightJSON(insight: $0, importance: "medium", evidence: "Built-in statistics") }
    }

    /// Generate executive summary report
    func generateReport(workbook: WorkbookData) async -> String {
        isProcessing = true
        defer { isProcessing = false }

        let prompt = """
        Generate an executive summary report for this spreadsheet:

        \(generateDataOverview(workbook: workbook))

        Include:
        1. Executive Summary (2-3 sentences)
        2. Key Findings (3-5 bullet points)
        3. Data Quality Assessment
        4. Recommendations (2-3 actionable items)
        5. Next Steps

        Format as professional business report.
        """

        let builtIn = "Executive summary (built-in)\n\n" + BuiltInAnalysis.workbookOverview(workbook)
            + (workbook.sheets.first.map { "\n\n" + BuiltInAnalysis.dataQuality($0) } ?? "")
        return await ai.ask(prompt, system: "You write clear, professional business reports.",
                            temperature: 0.4, maxTokens: 1200) { builtIn }.labeled
    }

    private func generateDataOverview(workbook: WorkbookData) -> String {
        var overview = ""

        for sheet in workbook.sheets.prefix(3) { // Limit to first 3 sheets
            overview += """

            Sheet: \(sheet.name)
            Dimensions: \(sheet.rowCount) rows × \(sheet.columnCount) columns
            Headers: \(sheet.headers.prefix(10).joined(separator: ", "))

            """
        }

        return overview
    }

    private func generateSampleData(sheet: SheetData) -> String {
        let sampleRows = min(5, sheet.rowCount)
        var sample = ""

        for row in 0..<sampleRows {
            let rowData = sheet.cells[row].prefix(10).map { $0.displayValue }.joined(separator: ", ")
            sample += "Row \(row + 1): \(rowData)\n"
        }

        return sample
    }
}

// MARK: - Models

struct Insight: Identifiable {
    let id = UUID()
    let insight: String
    let importance: String
    let evidence: String

    var importanceLevel: Int {
        switch importance.lowercased() {
        case "high": return 3
        case "medium": return 2
        default: return 1
        }
    }
}
