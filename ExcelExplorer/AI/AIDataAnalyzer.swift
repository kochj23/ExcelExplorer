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
        You are analyzing an Excel spreadsheet for a user in Excel Explorer, a macOS app.

        SPREADSHEET DATA:
        \(context)

        USER QUERY: \(query)

        IMPORTANT INSTRUCTIONS:
        - Provide direct answers and insights, NOT code or commands
        - DO NOT suggest Python, SQL, or programming code
        - DO NOT say "you can use X command" - just provide the analysis
        - Reference actual data from the spreadsheet with specific values
        - If the user asks to create something, describe what it would look like
        - Use markdown formatting for readability
        - Be concise but thorough (3-5 sentences)

        Example good responses:
        ✅ "The data shows sales peaked in March at $45,230, representing a 23% increase..."
        ✅ "There are 3 duplicate customer entries in rows 45, 67, and 89..."
        ✅ "Revenue by region: West $234k (40%), East $189k (32%), South $165k (28%)"

        Example bad responses:
        ❌ "You can use pandas.DataFrame.describe() to analyze this"
        ❌ "Run: df.groupby('region')['sales'].sum()"
        ❌ "Execute this SQL query: SELECT * FROM..."

        Provide insights, not instructions.
        """

        let response = try await aiManager.generate(
            prompt: prompt,
            systemPrompt: "You are an expert data analyst in Excel Explorer. Provide insights and analysis, never code or commands. You analyze data and provide direct answers.",
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
        2. Key metrics and statistics with actual values
        3. Notable patterns or outliers with specific examples
        4. Data quality observations

        IMPORTANT:
        - Provide direct insights, NOT code suggestions
        - Reference specific data values from the spreadsheet
        - Be actionable and clear
        - NO Python, SQL, or programming references
        """

        return try await aiManager.generate(
            prompt: prompt,
            systemPrompt: "You are an expert data analyst in Excel Explorer. Provide insights and analysis directly. Never suggest code or commands.",
            temperature: 0.3,
            maxTokens: 1500
        )
    }

    func findPatterns(_ sheet: SheetData) async throws -> String {
        let context = PromptBuilder.buildDataContext(sheet: sheet)

        let prompt = """
        Analyze this spreadsheet for interesting patterns and trends:

        \(context)

        Identify with specific examples:
        1. Trends over time (if applicable) - show actual values
        2. Correlations between columns - provide concrete examples
        3. Unusual patterns or anomalies - cite specific rows/values
        4. Groupings or clusters - describe what you found

        IMPORTANT:
        - Provide actual findings from the data, NOT analysis methods
        - Reference specific data values and row numbers
        - NO code suggestions (no Python, pandas, SQL, etc.)
        - Be direct and actionable
        """

        return try await aiManager.generate(
            prompt: prompt,
            systemPrompt: "You are an expert data scientist in Excel Explorer. Provide findings and patterns directly. Never suggest code or programming methods.",
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
        1. Predicted values (actual numbers, not formulas)
        2. Confidence level (percentage)
        3. Reasoning behind predictions with data references
        4. Limitations and assumptions

        IMPORTANT:
        - Provide actual predicted values, NOT prediction methods
        - NO code suggestions (no Python, scikit-learn, etc.)
        - Give concrete predictions like "Next value: $47,500 (±$3,200)"
        - Reference the actual data patterns you observed
        """

        return try await aiManager.generate(
            prompt: prompt,
            systemPrompt: "You are an expert in data forecasting in Excel Explorer. Provide actual predictions and insights, never code or technical methods.",
            temperature: 0.4,
            maxTokens: 2000
        )
    }

    func suggestChart(_ sheet: SheetData) async throws -> ChartSuggestion {
        let context = PromptBuilder.buildDataContext(sheet: sheet)

        // Identify numeric columns
        var numericColumns: [String] = []
        var categoricalColumns: [String] = []

        for (index, header) in sheet.headers.enumerated() {
            if let stats = sheet.columnStats(index), !stats.numbers.isEmpty {
                numericColumns.append(header)
            } else if !header.isEmpty {
                categoricalColumns.append(header)
            }
        }

        let prompt = """
        Analyze this data and suggest the best chart type:

        \(context)

        Numeric columns available: \(numericColumns.joined(separator: ", "))
        Categorical columns available: \(categoricalColumns.joined(separator: ", "))

        IMPORTANT RULES:
        1. Y-axis MUST be a numeric column (from the numeric list above)
        2. X-axis should be categorical (from categorical list) or numeric for trends
        3. For text-heavy data, suggest counting categories (e.g., count of items by category)
        4. Use column names EXACTLY as they appear in the headers

        Respond ONLY with valid JSON in this exact format:
        {
            "chartType": "bar",
            "xColumn": "exact column name from headers",
            "yColumn": "exact column name from numeric columns list",
            "reasoning": "why this works for the data"
        }

        Chart types: "bar" (categories), "line" (trends), "pie" (proportions)

        Example for vulnerability data:
        - X: "disney_rating" (shows Critical, High, Medium, Low)
        - Y: Use "count" as the yColumn name to trigger aggregation
        - Type: "bar"

        For categorical/text-heavy data (like vulnerability reports):
        - Use "bar" chart type
        - X: The categorical column (disney_rating, residual_risk, etc.)
        - Y: Use "count" to show frequency distribution
        """

        let response = try await aiManager.generate(
            prompt: prompt,
            systemPrompt: "You are a data visualization expert. Choose compatible columns. Y-axis must be numeric. Respond ONLY with JSON.",
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
