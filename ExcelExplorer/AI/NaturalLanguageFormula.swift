//
//  NaturalLanguageFormula.swift
//  ExcelExplorer
//
//  Convert natural language to Excel formulas using AI
//  Created by Jordan Koch on 2026-01-27
//

import Foundation

@MainActor
class NaturalLanguageFormula: ObservableObject {
    @Published var isProcessing = false
    @Published var lastFormula: String?

    private let aiManager = AIBackendManager.shared

    /// Convert natural language to Excel formula
    func convertToFormula(_ naturalLanguage: String, context: SheetData) async -> FormulaResult {
        isProcessing = true
        defer { isProcessing = false }

        let prompt = """
        Convert this natural language request to an Excel formula:
        "\(naturalLanguage)"

        Available columns: \(context.headers.joined(separator: ", "))
        Row count: \(context.rowCount)

        Respond with ONLY the Excel formula, nothing else.
        Examples:
        - "sum column B" → =SUM(B:B)
        - "average of sales" → =AVERAGE(B:B)
        - "count unique values in A" → =SUMPRODUCT(1/COUNTIF(A:A,A:A))

        Formula:
        """

        do {
            let formula = try await aiManager.generate(
                prompt: prompt,
                systemPrompt: "You are an Excel formula expert. Output ONLY the formula, no explanations.",
                temperature: 0.1,
                maxTokens: 200
            )

            let cleanedFormula = formula.trimmingCharacters(in: .whitespacesAndNewlines)
            lastFormula = cleanedFormula

            return FormulaResult(
                formula: cleanedFormula,
                explanation: "Generated from: '\(naturalLanguage)'",
                success: true
            )
        } catch {
            return FormulaResult(
                formula: "",
                explanation: "Failed to generate formula: \(error.localizedDescription)",
                success: false
            )
        }
    }

    /// Explain what a formula does
    func explainFormula(_ formula: String) async -> String {
        let prompt = """
        Explain this Excel formula in plain English:
        \(formula)

        Be concise and clear. One sentence if possible.
        """

        do {
            let explanation = try await aiManager.generate(
                prompt: prompt,
                systemPrompt: "You explain Excel formulas clearly.",
                temperature: 0.3,
                maxTokens: 150
            )
            return explanation
        } catch {
            return "Unable to explain formula"
        }
    }
}

struct FormulaResult {
    let formula: String
    let explanation: String
    let success: Bool
}
