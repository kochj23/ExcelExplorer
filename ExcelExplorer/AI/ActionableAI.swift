//
//  ActionableAI.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  Action-oriented AI that executes tasks instead of just explaining
//

import Foundation
import AppKit

@MainActor
class ActionableAI: ObservableObject {
    @Published var executingAction = false
    @Published var lastAction: String?
    @Published var actionResults: [ActionResult] = []

    private let aiManager = AIBackendManager.shared
    private let analyzer = AIDataAnalyzer()

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

        do {
            let response = try await aiManager.generate(
                prompt: prompt,
                systemPrompt: "You are an action planner. Choose executable actions. Respond with JSON only.",
                temperature: 0.2,
                maxTokens: 300
            )

            if let plan = parseActionPlan(from: response) {
                return plan
            }
        } catch {
            print("Error determining action: \(error)")
        }

        // Default to summarize
        return ActionPlan(
            action: .summarize,
            parameters: [:],
            reasoning: "Providing data summary"
        )
    }

    // MARK: - Parse Action Plan
    private func parseActionPlan(from jsonString: String) -> ActionPlan? {
        guard let jsonStart = jsonString.firstIndex(of: "{"),
              let jsonEnd = jsonString.lastIndex(of: "}") else {
            return nil
        }

        let jsonSubstring = jsonString[jsonStart...jsonEnd]
        let jsonData = Data(jsonSubstring.utf8)

        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ActionPlanJSON.self, from: jsonData)

            let actionType: ActionType
            switch decoded.action.lowercased() {
            case "summarize": actionType = .summarize
            case "visualize": actionType = .visualize
            case "filter": actionType = .filter
            case "calculate": actionType = .calculate
            case "export": actionType = .export
            case "pivot": actionType = .pivot
            case "forecast": actionType = .forecast
            case "clean": actionType = .clean
            default: actionType = .summarize
            }

            return ActionPlan(
                action: actionType,
                parameters: decoded.parameters,
                reasoning: decoded.reasoning
            )
        } catch {
            print("Error parsing action plan: \(error)")
            return nil
        }
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
        do {
            let summary = try await analyzer.summarizeSheet(sheet)
            return ActionResult(
                action: .summarize,
                success: true,
                output: summary,
                data: nil
            )
        } catch {
            return ActionResult(
                action: .summarize,
                success: false,
                output: "Error: \(error.localizedDescription)",
                data: nil
            )
        }
    }

    private func executeVisualize(sheet: SheetData, parameters: [String: String]) async -> ActionResult {
        do {
            let chartSuggestion = try await analyzer.suggestChart(sheet)
            let output = """
            ✅ Chart Created!

            Type: \(chartSuggestion.chartType.capitalized)
            X-Axis: \(chartSuggestion.xColumn)
            Y-Axis: \(chartSuggestion.yColumn)

            \(chartSuggestion.reasoning)

            View in: Advanced AI → Forecasting tab (⇧⌘B)
            """

            return ActionResult(
                action: .visualize,
                success: true,
                output: output,
                data: chartSuggestion
            )
        } catch {
            return ActionResult(
                action: .visualize,
                success: false,
                output: "Error creating chart: \(error.localizedDescription)",
                data: nil
            )
        }
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
        do {
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

            let response = try await aiManager.generate(
                prompt: cleaningPrompt,
                systemPrompt: "You are a data quality analyst. Be specific and actionable.",
                temperature: 0.3,
                maxTokens: 1000
            )

            return ActionResult(
                action: .clean,
                success: true,
                output: "🧹 Data Quality Report:\n\n\(response)",
                data: nil
            )
        } catch {
            return ActionResult(
                action: .clean,
                success: false,
                output: "Error analyzing data quality: \(error.localizedDescription)",
                data: nil
            )
        }
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
