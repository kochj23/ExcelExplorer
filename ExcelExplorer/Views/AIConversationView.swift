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
                    QuickActionButton(title: "Summarize", icon: "doc.text", action: {
                        sendQuickQuery("Summarize this spreadsheet data")
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

                    QuickActionButton(title: "Explain Column", icon: "questionmark.circle", action: {
                        sendQuickQuery("Explain what each column represents")
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
}

// MARK: - Chat Message
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let role: Role
    let timestamp = Date()

    enum Role {
        case user
        case assistant
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(message.role == .user ? Color.cyan.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
                    .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .assistant {
                Spacer()
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
                    .fill(Color.cyan.opacity(0.1))
            )
        }
        .buttonStyle(.borderless)
    }
}
