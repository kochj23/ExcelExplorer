//
//  SpreadsheetExplainer.swift
//  ExcelExplorer
//
//  AI-powered spreadsheet documentation generator
//  Created by Jordan Koch on 2026-01-27
//

import Foundation

@MainActor
class SpreadsheetExplainer: ObservableObject {
    @Published var isProcessing = false
    @Published var lastExplanation: String?

    private let aiManager = AIBackendManager.shared

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

        do {
            let explanation = try await aiManager.generate(
                prompt: prompt,
                systemPrompt: "You are a data analyst expert at explaining spreadsheets clearly.",
                temperature: 0.4,
                maxTokens: 1000
            )
            lastExplanation = explanation
            return explanation
        } catch {
            return "Failed to generate explanation: \(error.localizedDescription)"
        }
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

        do {
            let response = try await aiManager.generate(
                prompt: prompt,
                systemPrompt: "You are a data scientist finding valuable insights.",
                temperature: 0.5,
                maxTokens: 800
            )

            return parseInsights(from: response)
        } catch {
            return [Insight(insight: "Failed to analyze: \(error.localizedDescription)", importance: "low", evidence: "")]
        }
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

        do {
            let report = try await aiManager.generate(
                prompt: prompt,
                systemPrompt: "You write clear, professional business reports.",
                temperature: 0.4,
                maxTokens: 1200
            )
            return report
        } catch {
            return "Failed to generate report: \(error.localizedDescription)"
        }
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

    private func parseInsights(from response: String) -> [Insight] {
        // Try to parse JSON
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            // Fallback: parse as plain text
            return [Insight(insight: response, importance: "medium", evidence: "")]
        }

        return json.compactMap { dict in
            guard let insight = dict["insight"] else { return nil }
            return Insight(
                insight: insight,
                importance: dict["importance"] ?? "medium",
                evidence: dict["evidence"] ?? ""
            )
        }
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
