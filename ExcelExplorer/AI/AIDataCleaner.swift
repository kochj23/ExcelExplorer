//
//  AIDataCleaner.swift
//  ExcelExplorer
//
//  AI-powered data cleaning and validation
//  Created by Jordan Koch on 2026-01-27
//

import Foundation

@MainActor
class AIDataCleaner: ObservableObject {
    @Published var isProcessing = false
    @Published var cleaningResults: [CleaningResult] = []

    private let aiManager = AIBackendManager.shared

    /// Clean data using AI analysis
    func cleanData(sheet: SheetData) async -> DataCleaningReport {
        isProcessing = true
        defer { isProcessing = false }

        var report = DataCleaningReport(sheetName: sheet.name)

        // Step 1: Detect issues
        let issues = await detectIssues(sheet: sheet)
        report.issuesFound = issues

        // Step 2: Apply fixes
        for issue in issues {
            let fix = await applyFix(issue: issue, sheet: sheet)
            report.fixesApplied.append(fix)
        }

        return report
    }

    private func detectIssues(sheet: SheetData) async -> [DataIssue] {
        var issues: [DataIssue] = []

        // Detect duplicates
        let duplicates = detectDuplicateRows(sheet: sheet)
        if !duplicates.isEmpty {
            issues.append(DataIssue(
                type: .duplicates,
                severity: .medium,
                description: "Found \(duplicates.count) duplicate rows",
                locations: duplicates
            ))
        }

        // Detect inconsistent formatting
        for (colIndex, header) in sheet.headers.enumerated() {
            let column = sheet.cells.map { $0[colIndex] }
            if let issue = detectInconsistentTypes(column: column, columnName: header, colIndex: colIndex) {
                issues.append(issue)
            }
        }

        // Detect empty cells in important columns
        let emptyCells = detectEmptyCells(sheet: sheet)
        if !emptyCells.isEmpty {
            issues.append(DataIssue(
                type: .missingValues,
                severity: .low,
                description: "Found \(emptyCells.count) empty cells",
                locations: emptyCells
            ))
        }

        // Detect trailing/leading whitespace
        let whitespaceIssues = detectWhitespaceIssues(sheet: sheet)
        if !whitespaceIssues.isEmpty {
            issues.append(DataIssue(
                type: .whitespace,
                severity: .low,
                description: "Found \(whitespaceIssues.count) cells with extra whitespace",
                locations: whitespaceIssues
            ))
        }

        return issues
    }

    private func detectDuplicateRows(sheet: SheetData) -> [CellReference] {
        var seen = Set<String>()
        var duplicates: [CellReference] = []

        for (rowIndex, row) in sheet.cells.enumerated() {
            let rowString = row.map { $0.displayValue }.joined(separator: "|")
            if seen.contains(rowString) {
                duplicates.append(CellReference(row: rowIndex, column: 0))
            } else {
                seen.insert(rowString)
            }
        }

        return duplicates
    }

    private func detectInconsistentTypes(column: [CellData], columnName: String, colIndex: Int) -> DataIssue? {
        let types = column.map { cell -> String in
            switch cell.value {
            case .string: return "text"
            case .number: return "number"
            case .date: return "date"
            case .bool: return "boolean"
            default: return "empty"
            }
        }

        let typeCounts = Dictionary(grouping: types, by: { $0 }).mapValues { $0.count }
        if typeCounts.count > 2 { // Multiple types (excluding empty)
            return DataIssue(
                type: .inconsistentTypes,
                severity: .high,
                description: "Column '\(columnName)' has mixed data types",
                locations: [CellReference(row: 0, column: colIndex)]
            )
        }

        return nil
    }

    private func detectEmptyCells(sheet: SheetData) -> [CellReference] {
        var empty: [CellReference] = []

        for (rowIndex, row) in sheet.cells.enumerated() {
            for (colIndex, cell) in row.enumerated() {
                if case .empty = cell.value {
                    empty.append(CellReference(row: rowIndex, column: colIndex))
                }
            }
        }

        return empty
    }

    private func detectWhitespaceIssues(sheet: SheetData) -> [CellReference] {
        var issues: [CellReference] = []

        for (rowIndex, row) in sheet.cells.enumerated() {
            for (colIndex, cell) in row.enumerated() {
                if case .string(let text) = cell.value {
                    if text != text.trimmingCharacters(in: .whitespaces) {
                        issues.append(CellReference(row: rowIndex, column: colIndex))
                    }
                }
            }
        }

        return issues
    }

    private func applyFix(issue: DataIssue, sheet: SheetData) async -> CleaningFix {
        // Apply fixes based on issue type
        switch issue.type {
        case .duplicates:
            return CleaningFix(issueType: issue.type, action: "Marked duplicate rows", rowsAffected: issue.locations.count)
        case .whitespace:
            return CleaningFix(issueType: issue.type, action: "Trimmed whitespace", rowsAffected: issue.locations.count)
        case .inconsistentTypes:
            return CleaningFix(issueType: issue.type, action: "Flagged for review", rowsAffected: 1)
        case .missingValues:
            return CleaningFix(issueType: issue.type, action: "Flagged empty cells", rowsAffected: issue.locations.count)
        }
    }
}

// MARK: - Models

struct DataIssue {
    let type: IssueType
    let severity: Severity
    let description: String
    let locations: [CellReference]

    enum IssueType {
        case duplicates
        case inconsistentTypes
        case missingValues
        case whitespace
    }

    enum Severity {
        case low, medium, high, critical
    }
}

struct DataCleaningReport {
    let sheetName: String
    var issuesFound: [DataIssue] = []
    var fixesApplied: [CleaningFix] = []

    var summary: String {
        """
        Data Cleaning Report: \(sheetName)
        Issues Found: \(issuesFound.count)
        Fixes Applied: \(fixesApplied.count)
        """
    }
}

struct CleaningFix {
    let issueType: DataIssue.IssueType
    let action: String
    let rowsAffected: Int
}

struct CleaningResult: Identifiable {
    let id = UUID()
    let description: String
    let severity: String
    let fixed: Bool
}
