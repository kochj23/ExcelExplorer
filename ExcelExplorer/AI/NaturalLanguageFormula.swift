//
//  NaturalLanguageFormula.swift
//  ExcelExplorer
//
//  Convert natural language to Excel formulas using AI
//  Created by Jordan Koch on 2026-01-27
//

import Foundation
import NovaAIKit

@MainActor
class NaturalLanguageFormula: ObservableObject {
    @Published var isProcessing = false
    @Published var lastFormula: String?

    private let ai: NovaAI

    init(ai: NovaAI? = nil) {
        self.ai = ai ?? AppAI.shared
    }

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

        let builtIn = BuiltInAnalysis.formula(for: naturalLanguage, headers: context.headers) ?? ""
        let result = await ai.ask(prompt, system: "You are an Excel formula expert. Output ONLY the formula, no explanations.",
                                  temperature: 0.1, maxTokens: 200, validate: ExcelAIValidators.formula) { builtIn }
        guard !result.value.isEmpty else {
            return FormulaResult(
                formula: "",
                explanation: "Could not build a formula. Without AI, try \"sum/average/count/min/max of <column name or letter>\".",
                success: false
            )
        }
        lastFormula = result.value
        return FormulaResult(
            formula: result.value,
            explanation: "Generated from: '\(naturalLanguage)' — \(result.source.detailLabel)",
            success: true
        )
    }

    /// Explain what a formula does
    func explainFormula(_ formula: String) async -> String {
        let prompt = """
        Explain this Excel formula in plain English:
        \(formula)

        Be concise and clear. One sentence if possible.
        """

        return await ai.ask(prompt, system: "You explain Excel formulas clearly.", temperature: 0.3, maxTokens: 150,
                            validate: ExcelAIValidators.shortText(maxCharacters: 600)) {
            "Formula explanations need AI (it is off or unavailable)."
        }.value
    }
}

struct FormulaResult {
    let formula: String
    let explanation: String
    let success: Bool
}
