//
//  AIConversationView.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import SwiftUI

struct AIConversationView: View {
    @EnvironmentObject var dataManager: ExcelDataManager
    @ObservedObject var aiManager = AIBackendManager.shared
    @StateObject private var analyzer = AIDataAnalyzer()
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

                    // AI Status
                    HStack(spacing: 8) {
                        if aiManager.isOllamaAvailable || aiManager.isMLXAvailable ||
                           aiManager.isTinyLLMAvailable || aiManager.isTinyChatAvailable ||
                           aiManager.isOpenWebUIAvailable {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("AI: \(aiManager.activeBackend.rawValue)")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            Text("AI Not Available")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
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
                .onChange(of: messages.count) { _ in
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
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessage(content: inputText, role: .user)
        messages.append(userMessage)

        let query = inputText
        inputText = ""

        isGenerating = true

        Task {
            do {
                guard let sheet = dataManager.currentSheet else {
                    let errorMessage = ChatMessage(content: "No spreadsheet is currently loaded", role: .assistant)
                    await MainActor.run {
                        messages.append(errorMessage)
                        isGenerating = false
                    }
                    return
                }

                let response = try await analyzer.queryData(query, sheet: sheet)

                await MainActor.run {
                    let assistantMessage = ChatMessage(content: response, role: .assistant)
                    messages.append(assistantMessage)
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", role: .assistant)
                    messages.append(errorMessage)
                    isGenerating = false
                }
            }
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
            do {
                // Step 1: Generate summary
                let summary = try await analyzer.summarizeSheet(sheet)

                await MainActor.run {
                    let summaryMessage = ChatMessage(content: "📊 Data Summary:\n\n\(summary)", role: .assistant)
                    messages.append(summaryMessage)
                }

                // Step 2: Suggest chart type
                let chartSuggestion = try await analyzer.suggestChart(sheet)

                await MainActor.run {
                    let chartMessage = ChatMessage(
                        content: "📈 Visualization Recommendation:\n\nChart Type: \(chartSuggestion.chartType.capitalized)\nX-Axis: \(chartSuggestion.xColumn)\nY-Axis: \(chartSuggestion.yColumn)\n\nReasoning: \(chartSuggestion.reasoning)\n\nI can create this chart in the Advanced AI Features panel (⇧⌘B → Forecasting tab).",
                        role: .assistant
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

                        let xSample = sheet.cells[1][xIndex].displayValue
                        let ySample = sheet.cells[1][yIndex].displayValue

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

            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", role: .assistant)
                    messages.append(errorMessage)
                    isGenerating = false
                }
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

                Text(message.timestamp, style: .time)
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
