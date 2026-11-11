//
//  AIConversationView.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import SwiftUI
import NovaAIKit

struct AIConversationView: View {
    @EnvironmentObject var dataManager: ExcelDataManager
    @StateObject private var analyzer = AIDataAnalyzer()
    @StateObject private var explainer = SpreadsheetExplainer()
    @StateObject private var formulaBuilder = NaturalLanguageFormula()
    @StateObject private var imageService = ImageGenerationService()
    @StateObject private var chartGenerator = ChartImageGenerator()

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isGenerating: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with AI Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(.cyan)

                        Text("AI Data Analysis")
                            .font(.headline)
                    }

                    // AI Status (click to re-check)
                    NovaAIStatusIndicator(ai: AppAI.shared)
                }

                Spacer()

                Button(action: copyConversation) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy entire conversation")

                Button(action: exportConversation) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .help("Export conversation to file")

                Button(action: clearChat) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear conversation")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            EmptyStateView()
                        } else {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }

                        if isGenerating {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Quick actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickActionButton(title: "Summarize & Visualize", icon: "chart.bar.doc.horizontal", color: .cyan, action: {
                        summarizeAndVisualize()
                    })

                    QuickActionButton(title: "Summarize", icon: "doc.text", action: {
                        sendQuickQuery("Summarize this spreadsheet data in 3-4 sentences")
                    })

                    QuickActionButton(title: "Find Patterns", icon: "waveform.path.ecg", action: {
                        sendQuickQuery("Find interesting patterns and trends in this data")
                    })

                    QuickActionButton(title: "Generate Chart", icon: "chart.bar", action: {
                        sendQuickQuery("What type of chart would best visualize this data?")
                    })

                    QuickActionButton(title: "Predict Values", icon: "arrow.up.forward", action: {
                        sendQuickQuery("Based on the data trends, predict the next values")
                    })

                    QuickActionButton(title: "Data Quality", icon: "checkmark.shield", action: {
                        sendQuickQuery("Analyze data quality: find errors, duplicates, missing values, and inconsistencies")
                    })

                    QuickActionButton(title: "Explain Columns", icon: "questionmark.circle", action: {
                        sendQuickQuery("Explain what each column represents and its data type")
                    })

                    QuickActionButton(title: "Create Pivot", icon: "table", action: {
                        sendQuickQuery("Suggest the best pivot table for this data")
                    })
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // Input area
            HStack(spacing: 12) {
                TextField("Ask about your data...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(inputText.isEmpty && !isGenerating ? Color.secondary : Color.cyan)
                }
                .buttonStyle(.borderless)
                .disabled(inputText.isEmpty && !isGenerating)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 300)
        // The AI menu's commands run here, in the conversation.
        .onReceive(NotificationCenter.default.publisher(for: .analyzeData)) { _ in
            sendQuickQuery("Summarize this spreadsheet data in 3-4 sentences")
        }
        .onReceive(NotificationCenter.default.publisher(for: .explainSpreadsheet)) { _ in
            runWorkbookCommand("Explain this spreadsheet") { await explainer.explainSpreadsheet(workbook: $0) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findInsights)) { _ in
            runInsights()
        }
        .onReceive(NotificationCenter.default.publisher(for: .naturalLanguageFormula)) { _ in
            inputText = "Formula: "
        }
        .onReceive(NotificationCenter.default.publisher(for: .findPatterns)) { _ in
            sendQuickQuery("Find interesting patterns and trends in this data")
        }
        .onReceive(NotificationCenter.default.publisher(for: .generateChart)) { _ in
            summarizeAndVisualize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .generateReport)) { _ in
            runWorkbookCommand("Generate a report") { await explainer.generateReport(workbook: $0) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .predictValues)) { _ in
            sendQuickQuery("Based on the data trends, predict the next values")
        }
        .onReceive(NotificationCenter.default.publisher(for: .cleanData)) { _ in
            sendQuickQuery("Analyze data quality: find errors, duplicates, missing values, and inconsistencies")
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessage(content: inputText, role: .user)
        messages.append(userMessage)

        let query = inputText
        inputText = ""

        isGenerating = true

        guard let sheet = dataManager.currentSheet else {
            messages.append(ChatMessage(content: "No spreadsheet is currently loaded", role: .assistant))
            isGenerating = false
            return
        }

        // "Formula: <request>" → an Excel formula (validated: starts with =, balanced).
        if query.lowercased().hasPrefix("formula:") {
            let request = String(query.dropFirst("formula:".count)).trimmingCharacters(in: .whitespaces)
            Task {
                let result = await formulaBuilder.convertToFormula(request, context: sheet)
                let text = result.success ? "\(result.formula)\n\n\(result.explanation)" : result.explanation
                messages.append(ChatMessage(content: text, role: .assistant))
                isGenerating = false
            }
            return
        }

        Task {
            let response = await analyzer.queryData(query, sheet: sheet)
            messages.append(ChatMessage(content: response.value, role: .assistant, source: response.source.detailLabel))
            isGenerating = false
        }
    }

    /// Runs a whole-workbook command (explain/report) and posts the labelled result.
    private func runWorkbookCommand(_ title: String, _ run: @escaping (WorkbookData) async -> String) {
        guard let workbook = dataManager.workbook else {
            messages.append(ChatMessage(content: "No spreadsheet is currently loaded", role: .assistant))
            return
        }
        messages.append(ChatMessage(content: title, role: .user))
        isGenerating = true
        Task {
            let text = await run(workbook)
            messages.append(ChatMessage(content: text, role: .assistant))
            isGenerating = false
        }
    }

    private func runInsights() {
        guard let sheet = dataManager.currentSheet else {
            messages.append(ChatMessage(content: "No spreadsheet is currently loaded", role: .assistant))
            return
        }
        messages.append(ChatMessage(content: "Find insights", role: .user))
        isGenerating = true
        Task {
            let insights = await explainer.findInsights(sheet: sheet)
            let text = insights.sorted { $0.importanceLevel > $1.importanceLevel }
                .map { "• [\($0.importance)] \($0.insight)" + ($0.evidence.isEmpty ? "" : " — \($0.evidence)") }
                .joined(separator: "\n")
            messages.append(ChatMessage(content: "💎 Insights:\n\n\(text)", role: .assistant,
                                        source: explainer.lastInsightsSource?.detailLabel))
            isGenerating = false
        }
    }

    private func sendQuickQuery(_ query: String) {
        inputText = query
        sendMessage()
    }

    private func clearChat() {
        messages.removeAll()
    }

    private func copyConversation() {
        let conversationText = messages.map { message in
            let role = message.role == .user ? "You" : "AI"
            let timestamp = message.timestamp.formatted(date: .abbreviated, time: .shortened)
            return "[\(timestamp)] \(role):\n\(message.content)\n"
        }.joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(conversationText, forType: .string)
    }

    private func exportConversation() {
        let conversationText = messages.map { message in
            let role = message.role == .user ? "You" : "AI"
            let timestamp = message.timestamp.formatted(date: .abbreviated, time: .shortened)
            return "[\(timestamp)] \(role):\n\(message.content)\n"
        }.joined(separator: "\n")

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "AI_Conversation_\(Date().formatted(date: .numeric, time: .omitted)).txt"

        if panel.runModal() == .OK, let url = panel.url {
            try? conversationText.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func summarizeAndVisualize() {
        guard let sheet = dataManager.currentSheet else {
            let errorMessage = ChatMessage(content: "No spreadsheet is currently loaded", role: .assistant)
            messages.append(errorMessage)
            return
        }

        let userMessage = ChatMessage(content: "Summarize this data and create a visualization", role: .user)
        messages.append(userMessage)

        isGenerating = true

        Task {
            // Step 1: Generate summary
            let summary = await analyzer.summarizeSheet(sheet)

            await MainActor.run {
                let summaryMessage = ChatMessage(content: "📊 Data Summary:\n\n\(summary.value)", role: .assistant,
                                                 source: summary.source.detailLabel)
                messages.append(summaryMessage)
            }

            // Step 2: Suggest chart type (validated: real columns, numeric Y)
            let chartResult = await analyzer.suggestChart(sheet)
            let chartSuggestion = chartResult.value

            await MainActor.run {
                let chartMessage = ChatMessage(
                    content: "📈 Visualization Recommendation:\n\nChart Type: \(chartSuggestion.chartType.capitalized)\nX-Axis: \(chartSuggestion.xColumn)\nY-Axis: \(chartSuggestion.yColumn)\n\nReasoning: \(chartSuggestion.reasoning)\n\nI can create this chart in the Advanced AI Features panel (⇧⌘B → Forecasting tab).",
                    role: .assistant,
                    source: chartResult.source.detailLabel
                )
                messages.append(chartMessage)
            }

            // Step 3: Generate data visualization using Swift Charts (readable text!)
            await MainActor.run {
                let statusMessage = ChatMessage(
                    content: "🎨 Creating visualization chart...",
                    role: .assistant
                )
                messages.append(statusMessage)
            }

            // Generate chart using Swift Charts (native, with readable text)
            let chartImage = await MainActor.run {
                chartGenerator.generateChartImage(
                    sheet: sheet,
                    chartType: chartSuggestion.chartType,
                    xColumn: chartSuggestion.xColumn,
                    yColumn: chartSuggestion.yColumn,
                    title: "\(sheet.name) - Data Visualization"
                )
            }

            await MainActor.run {
                if let image = chartImage {
                    var imageMessage = ChatMessage(
                        content: "✅ Visualization created with readable text! Click image to save as PNG.\n\n📊 Chart shows: \(chartSuggestion.yColumn) by \(chartSuggestion.xColumn)\n💡 All text is perfectly readable (using Swift Charts, not AI generation)",
                        role: .assistant
                    )
                    imageMessage.image = image
                    messages.append(imageMessage)
                } else {
                    // Get column types to help user understand
                    let xIndex = sheet.headers.firstIndex(of: chartSuggestion.xColumn) ?? 0
                    let yIndex = sheet.headers.firstIndex(of: chartSuggestion.yColumn) ?? 0

                    let xSample = sheet.rowCount > 1 ? sheet.cells[1][xIndex].displayValue : ""
                    let ySample = sheet.rowCount > 1 ? sheet.cells[1][yIndex].displayValue : ""

                    let errorMessage = ChatMessage(
                        content: """
                        ❌ Could not create chart with these columns:

                        X-Axis: \(chartSuggestion.xColumn)
                        Sample value: "\(xSample)"

                        Y-Axis: \(chartSuggestion.yColumn)
                        Sample value: "\(ySample)"

                        Problem: The Y-axis column doesn't contain numeric data that can be charted.

                        💡 Try asking: "Which columns have numeric data I can chart?"

                        Or manually open Advanced AI → Forecasting tab and select a numeric column.
                        """,
                        role: .assistant
                    )
                    messages.append(errorMessage)
                }
                isGenerating = false
            }
        }
    }
}

// MARK: - Chat Message
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let role: Role
    let timestamp = Date()
    var image: NSImage? = nil
    /// Where an assistant reply came from ("AI · Ollama (…)" / "Built-in analysis (…)"); nil for notes.
    var source: String? = nil

    init(content: String, role: Role, source: String? = nil) {
        self.content = content
        self.role = role
        self.source = source
    }

    enum Role {
        case user
        case assistant
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    @State private var showingCopied = false

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                HStack {
                    Text(message.content)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: 250, alignment: message.role == .user ? .trailing : .leading)

                    if message.role == .assistant {
                        Button(action: {
                            copyMessage()
                        }) {
                            Image(systemName: showingCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Copy message")
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(message.role == .user ? Color.cyan.opacity(0.2) : Color.secondary.opacity(0.1))
                )

                // Display image if present
                if let image = message.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 250)
                        .cornerRadius(8)
                        .onTapGesture {
                            saveImage(image)
                        }
                        .help("Click to save image")
                }

                HStack(spacing: 6) {
                    Text(message.timestamp, style: .time)
                    if let source = message.source {
                        Text("· \(source)")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    private func copyMessage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.content, forType: .string)

        showingCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingCopied = false
        }
    }

    private func saveImage(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "DataVisualization_\(Date().formatted(date: .numeric, time: .omitted)).png"

        if panel.runModal() == .OK, let url = panel.url {
            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
            }
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(.cyan.opacity(0.5))

            Text("Ask AI about your data")
                .font(.headline)

            Text("Use natural language to analyze, query, and understand your spreadsheet")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    var color: Color = .cyan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.borderless)
    }
}
