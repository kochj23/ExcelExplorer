//
//  AdvancedAIFeaturesView.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  UI for advanced AI features
//

import SwiftUI
import Charts

struct AdvancedAIFeaturesView: View {
    @EnvironmentObject var dataManager: ExcelDataManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PredictiveAnalyticsView()
                .tabItem {
                    Label("Forecasting", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(0)

            PivotTableView()
                .tabItem {
                    Label("Pivot Tables", systemImage: "table")
                }
                .tag(1)

            RelationshipView()
                .tabItem {
                    Label("Relationships", systemImage: "link")
                }
                .tag(2)

            VoiceCommandView()
                .tabItem {
                    Label("Voice Commands", systemImage: "mic.fill")
                }
                .tag(3)

            SentimentAnalysisView()
                .tabItem {
                    Label("Sentiment", systemImage: "face.smiling")
                }
                .tag(4)
        }
        .frame(minWidth: 900, minHeight: 700)
    }
}

// MARK: - Predictive Analytics View
struct PredictiveAnalyticsView: View {
    @EnvironmentObject var dataManager: ExcelDataManager
    @StateObject private var analytics = PredictiveAnalytics()
    @State private var selectedColumnIndex: Int = 0
    @State private var forecastPeriods: Int = 3
    @State private var currentForecast: ForecastResult?

    var body: some View {
        HSplitView {
            // Left sidebar - Controls
            VStack(alignment: .leading, spacing: 16) {
                Text("Predictive Analytics")
                    .font(.title2)
                    .bold()

                if let sheet = dataManager.currentSheet {
                    // Column selector
                    Picker("Select Column", selection: $selectedColumnIndex) {
                        ForEach(sheet.headers.indices, id: \.self) { index in
                            Text(sheet.headers[index]).tag(index)
                        }
                    }
                    .pickerStyle(.menu)

                    // Forecast periods
                    Stepper("Forecast \(forecastPeriods) periods", value: $forecastPeriods, in: 1...12)

                    // Analyze button
                    Button(action: runForecast) {
                        Label(analytics.isAnalyzing ? "Analyzing..." : "Generate Forecast", systemImage: "chart.line.uptrend.xyaxis")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(analytics.isAnalyzing)

                    Divider()

                    // Results summary
                    if let forecast = currentForecast {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Forecast Results")
                                .font(.headline)

                            Text(forecast.trend.description)
                                .font(.caption)

                            Text(forecast.seasonality.description)
                                .font(.caption)

                            Text("Confidence: 95%")
                                .font(.caption)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cyan.opacity(0.1))
                        )
                    }
                } else {
                    Text("No spreadsheet loaded")
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 250, maxWidth: 300)

            // Right side - Visualization
            VStack {
                if let forecast = currentForecast {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Chart
                            ForecastChartView(forecast: forecast)
                                .frame(height: 300)

                            // Interpretation
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI Interpretation")
                                    .font(.headline)

                                Text(forecast.interpretation)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                            }

                            // Predictions table
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Forecasted Values")
                                    .font(.headline)

                                ForEach(forecast.predictions) { prediction in
                                    HStack {
                                        Text("Period \(prediction.period)")
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text(String(format: "%.2f", prediction.value))
                                                .bold()
                                            Text("[\(String(format: "%.2f", prediction.lowerBound)) - \(String(format: "%.2f", prediction.upperBound))]")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundStyle(.cyan.opacity(0.5))

                        Text("Generate Forecast")
                            .font(.title3)

                        Text("Select a numeric column and click 'Generate Forecast' to see time series predictions")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: 400)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func runForecast() {
        guard let sheet = dataManager.currentSheet else { return }

        // Extract numeric data from column
        var data: [Double] = []
        var labels: [String] = []

        for row in 1..<sheet.rowCount {
            if let cell = sheet.getCell(row: row, column: selectedColumnIndex),
               case .number(let num) = cell.value {
                data.append(num)
                labels.append("Period \(row)")
            }
        }

        guard data.count >= 3 else { return }

        Task {
            currentForecast = await analytics.generateForecast(
                data: data,
                labels: labels,
                periods: forecastPeriods
            )
        }
    }
}

// MARK: - Forecast Chart View
struct ForecastChartView: View {
    let forecast: ForecastResult

    var body: some View {
        VStack {
            Text("Historical Data & Forecast")
                .font(.headline)

            Chart {
                // Historical data
                ForEach(Array(forecast.dataPoints.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Period", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(.blue)
                }

                // Forecasted values
                ForEach(Array(forecast.predictions.enumerated()), id: \.element.id) { index, prediction in
                    let xValue = forecast.dataPoints.count + index

                    LineMark(
                        x: .value("Period", xValue),
                        y: .value("Value", prediction.value)
                    )
                    .foregroundStyle(.cyan)

                    // Confidence interval
                    AreaMark(
                        x: .value("Period", xValue),
                        yStart: .value("Lower", prediction.lowerBound),
                        yEnd: .value("Upper", prediction.upperBound)
                    )
                    .foregroundStyle(.cyan.opacity(0.2))
                }
            }
            .chartXAxis {
                AxisMarks(preset: .aligned)
            }
            .chartYAxis {
                AxisMarks(preset: .aligned)
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .padding()
    }
}

// MARK: - Pivot Table View
struct PivotTableView: View {
    @EnvironmentObject var dataManager: ExcelDataManager
    @StateObject private var pivotBuilder = SmartPivotBuilder()
    @State private var queryText: String = ""
    @State private var currentPivot: PivotTable?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Smart Pivot Table Builder")
                    .font(.title2)
                    .bold()

                Spacer()

                Button("Clear") {
                    currentPivot = nil
                    queryText = ""
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Query input
            VStack(spacing: 12) {
                TextField("Describe your pivot table (e.g., 'Show total sales by region and product')", text: $queryText)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .onSubmit {
                        buildPivot()
                    }

                Button(action: buildPivot) {
                    Label(pivotBuilder.isBuilding ? "Building..." : "Build Pivot Table", systemImage: "table")
                }
                .buttonStyle(.borderedProminent)
                .disabled(pivotBuilder.isBuilding || queryText.isEmpty)

                // Quick suggestions
                if let sheet = dataManager.currentSheet, currentPivot == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggestions:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(pivotBuilder.suggestPivotTables(sheet: sheet), id: \.self) { suggestion in
                            Button(suggestion) {
                                queryText = suggestion
                                buildPivot()
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundColor(.cyan)
                        }
                    }
                }
            }
            .padding()

            Divider()

            // Pivot table display
            if let pivot = currentPivot {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row
                        HStack(spacing: 0) {
                            ForEach(pivot.spec.rowDimensions, id: \.self) { dim in
                                Text(dim)
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 120)
                                    .padding(8)
                                    .background(Color.cyan.opacity(0.2))
                            }

                            ForEach(pivot.spec.values, id: \.column) { value in
                                Text("\(value.aggregation.rawValue.capitalized) of \(value.column)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 120)
                                    .padding(8)
                                    .background(Color.cyan.opacity(0.2))
                            }
                        }

                        // Data rows
                        ForEach(pivot.data) { row in
                            HStack(spacing: 0) {
                                ForEach(row.dimensions, id: \.self) { dim in
                                    Text(dim)
                                        .font(.system(size: 12))
                                        .frame(width: 120)
                                        .padding(8)
                                        .background(Color.secondary.opacity(0.05))
                                }

                                ForEach(row.values, id: \.self) { value in
                                    Text(String(format: "%.2f", value))
                                        .font(.system(size: 12))
                                        .frame(width: 120)
                                        .padding(8)
                                }
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "table")
                        .font(.system(size: 60))
                        .foregroundStyle(.cyan.opacity(0.5))

                    Text("Create Pivot Table")
                        .font(.title3)

                    Text("Describe what you want to see in natural language, and AI will build the pivot table for you")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 400)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func buildPivot() {
        guard let sheet = dataManager.currentSheet else { return }

        Task {
            currentPivot = await pivotBuilder.buildPivotTable(query: queryText, sheet: sheet)
        }
    }
}

// MARK: - Relationship View
struct RelationshipView: View {
    @EnvironmentObject var dataManager: ExcelDataManager
    @StateObject private var discovery = RelationshipDiscovery()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Data Relationship Discovery")
                    .font(.title2)
                    .bold()

                Spacer()

                Button(action: discoverRelationships) {
                    Label(discovery.isAnalyzing ? "Analyzing..." : "Discover Relationships", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(discovery.isAnalyzing)
            }
            .padding()

            Divider()

            // Relationships list
            if discovery.relationships.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "link.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(.cyan.opacity(0.5))

                    Text("Discover Data Relationships")
                        .font(.title3)

                    Text("Click 'Discover Relationships' to analyze your workbook and find connections between sheets and columns")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 400)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(discovery.relationships) { relationship in
                            RelationshipCard(relationship: relationship)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func discoverRelationships() {
        guard let workbook = dataManager.workbook else { return }

        Task {
            await discovery.discoverRelationships(workbook: workbook)
        }
    }
}

struct RelationshipCard: View {
    let relationship: DataRelationship

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: relationship.type.icon)
                .font(.title)
                .foregroundColor(colorForType(relationship.type.color))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(relationship.sourceSheet).\(relationship.sourceColumn) → \(relationship.targetSheet).\(relationship.targetColumn)")
                    .font(.headline)

                Text(relationship.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Strength: \(String(format: "%.0f%%", relationship.strength * 100))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }
}

// MARK: - Voice Command View
struct VoiceCommandView: View {
    @StateObject private var voiceHandler = VoiceCommandHandler()

    var body: some View {
        VStack(spacing: 20) {
            Text("Voice Commands")
                .font(.title2)
                .bold()

            // Authorization status
            if voiceHandler.authorizationStatus != .authorized {
                VStack(spacing: 16) {
                    Image(systemName: "mic.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("Microphone Access Required")
                        .font(.headline)

                    Text("Excel Explorer needs microphone permission to use voice commands")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    Button("Request Permission") {
                        voiceHandler.requestAuthorization()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Mic button
                Button(action: toggleListening) {
                    VStack(spacing: 12) {
                        Image(systemName: voiceHandler.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 60))
                            .foregroundColor(voiceHandler.isListening ? .red : .cyan)

                        Text(voiceHandler.isListening ? "Listening..." : "Tap to Speak")
                            .font(.headline)
                    }
                    .frame(width: 200, height: 200)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)

                // Transcribed text
                if !voiceHandler.transcribedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You said:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(voiceHandler.transcribedText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.cyan.opacity(0.1))
                            )
                    }
                    .frame(maxWidth: 500)
                }

                Divider()

                // Quick commands
                VStack(alignment: .leading, spacing: 12) {
                    Text("Example Commands:")
                        .font(.headline)

                    ForEach(VoiceCommandHandler.quickCommands, id: \.self) { command in
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.cyan)
                            Text(command)
                                .font(.caption)
                        }
                    }
                }
                .frame(maxWidth: 500)
            }

            Spacer()
        }
        .padding()
    }

    private func toggleListening() {
        if voiceHandler.isListening {
            voiceHandler.stopListening()
        } else {
            try? voiceHandler.startListening()
        }
    }
}

// MARK: - Sentiment Analysis View
struct SentimentAnalysisView: View {
    @EnvironmentObject var dataManager: ExcelDataManager
    @StateObject private var analyzer = SentimentAnalyzer()
    @State private var selectedColumnIndex: Int = 0
    @State private var currentAnalysis: SentimentAnalysis?

    var body: some View {
        HSplitView {
            // Left sidebar
            VStack(alignment: .leading, spacing: 16) {
                Text("Sentiment Analysis")
                    .font(.title2)
                    .bold()

                if let sheet = dataManager.currentSheet {
                    Picker("Select Text Column", selection: $selectedColumnIndex) {
                        ForEach(sheet.headers.indices, id: \.self) { index in
                            Text(sheet.headers[index]).tag(index)
                        }
                    }
                    .pickerStyle(.menu)

                    Button(action: analyzeSentiment) {
                        Label(analyzer.isAnalyzing ? "Analyzing..." : "Analyze Sentiment", systemImage: "face.smiling")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(analyzer.isAnalyzing)

                    if let analysis = currentAnalysis {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Results")
                                .font(.headline)

                            HStack {
                                Text("😊")
                                Text(String(format: "%.0f%%", analysis.distribution.positive * 100))
                                    .foregroundColor(.green)
                            }

                            HStack {
                                Text("😐")
                                Text(String(format: "%.0f%%", analysis.distribution.neutral * 100))
                                    .foregroundColor(.gray)
                            }

                            HStack {
                                Text("😞")
                                Text(String(format: "%.0f%%", analysis.distribution.negative * 100))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cyan.opacity(0.1))
                        )
                    }
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 250, maxWidth: 300)

            // Right side - Results
            VStack {
                if let analysis = currentAnalysis {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Summary
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Summary")
                                    .font(.headline)

                                Text(analysis.summary)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                            }

                            // Distribution chart
                            Text("Sentiment Distribution")
                                .font(.headline)

                            Chart {
                                BarMark(
                                    x: .value("Sentiment", "Positive"),
                                    y: .value("Percentage", analysis.distribution.positive * 100)
                                )
                                .foregroundStyle(.green)

                                BarMark(
                                    x: .value("Sentiment", "Neutral"),
                                    y: .value("Percentage", analysis.distribution.neutral * 100)
                                )
                                .foregroundStyle(.gray)

                                BarMark(
                                    x: .value("Sentiment", "Negative"),
                                    y: .value("Percentage", analysis.distribution.negative * 100)
                                )
                                .foregroundStyle(.red)
                            }
                            .frame(height: 200)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )

                            // Key themes
                            if !analysis.themes.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Key Themes")
                                        .font(.headline)

                                    ForEach(analysis.themes) { theme in
                                        HStack {
                                            Text(theme.name)
                                                .font(.caption)
                                            Spacer()
                                            Text("\(theme.count)")
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.secondary.opacity(0.2))
                                                )
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 60))
                            .foregroundStyle(.cyan.opacity(0.5))

                        Text("Analyze Text Sentiment")
                            .font(.title3)

                        Text("Select a text column and click 'Analyze Sentiment' to extract sentiment and key themes")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: 400)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func analyzeSentiment() {
        guard let sheet = dataManager.currentSheet else { return }

        Task {
            currentAnalysis = await analyzer.analyzeTextColumn(
                sheet: sheet,
                columnIndex: selectedColumnIndex
            )
        }
    }
}
