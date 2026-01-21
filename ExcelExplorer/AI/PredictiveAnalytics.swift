//
//  PredictiveAnalytics.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  Advanced predictive analytics and forecasting
//

import Foundation
import SwiftUI

// MARK: - Predictive Analytics Engine
@MainActor
class PredictiveAnalytics: ObservableObject {
    @Published var forecasts: [ForecastResult] = []
    @Published var isAnalyzing: Bool = false
    @Published var error: String?

    private let aiManager = AIBackendManager.shared

    // MARK: - Time Series Forecasting
    func generateForecast(
        data: [Double],
        labels: [String],
        periods: Int = 3,
        confidence: Double = 0.95
    ) async -> ForecastResult? {
        isAnalyzing = true
        defer { isAnalyzing = false }

        guard data.count >= 3 else {
            error = "Need at least 3 data points for forecasting"
            return nil
        }

        // Calculate trend using linear regression
        let trend = calculateLinearTrend(data: data)

        // Calculate seasonality
        let seasonality = detectSeasonality(data: data)

        // Generate forecasts
        var predictions: [ForecastPoint] = []
        let lastValue = data.last ?? 0

        for i in 1...periods {
            let timeStep = Double(data.count + i)

            // Trend component
            let trendValue = trend.slope * timeStep + trend.intercept

            // Seasonal adjustment
            let seasonalIndex = (data.count + i - 1) % seasonality.period
            let seasonalFactor = seasonality.factors[seasonalIndex % seasonality.factors.count]

            let prediction = trendValue * seasonalFactor

            // Calculate confidence interval
            let stdDev = calculateStandardDeviation(data: data)
            let zScore = confidence == 0.95 ? 1.96 : 2.576
            let margin = zScore * stdDev * sqrt(Double(i))

            predictions.append(ForecastPoint(
                period: labels.last ?? "Future",
                value: prediction,
                lowerBound: prediction - margin,
                upperBound: prediction + margin,
                confidence: confidence
            ))
        }

        // Get AI interpretation
        let interpretation = await getAIInterpretation(
            historical: data,
            forecasts: predictions
        )

        return ForecastResult(
            dataPoints: data,
            labels: labels,
            predictions: predictions,
            trend: trend,
            seasonality: seasonality,
            interpretation: interpretation
        )
    }

    // MARK: - Linear Regression
    private func calculateLinearTrend(data: [Double]) -> TrendLine {
        let n = Double(data.count)
        let x = Array(0..<data.count).map { Double($0) }

        let sumX = x.reduce(0, +)
        let sumY = data.reduce(0, +)
        let sumXY = zip(x, data).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n

        // Calculate R-squared
        let yMean = sumY / n
        let ssTot = data.map { pow($0 - yMean, 2) }.reduce(0, +)
        let ssRes = zip(x, data).map { pow($1 - (slope * $0 + intercept), 2) }.reduce(0, +)
        let rSquared = 1 - (ssRes / ssTot)

        return TrendLine(slope: slope, intercept: intercept, rSquared: rSquared)
    }

    // MARK: - Seasonality Detection
    private func detectSeasonality(data: [Double]) -> Seasonality {
        // Simple seasonality detection - look for repeating patterns
        let possiblePeriods = [4, 7, 12] // Quarterly, weekly, monthly
        var bestPeriod = 12
        var bestScore = 0.0

        for period in possiblePeriods where data.count >= period * 2 {
            var correlationSum = 0.0
            var count = 0

            for i in 0..<(data.count - period) {
                correlationSum += data[i] * data[i + period]
                count += 1
            }

            let score = correlationSum / Double(count)
            if score > bestScore {
                bestScore = score
                bestPeriod = period
            }
        }

        // Calculate seasonal factors
        var factors: [Double] = Array(repeating: 1.0, count: bestPeriod)
        if data.count >= bestPeriod {
            let mean = data.reduce(0, +) / Double(data.count)
            for i in 0..<bestPeriod {
                var sum = 0.0
                var count = 0
                var index = i
                while index < data.count {
                    sum += data[index] / mean
                    count += 1
                    index += bestPeriod
                }
                factors[i] = count > 0 ? sum / Double(count) : 1.0
            }
        }

        return Seasonality(period: bestPeriod, factors: factors)
    }

    // MARK: - Statistical Functions
    private func calculateStandardDeviation(data: [Double]) -> Double {
        let mean = data.reduce(0, +) / Double(data.count)
        let squaredDifferences = data.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(data.count)
        return sqrt(variance)
    }

    // MARK: - AI Interpretation
    private func getAIInterpretation(
        historical: [Double],
        forecasts: [ForecastPoint]
    ) async -> String {
        let trend = forecasts.first!.value > historical.last! ? "upward" : "downward"
        let avgChange = forecasts.map { $0.value }.reduce(0, +) / Double(forecasts.count)
        let percentChange = ((avgChange - historical.last!) / historical.last!) * 100

        let prompt = """
        Analyze this time series forecast:

        Historical data (last 5 points): \(historical.suffix(5).map { String(format: "%.2f", $0) }.joined(separator: ", "))
        Forecasted values: \(forecasts.map { String(format: "%.2f", $0.value) }.joined(separator: ", "))
        Trend: \(trend)
        Expected change: \(String(format: "%.1f", percentChange))%

        Provide a concise 2-3 sentence interpretation focusing on:
        1. What the forecast suggests
        2. Key factors driving the trend
        3. Confidence level and risks
        """

        do {
            return try await aiManager.generate(
                prompt: prompt,
                systemPrompt: "You are a data analyst providing forecast interpretations.",
                temperature: 0.3,
                maxTokens: 200
            )
        } catch {
            return "The forecast shows a \(trend) trend with an expected \(String(format: "%.1f", abs(percentChange)))% \(percentChange >= 0 ? "increase" : "decrease") based on historical patterns."
        }
    }

    // MARK: - Anomaly Detection
    func detectAnomalies(data: [Double]) -> [AnomalyPoint] {
        let mean = data.reduce(0, +) / Double(data.count)
        let stdDev = calculateStandardDeviation(data: data)
        let threshold = 2.5 // Standard deviations

        var anomalies: [AnomalyPoint] = []

        for (index, value) in data.enumerated() {
            let zScore = abs((value - mean) / stdDev)
            if zScore > threshold {
                anomalies.append(AnomalyPoint(
                    index: index,
                    value: value,
                    expectedValue: mean,
                    zScore: zScore,
                    severity: zScore > 3.0 ? .high : .medium
                ))
            }
        }

        return anomalies
    }
}

// MARK: - Data Structures

struct ForecastResult {
    let dataPoints: [Double]
    let labels: [String]
    let predictions: [ForecastPoint]
    let trend: TrendLine
    let seasonality: Seasonality
    let interpretation: String
}

struct ForecastPoint: Identifiable {
    let id = UUID()
    let period: String
    let value: Double
    let lowerBound: Double
    let upperBound: Double
    let confidence: Double
}

struct TrendLine {
    let slope: Double
    let intercept: Double
    let rSquared: Double

    var description: String {
        let direction = slope > 0 ? "upward" : "downward"
        let strength = rSquared > 0.7 ? "strong" : (rSquared > 0.4 ? "moderate" : "weak")
        return "\(strength.capitalized) \(direction) trend (R² = \(String(format: "%.2f", rSquared)))"
    }
}

struct Seasonality {
    let period: Int
    let factors: [Double]

    var description: String {
        let periodName: String
        switch period {
        case 4: periodName = "quarterly"
        case 7: periodName = "weekly"
        case 12: periodName = "monthly"
        default: periodName = "\(period)-period"
        }
        return "\(periodName.capitalized) seasonal pattern detected"
    }
}

struct AnomalyPoint: Identifiable {
    let id = UUID()
    let index: Int
    let value: Double
    let expectedValue: Double
    let zScore: Double
    let severity: Severity

    enum Severity {
        case medium, high

        var color: Color {
            switch self {
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
}
