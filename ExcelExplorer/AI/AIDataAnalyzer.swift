//
//  AIDataAnalyzer.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import Foundation

@MainActor
class AIDataAnalyzer: ObservableObject {
    private let aiManager = AIBackendManager.shared

    // MARK: - Main Query Interface
    func queryData(_ query: String, sheet: SheetData) async throws -> String {
        let context = PromptBuilder.buildDataContext(sheet: sheet)

        let prompt = """
        You are analyzing an Excel spreadsheet for a user.

        SPREADSHEET DATA:
        \(context)

        USER QUERY: \(query)

        Provide a clear, specific answer referencing actual data from the spreadsheet.
        Be concise but thorough. Use markdown formatting for better readability.
        """

        let response = try await aiManager.generate(
            prompt: prompt,
            systemPrompt: "You are an expert data analyst helping users understand their spreadsheet data.",
            temperature: 0.3,
            maxTokens: 2000
        )

        return response
    }

    // MARK: - Specific Analysis Functions
    func summarizeSheet(_ sheet: SheetData) async throws -> String {
        let context = PromptBuilder.buildDataContext(sheet: sheet)

        let prompt = """
        Summarize this spreadsheet data:

        \(context)

        Provide:
        1. Overall summary (2-3 sentences)
        2. Key metrics and statistics
        3. Notable patterns or outliers
        4. Data quality observations
        """

        return try await aiManager.generate(
            prompt: prompt,
            systemPrompt: "You are an expert data analyst.",
            temperature: 0.3,
            maxTokens: 1500
        )
    }

    func findPatterns(_ sheet: SheetData) async throws -> String {
        let context = PromptBuilder.buildDataContext(sheet: sheet)

        let prompt = """
        Analyze this spreadsheet for interesting patterns and trends:

        \(context)

        Identify:
        1. Trends over time (if applicable)
        2. Correlations between columns
        3. Unusual patterns or anomalies
        4. Groupings or clusters
        """

        return try await aiManager.generate(
            prompt: prompt,
            systemPrompt: "You are an expert data scientist specializing in pattern recognition.",
            temperature: 0.3,
            maxTokens: 2000
        )
    }

    func predictValues(_ sheet: SheetData, targetColumn: String? = nil) async throws -> String {
        let context = PromptBuilder.buildDataContext(sheet: sheet)

        let prompt = """
        Based on this spreadsheet data, make predictions:

        \(context)

        \(targetColumn != nil ? "Focus on predicting values for the '\(targetColumn!)' column." : "Identify which columns are suitable for prediction.")

        Provide:
        1. Predicted values (if possible)
        2. Confidence level
        3. Reasoning behind predictions
        4. Limitations and assumptions
        """

        return try await aiManager.generate(
            prompt: prompt,
            systemPrompt: "You are an expert in data forecasting and predictive analytics.",
            temperature: 0.4,
            maxTokens: 2000
        )
    }

    func suggestChart(_ sheet: SheetData) async throws -> ChartSuggestion {
        let context = PromptBuilder.buildDataContext(sheet: sheet)

        let prompt = """
        Analyze this data and suggest the best chart type:

        \(context)

        Respond ONLY with valid JSON in this exact format:
        {
            "chartType": "bar" or "line" or "pie" or "scatter",
            "xColumn": "column name or index",
            "yColumn": "column name or index",
            "reasoning": "why this chart type is appropriate"
        }

        Choose the chart type that best represents the data structure and relationships.
        """

        let response = try await aiManager.generate(
            prompt: prompt,
            systemPrompt: "You are a data visualization expert. Respond ONLY with JSON.",
            temperature: 0.2,
            maxTokens: 500
        )

        return try parseChartSuggestion(response)
    }

    func explainColumn(_ sheet: SheetData, columnIndex: Int) async throws -> String {
        guard columnIndex >= 0 && columnIndex < sheet.columnCount else {
            throw AnalysisError.invalidColumn
        }

        let columnName = sheet.headers[columnIndex]
        let sampleValues = sheet.cells.prefix(20).map { $0[columnIndex].displayValue }

        let prompt = """
        Explain this column from a spreadsheet:

        Column Name: \(columnName)
        Sample Values: \(sampleValues.joined(separator: ", "))

        Provide:
        1. What this column represents
        2. Data type and format
        3. Potential use cases
        4. Data quality observations
        """

        return try await aiManager.generate(
            prompt: prompt,
            systemPrompt: "You are a data analyst explaining spreadsheet columns.",
            temperature: 0.3,
            maxTokens: 1000
        )
    }

    // MARK: - Helper Functions
    private func parseChartSuggestion(_ jsonString: String) throws -> ChartSuggestion {
        // Extract JSON from response (in case there's extra text)
        guard let jsonStart = jsonString.firstIndex(of: "{"),
              let jsonEnd = jsonString.lastIndex(of: "}") else {
            throw AnalysisError.invalidResponse
        }

        let jsonSubstring = jsonString[jsonStart...jsonEnd]
        let jsonData = Data(jsonSubstring.utf8)

        let decoder = JSONDecoder()
        return try decoder.decode(ChartSuggestion.self, from: jsonData)
    }
}

// MARK: - Prompt Builder
class PromptBuilder {
    static func buildDataContext(sheet: SheetData, sampleSize: Int = 20) -> String {
        var context = "### Spreadsheet: \(sheet.name)\n\n"
        context += "**Dimensions:** \(sheet.rowCount) rows × \(sheet.columnCount) columns\n\n"

        // Headers
        context += "**Column Headers:**\n"
        for (index, header) in sheet.headers.enumerated() {
            context += "\(index + 1). \(header)\n"
        }
        context += "\n"

        // Sample data (first N rows)
        context += "**Sample Data (first \(min(sampleSize, sheet.rowCount - 1)) rows):**\n\n"
        context += "| " + sheet.headers.joined(separator: " | ") + " |\n"
        context += "|" + String(repeating: " --- |", count: sheet.headers.count) + "\n"

        for row in 1..<min(sampleSize + 1, sheet.rowCount) {
            let rowValues = sheet.cells[row].map { $0.displayValue }
            context += "| " + rowValues.joined(separator: " | ") + " |\n"
        }
        context += "\n"

        // Column statistics
        context += "**Column Statistics:**\n\n"
        for (index, header) in sheet.headers.enumerated() {
            if let stats = sheet.columnStats(index) {
                context += "- **\(header):** \(stats.summary)\n"
            }
        }

        return context
    }
}

// MARK: - Chart Suggestion
struct ChartSuggestion: Codable {
    let chartType: String
    let xColumn: String
    let yColumn: String
    let reasoning: String
}

// MARK: - Analysis Errors
enum AnalysisError: Error {
    case invalidColumn
    case invalidResponse
    case noData

    var localizedDescription: String {
        switch self {
        case .invalidColumn:
            return "Invalid column index"
        case .invalidResponse:
            return "Could not parse AI response"
        case .noData:
            return "No data available for analysis"
        }
    }
}
