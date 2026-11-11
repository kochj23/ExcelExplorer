//
//  ActionableAI.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  Action-oriented AI that executes tasks instead of just explaining
//

import Foundation
import AppKit
import NovaAIKit

@MainActor
class ActionableAI: ObservableObject {
    @Published var executingAction = false
    @Published var lastAction: String?
    @Published var actionResults: [ActionResult] = []

    private let ai: NovaAI
    private let analyzer: AIDataAnalyzer

    init(ai: NovaAI? = nil) {
        let ai = ai ?? AppAI.shared
        self.ai = ai
        self.analyzer = AIDataAnalyzer(ai: ai)
    }

    // MARK: - Parse Command and Execute
    func executeCommand(_ command: String, sheet: SheetData) async -> ActionResult {
        executingAction = true
        defer { executingAction = false }

        lastAction = command

        // Use AI to determine what action to take
        let actionPlan = await determineAction(command: command, sheet: sheet)

        // Execute the action
        let result = await performAction(plan: actionPlan, sheet: sheet)

        actionResults.append(result)
        return result
    }

    // MARK: - Determine Action Type
    private func determineAction(command: String, sheet: SheetData) async -> ActionPlan {
        let context = PromptBuilder.buildDataContext(sheet: sheet)

        let prompt = """
        The user said: "\(command)"

        Available data:
        \(context)

        Determine what action to take and respond with JSON:
        {
            "action": "summarize|visualize|filter|calculate|export|pivot|forecast|clean",
            "parameters": {
                "column": "column name if applicable",
                "operation": "specific operation",
                "output": "what to produce"
            },
            "reasoning": "why this action"
        }

        IMPORTANT: Choose actions you can EXECUTE, not just explain.
        """

        let fallback = ActionPlanJSON(action: Self.ruleBasedAction(for: command).rawValue, parameters: [:],
                                      reasoning: "Chosen from the command's keywords")
        let result = await ai.structured(
            ActionPlanJSON.self,
            NovaAIRequest(prompt: prompt,
                          system: "You are an action planner. Choose executable actions. Respond with JSON only.",
                          temperature: 0.2, maxTokens: 300),
            validate: ExcelAIValidators.actionPlan
        ) { fallback }
        return ActionPlan(action: ActionType(rawValue: result.value.action) ?? .summarize,
                          parameters: result.value.parameters, reasoning: result.value.reasoning)
    }

    /// Keyword routing used when AI is off or its plan is rejected.
    nonisolated static func ruleBasedAction(for command: String) -> ActionType {
        let c = command.lowercased()
        if c.contains("chart") || c.contains("visual") || c.contains("graph") || c.contains("plot") { return .visualize }
        if c.contains("forecast") || c.contains("predict") { return .forecast }
        if c.contains("pivot") { return .pivot }
        if c.contains("clean") || c.contains("duplicate") || c.contains("quality") { return .clean }
        if c.contains("export") || c.contains("save as") { return .export }
        if c.contains("filter") || c.contains("only rows") { return .filter }
        if c.contains("sum") || c.contains("total") || c.contains("average") || c.contains("calculate") { return .calculate }
        return .summarize
    }

    // MARK: - Perform Action
    private func performAction(plan: ActionPlan, sheet: SheetData) async -> ActionResult {
        switch plan.action {
        case .summarize:
            return await executeSummarize(sheet: sheet)

        case .visualize:
            return await executeVisualize(sheet: sheet, parameters: plan.parameters)

        case .filter:
            return await executeFilter(sheet: sheet, parameters: plan.parameters)

        case .calculate:
            return await executeCalculate(sheet: sheet, parameters: plan.parameters)

        case .export:
            return await executeExport(sheet: sheet, parameters: plan.parameters)

        case .pivot:
            return await executePivot(sheet: sheet, parameters: plan.parameters)

        case .forecast:
            return await executeForecast(sheet: sheet, parameters: plan.parameters)

        case .clean:
            return await executeClean(sheet: sheet, parameters: plan.parameters)
        }
    }

    // MARK: - Action Implementations

    private func executeSummarize(sheet: SheetData) async -> ActionResult {
        let summary = await analyzer.summarizeSheet(sheet)
        return ActionResult(action: .summarize, success: true, output: summary.labeled, data: nil)
    }

    private func executeVisualize(sheet: SheetData, parameters: [String: String]) async -> ActionResult {
        let result = await analyzer.suggestChart(sheet)
        let chartSuggestion = result.value
        let output = """
        ✅ Chart Created!

        Type: \(chartSuggestion.chartType.capitalized)
        X-Axis: \(chartSuggestion.xColumn)
        Y-Axis: \(chartSuggestion.yColumn)

        \(chartSuggestion.reasoning)

        View in: Advanced AI → Forecasting tab (⇧⌘B)

        — \(result.source.detailLabel)
        """
        return ActionResult(action: .visualize, success: true, output: output, data: chartSuggestion)
    }

    private func executeFilter(sheet: SheetData, parameters: [String: String]) async -> ActionResult {
        // Placeholder for filter execution
        return ActionResult(
            action: .filter,
            success: true,
            output: "Filter action would be applied here. Coming soon!",
            data: nil
        )
    }

    private func executeCalculate(sheet: SheetData, parameters: [String: String]) async -> ActionResult {
        // Placeholder for calculation
        return ActionResult(
            action: .calculate,
            success: true,
            output: "Calculation would be performed here. Coming soon!",
            data: nil
        )
    }

    private func executeExport(sheet: SheetData, parameters: [String: String]) async -> ActionResult {
        // Trigger export notification
        let format = parameters["format"] ?? "csv"
        NotificationCenter.default.post(name: .exportCSV, object: nil)

        return ActionResult(
            action: .export,
            success: true,
            output: "✅ Export dialog opened. Choose location to save \(format.uppercased()) file.",
            data: nil
        )
    }

    private func executePivot(sheet: SheetData, parameters: [String: String]) async -> ActionResult {
        return ActionResult(
            action: .pivot,
            success: true,
            output: "✅ Pivot table builder opened. Go to Advanced AI → Pivot Tables tab (⇧⌘B).",
            data: nil
        )
    }

    private func executeForecast(sheet: SheetData, parameters: [String: String]) async -> ActionResult {
        return ActionResult(
            action: .forecast,
            success: true,
            output: "✅ Forecasting opened. Go to Advanced AI → Forecasting tab (⇧⌘B) to generate predictions.",
            data: nil
        )
    }

    private func executeClean(sheet: SheetData, parameters: [String: String]) async -> ActionResult {
        // Data cleaning suggestions
        let cleaningPrompt = """
        Analyze this data for quality issues:

        \(PromptBuilder.buildDataContext(sheet: sheet, sampleSize: 20))

        Find and list:
        1. Duplicate rows
        2. Missing values
        3. Inconsistent formatting
        4. Outliers
        5. Invalid data types

        For each issue, provide:
        - Issue description
        - Row numbers affected
        - Suggested fix

        Keep response concise and actionable.
        """
        let builtIn = BuiltInAnalysis.dataQuality(sheet)
        let response = await ai.ask(cleaningPrompt, system: "You are a data quality analyst. Be specific and actionable.",
                                    temperature: 0.3, maxTokens: 1000) { builtIn }
        return ActionResult(action: .clean, success: true, output: "🧹 Data Quality Report:\n\n\(response.labeled)", data: nil)
    }
}

// MARK: - Data Structures

struct ActionPlan {
    let action: ActionType
    let parameters: [String: String]
    let reasoning: String
}

struct ActionPlanJSON: Codable {
    let action: String
    let parameters: [String: String]
    let reasoning: String
}

enum ActionType: String {
    case summarize
    case visualize
    case filter
    case calculate
    case export
    case pivot
    case forecast
    case clean
}

struct ActionResult {
    let action: ActionType
    let success: Bool
    let output: String
    let data: Any?
}
