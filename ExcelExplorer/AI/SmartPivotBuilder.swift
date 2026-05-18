//
//  SmartPivotBuilder.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  AI-powered pivot table generation from natural language
//

import Foundation

@MainActor
class SmartPivotBuilder: ObservableObject {
    @Published var pivotTables: [PivotTable] = []
    @Published var isBuilding: Bool = false
    @Published var error: String?

    private let aiManager = AIBackendManager.shared

    // MARK: - Build Pivot Table from Natural Language
    func buildPivotTable(query: String, sheet: SheetData) async -> PivotTable? {
        isBuilding = true
        defer { isBuilding = false }

        // Use AI to parse the query
        guard let spec = await parsePivotQuery(query: query, sheet: sheet) else {
            error = "Could not parse pivot table query"
            return nil
        }

        // Build the pivot table
        let pivotTable = createPivotTable(spec: spec, sheet: sheet)
        pivotTables.append(pivotTable)

        return pivotTable
    }

    // MARK: - Parse Natural Language Query
    private func parsePivotQuery(query: String, sheet: SheetData) async -> PivotSpec? {
        let headers = sheet.headers.joined(separator: ", ")

        let prompt = """
        Parse this pivot table request into a JSON specification.

        Available columns: \(headers)

        User request: "\(query)"

        Respond with ONLY valid JSON in this format:
        {
            "rowDimensions": ["column1", "column2"],
            "columnDimensions": ["column3"],
            "values": [
                {"column": "column4", "aggregation": "sum"},
                {"column": "column5", "aggregation": "average"}
            ]
        }

        Aggregation types: sum, average, count, min, max

        Examples:
        - "Show total sales by region and product" → rows: [region, product], values: [sales: sum]
        - "Average price by category and month" → rows: [category], columns: [month], values: [price: average]
        """

        do {
            let response = try await aiManager.generate(
                prompt: prompt,
                systemPrompt: "You are a data analyst parsing pivot table requests. Respond ONLY with valid JSON.",
                temperature: 0.2,
                maxTokens: 500
            )

            return try parsePivotSpec(from: response)
        } catch {
            print("Error parsing pivot query: \(error)")
            return nil
        }
    }

    // MARK: - Parse JSON Response
    private func parsePivotSpec(from jsonString: String) throws -> PivotSpec? {
        // Extract JSON from response
        guard let jsonStart = jsonString.firstIndex(of: "{"),
              let jsonEnd = jsonString.lastIndex(of: "}") else {
            return nil
        }

        let jsonSubstring = jsonString[jsonStart...jsonEnd]
        let jsonData = Data(jsonSubstring.utf8)

        let decoder = JSONDecoder()
        return try decoder.decode(PivotSpec.self, from: jsonData)
    }

    // MARK: - Create Pivot Table
    private func createPivotTable(spec: PivotSpec, sheet: SheetData) -> PivotTable {
        var data: [PivotRow] = []

        // Get column indices
        let rowIndices = spec.rowDimensions.compactMap { dim in
            sheet.headers.firstIndex(of: dim)
        }
        let colIndices = spec.columnDimensions.compactMap { dim in
            sheet.headers.firstIndex(of: dim)
        }
        let valueIndices = spec.values.compactMap { val -> (Int, AggregationType)? in
            guard let index = sheet.headers.firstIndex(of: val.column) else { return nil }
            return (index, val.aggregation)
        }

        // Group data by row dimensions
        var groups: [String: [[CellData]]] = [:]

        for row in 1..<sheet.rowCount {
            let rowKey = rowIndices.map { sheet.cells[row][$0].displayValue }.joined(separator: "|")
            if groups[rowKey] == nil {
                groups[rowKey] = []
            }
            groups[rowKey]?.append(sheet.cells[row])
        }

        // Calculate aggregations for each group
        for (key, rows) in groups {
            let dimensions = key.split(separator: "|").map { String($0) }
            var values: [Double] = []

            for (valueIndex, aggregation) in valueIndices {
                let nums = rows.compactMap { row -> Double? in
                    if case .number(let num) = row[valueIndex].value {
                        return num
                    }
                    return nil
                }

                let aggregatedValue: Double
                switch aggregation {
                case .sum:
                    aggregatedValue = nums.reduce(0, +)
                case .average:
                    aggregatedValue = nums.isEmpty ? 0 : nums.reduce(0, +) / Double(nums.count)
                case .count:
                    aggregatedValue = Double(rows.count)
                case .min:
                    aggregatedValue = nums.min() ?? 0
                case .max:
                    aggregatedValue = nums.max() ?? 0
                }

                values.append(aggregatedValue)
            }

            data.append(PivotRow(dimensions: dimensions, values: values))
        }

        // Sort by first dimension
        data.sort { $0.dimensions.first ?? "" < $1.dimensions.first ?? "" }

        return PivotTable(
            name: "Pivot: \(spec.rowDimensions.joined(separator: ", "))",
            spec: spec,
            data: data,
            createdDate: Date()
        )
    }

    // MARK: - Quick Pivot Suggestions
    func suggestPivotTables(sheet: SheetData) -> [String] {
        let numericColumns = sheet.headers.enumerated().filter { index, _ in
            if let stats = sheet.columnStats(index), !stats.numbers.isEmpty {
                return true
            }
            return false
        }.map { $0.element }

        let categoricalColumns = sheet.headers.filter { header in
            !numericColumns.contains(header)
        }

        var suggestions: [String] = []

        if let firstCat = categoricalColumns.first, let firstNum = numericColumns.first {
            suggestions.append("Show total \(firstNum) by \(firstCat)")
        }

        if categoricalColumns.count >= 2, let firstNum = numericColumns.first {
            suggestions.append("Show \(firstNum) by \(categoricalColumns[0]) and \(categoricalColumns[1])")
        }

        if numericColumns.count >= 2, let firstCat = categoricalColumns.first {
            suggestions.append("Compare \(numericColumns[0]) and \(numericColumns[1]) by \(firstCat)")
        }

        return Array(suggestions.prefix(3))
    }
}

// MARK: - Data Structures

struct PivotSpec: Codable {
    let rowDimensions: [String]
    let columnDimensions: [String]
    let values: [ValueSpec]

    struct ValueSpec: Codable {
        let column: String
        let aggregation: AggregationType
    }
}

enum AggregationType: String, Codable {
    case sum
    case average
    case count
    case min
    case max
}

struct PivotTable: Identifiable {
    let id = UUID()
    let name: String
    let spec: PivotSpec
    let data: [PivotRow]
    let createdDate: Date

    var rowCount: Int { data.count }
    var columnCount: Int { spec.rowDimensions.count + spec.values.count }
}

struct PivotRow: Identifiable {
    let id = UUID()
    let dimensions: [String]
    let values: [Double]
}
