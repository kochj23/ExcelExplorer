//
//  RelationshipDiscovery.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  AI-powered relationship discovery across sheets
//

import Foundation

@MainActor
class RelationshipDiscovery: ObservableObject {
    @Published var relationships: [DataRelationship] = []
    @Published var isAnalyzing: Bool = false
    @Published var error: String?

    private let aiManager = AIBackendManager.shared

    // MARK: - Discover Relationships
    func discoverRelationships(workbook: WorkbookData) async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        relationships.removeAll()

        // Find foreign key relationships
        let foreignKeys = await findForeignKeys(workbook: workbook)
        relationships.append(contentsOf: foreignKeys)

        // Find correlations
        let correlations = findCorrelations(workbook: workbook)
        relationships.append(contentsOf: correlations)

        // Find calculated dependencies
        let dependencies = findCalculatedDependencies(workbook: workbook)
        relationships.append(contentsOf: dependencies)

        // Get AI interpretation
        if !relationships.isEmpty {
            let interpretation = await getAIInterpretation(relationships: relationships)
            print("Relationship Analysis: \(interpretation)")
        }
    }

    // MARK: - Foreign Key Detection
    private func findForeignKeys(workbook: WorkbookData) async -> [DataRelationship] {
        var relationships: [DataRelationship] = []

        // Compare columns across sheets
        for (i, sheet1) in workbook.sheets.enumerated() {
            for (j, sheet2) in workbook.sheets.enumerated() where i < j {
                // Check each column in sheet1 against each column in sheet2
                for (col1Idx, col1Name) in sheet1.headers.enumerated() {
                    for (col2Idx, col2Name) in sheet2.headers.enumerated() {
                        let matchScore = calculateMatchScore(
                            sheet1: sheet1, column1: col1Idx,
                            sheet2: sheet2, column2: col2Idx
                        )

                        if matchScore > 0.7 {
                            relationships.append(DataRelationship(
                                type: .foreignKey,
                                sourceSheet: sheet1.name,
                                sourceColumn: col1Name,
                                targetSheet: sheet2.name,
                                targetColumn: col2Name,
                                strength: matchScore,
                                description: "Foreign key relationship between \(sheet1.name).\(col1Name) and \(sheet2.name).\(col2Name)"
                            ))
                        }
                    }
                }
            }
        }

        return relationships
    }

    // MARK: - Calculate Match Score
    private func calculateMatchScore(
        sheet1: SheetData, column1: Int,
        sheet2: SheetData, column2: Int
    ) -> Double {
        // Extract values from both columns
        var values1 = Set<String>()
        var values2 = Set<String>()

        for row in 1..<min(sheet1.rowCount, 100) {
            if let cell = sheet1.getCell(row: row, column: column1) {
                values1.insert(cell.displayValue)
            }
        }

        for row in 1..<min(sheet2.rowCount, 100) {
            if let cell = sheet2.getCell(row: row, column: column2) {
                values2.insert(cell.displayValue)
            }
        }

        // Calculate Jaccard similarity
        let intersection = values1.intersection(values2).count
        let union = values1.union(values2).count

        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    // MARK: - Correlation Detection
    private func findCorrelations(workbook: WorkbookData) -> [DataRelationship] {
        var relationships: [DataRelationship] = []

        for sheet in workbook.sheets {
            // Get numeric columns
            let numericColumns = sheet.headers.enumerated().compactMap { index, name -> (Int, String, [Double])? in
                guard let stats = sheet.columnStats(index), !stats.numbers.isEmpty else {
                    return nil
                }
                return (index, name, stats.numbers)
            }

            // Calculate correlations between numeric columns
            for i in 0..<numericColumns.count {
                for j in (i+1)..<numericColumns.count {
                    let col1 = numericColumns[i]
                    let col2 = numericColumns[j]

                    let correlation = calculateCorrelation(col1.2, col2.2)

                    if abs(correlation) > 0.7 {
                        let relationshipType: RelationshipType = correlation > 0 ? .positiveCorrelation : .negativeCorrelation

                        relationships.append(DataRelationship(
                            type: relationshipType,
                            sourceSheet: sheet.name,
                            sourceColumn: col1.1,
                            targetSheet: sheet.name,
                            targetColumn: col2.1,
                            strength: abs(correlation),
                            description: "\(col1.1) and \(col2.1) are \(correlation > 0 ? "positively" : "negatively") correlated (r = \(String(format: "%.2f", correlation)))"
                        ))
                    }
                }
            }
        }

        return relationships
    }

    // MARK: - Calculate Pearson Correlation
    private func calculateCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        let n = min(x.count, y.count)
        guard n > 1 else { return 0 }

        let xSlice = Array(x.prefix(n))
        let ySlice = Array(y.prefix(n))

        let xMean = xSlice.reduce(0, +) / Double(n)
        let yMean = ySlice.reduce(0, +) / Double(n)

        var numerator = 0.0
        var xDenom = 0.0
        var yDenom = 0.0

        for i in 0..<n {
            let xDiff = xSlice[i] - xMean
            let yDiff = ySlice[i] - yMean
            numerator += xDiff * yDiff
            xDenom += xDiff * xDiff
            yDenom += yDiff * yDiff
        }

        let denominator = sqrt(xDenom * yDenom)
        return denominator != 0 ? numerator / denominator : 0
    }

    // MARK: - Calculated Dependencies
    private func findCalculatedDependencies(workbook: WorkbookData) -> [DataRelationship] {
        var relationships: [DataRelationship] = []

        for sheet in workbook.sheets {
            for row in 1..<min(sheet.rowCount, 100) {
                for col in 0..<sheet.columnCount {
                    if let cell = sheet.getCell(row: row, column: col),
                       case .formula(let formula, _) = cell.value {
                        // Parse formula to find dependencies
                        let dependencies = parseFormulaDependencies(formula: formula)

                        for dep in dependencies {
                            relationships.append(DataRelationship(
                                type: .calculatedDependency,
                                sourceSheet: sheet.name,
                                sourceColumn: dep,
                                targetSheet: sheet.name,
                                targetColumn: sheet.headers[col],
                                strength: 1.0,
                                description: "\(sheet.headers[col]) depends on \(dep) (formula: \(formula))"
                            ))
                        }
                    }
                }
            }
        }

        return relationships
    }

    // MARK: - Parse Formula Dependencies
    private func parseFormulaDependencies(formula: String) -> [String] {
        // Extract cell references from formula
        let pattern = "[A-Z]+[0-9]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(formula.startIndex..., in: formula)
        let matches = regex.matches(in: formula, range: range)

        return matches.compactMap { match in
            if let range = Range(match.range, in: formula) {
                return String(formula[range])
            }
            return nil
        }
    }

    // MARK: - AI Interpretation
    private func getAIInterpretation(relationships: [DataRelationship]) async -> String {
        let summary = relationships.prefix(10).map { $0.description }.joined(separator: "\n")

        let prompt = """
        Analyze these data relationships and provide insights:

        \(summary)

        Provide a brief summary (3-4 sentences) focusing on:
        1. Most significant relationships
        2. Data quality implications
        3. Recommendations for data organization
        """

        do {
            return try await aiManager.generate(
                prompt: prompt,
                systemPrompt: "You are a data architect analyzing database relationships.",
                temperature: 0.3,
                maxTokens: 300
            )
        } catch {
            return "Found \(relationships.count) relationships across the workbook."
        }
    }
}

// MARK: - Data Structures

struct DataRelationship: Identifiable {
    let id = UUID()
    let type: RelationshipType
    let sourceSheet: String
    let sourceColumn: String
    let targetSheet: String
    let targetColumn: String
    let strength: Double // 0.0 to 1.0
    let description: String
}

enum RelationshipType {
    case foreignKey
    case positiveCorrelation
    case negativeCorrelation
    case calculatedDependency

    var icon: String {
        switch self {
        case .foreignKey: return "link"
        case .positiveCorrelation: return "arrow.up.right"
        case .negativeCorrelation: return "arrow.down.right"
        case .calculatedDependency: return "function"
        }
    }

    var color: String {
        switch self {
        case .foreignKey: return "blue"
        case .positiveCorrelation: return "green"
        case .negativeCorrelation: return "orange"
        case .calculatedDependency: return "purple"
        }
    }
}
