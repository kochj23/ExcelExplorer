//
//  SentimentAnalyzer.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  AI-powered sentiment analysis for text columns
//

import Foundation
import NaturalLanguage
import NovaAIKit

@MainActor
class SentimentAnalyzer: ObservableObject {
    @Published var analyses: [SentimentAnalysis] = []
    @Published var isAnalyzing: Bool = false
    @Published var error: String?

    private let ai: NovaAI

    init(ai: NovaAI? = nil) {
        self.ai = ai ?? AppAI.shared
    }

    // MARK: - Analyze Text Column
    func analyzeTextColumn(
        sheet: SheetData,
        columnIndex: Int
    ) async -> SentimentAnalysis? {
        isAnalyzing = true
        defer { isAnalyzing = false }

        let columnName = sheet.headers[columnIndex]
        var texts: [String] = []

        // Extract text from column
        for row in 1..<min(sheet.rowCount, 1000) {
            if let cell = sheet.getCell(row: row, column: columnIndex) {
                let text = cell.displayValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    texts.append(text)
                }
            }
        }

        guard !texts.isEmpty else {
            error = "No text data found in column"
            return nil
        }

        // Analyze sentiments using NaturalLanguage framework
        let sentiments = texts.map { analyzeSentiment($0) }

        // Calculate distribution
        let positiveCount = sentiments.filter { $0 == .positive }.count
        let neutralCount = sentiments.filter { $0 == .neutral }.count
        let negativeCount = sentiments.filter { $0 == .negative }.count

        let total = Double(sentiments.count)
        let distribution = SentimentDistribution(
            positive: Double(positiveCount) / total,
            neutral: Double(neutralCount) / total,
            negative: Double(negativeCount) / total
        )

        // Extract key themes using AI
        let themes = await extractThemes(texts: texts, sentiments: sentiments)

        // Generate summary
        let summary = await generateSummary(
            columnName: columnName,
            texts: texts,
            distribution: distribution,
            themes: themes
        )

        let analysis = SentimentAnalysis(
            columnName: columnName,
            totalEntries: texts.count,
            distribution: distribution,
            sentiments: sentiments,
            themes: themes,
            summary: summary,
            analyzedDate: Date()
        )

        analyses.append(analysis)
        return analysis
    }

    // MARK: - Analyze Individual Sentiment
    private func analyzeSentiment(_ text: String) -> Sentiment {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        var sentimentScore: Double = 0.0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                sentimentScore = score
                return false // Stop after first result
            }
            return true
        }

        // Convert score to sentiment
        if sentimentScore > 0.2 {
            return .positive
        } else if sentimentScore < -0.2 {
            return .negative
        } else {
            return .neutral
        }
    }

    // MARK: - Extract Themes
    private func extractThemes(texts: [String], sentiments: [Sentiment]) async -> [Theme] {
        // Sample a subset for AI analysis
        let sample = texts.prefix(50).joined(separator: "\n")

        let prompt = """
        Analyze these customer reviews/comments and extract the top 5 themes:

        \(sample)

        Respond with ONLY a JSON array in this format:
        [
            {"name": "Theme Name", "count": 15, "sentiment": "positive"},
            {"name": "Another Theme", "count": 12, "sentiment": "negative"}
        ]

        Sentiment values: positive, negative, or neutral
        """

        let builtIn = Self.keywordThemes(texts: texts, sentiments: sentiments)
        return await ai.structured(
            [Theme].self,
            NovaAIRequest(prompt: prompt,
                          system: "You are analyzing customer feedback. Respond ONLY with valid JSON.",
                          temperature: 0.3, maxTokens: 500),
            validate: ExcelAIValidators.themes(total: texts.count)
        ) { builtIn }.value
    }

    /// Built-in themes: the five most frequent meaningful words, each with the majority sentiment of the
    /// entries that mention it.
    nonisolated static func keywordThemes(texts: [String], sentiments: [Sentiment]) -> [Theme] {
        let stop: Set<String> = ["this", "that", "with", "have", "from", "they", "were", "been", "very", "just", "about",
                                 "would", "there", "their", "what", "when", "your", "more", "some", "will", "also",
                                 "than", "them", "only", "into", "much", "after", "really", "because", "could"]
        var counts: [String: Int] = [:]
        var tone: [String: [Sentiment]] = [:]
        for (i, text) in texts.enumerated() {
            let words = Set(text.lowercased().components(separatedBy: CharacterSet.letters.inverted).filter { $0.count >= 4 && !stop.contains($0) })
            for w in words {
                counts[w, default: 0] += 1
                if i < sentiments.count { tone[w, default: []].append(sentiments[i]) }
            }
        }
        return counts.filter { $0.value >= 2 }
            .sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
            .prefix(5)
            .map { word, count in
                let t = tone[word] ?? []
                let pos = t.filter { $0 == .positive }.count, neg = t.filter { $0 == .negative }.count
                return Theme(name: word.capitalized, count: count,
                             sentiment: pos > neg ? "positive" : (neg > pos ? "negative" : "neutral"))
            }
    }

    // MARK: - Generate Summary
    private func generateSummary(
        columnName: String,
        texts: [String],
        distribution: SentimentDistribution,
        themes: [Theme]
    ) async -> String {
        let sample = texts.prefix(20).joined(separator: "\n")
        let themesStr = themes.map { "- \($0.name) (\($0.sentiment))" }.joined(separator: "\n")

        let prompt = """
        Summarize this sentiment analysis:

        Column: \(columnName)
        Total entries: \(texts.count)
        Sentiment distribution:
        - Positive: \(String(format: "%.1f%%", distribution.positive * 100))
        - Neutral: \(String(format: "%.1f%%", distribution.neutral * 100))
        - Negative: \(String(format: "%.1f%%", distribution.negative * 100))

        Key themes:
        \(themesStr)

        Sample data:
        \(sample)

        Provide a 2-3 sentence executive summary of the customer sentiment.
        """

        let dominant = distribution.positive > distribution.negative ? "positive" : (distribution.negative > distribution.positive ? "negative" : "neutral")
        let builtIn = "Analysis of \(texts.count) entries shows predominantly \(dominant) sentiment (\(String(format: "%.1f%%", (dominant == "positive" ? distribution.positive : (dominant == "negative" ? distribution.negative : distribution.neutral)) * 100)))."
        return await ai.ask(prompt, system: "You are analyzing customer sentiment data.",
                            temperature: 0.3, maxTokens: 200) { builtIn }.labeled
    }

    // MARK: - Export Sentiment Column
    func exportSentimentColumn(
        sheet: SheetData,
        columnIndex: Int,
        sentiments: [Sentiment]
    ) -> SheetData {
        // Create a new sheet with sentiment column added
        let newSheet = SheetData(name: "\(sheet.name) + Sentiment", rows: sheet.rowCount, columns: sheet.columnCount + 1)

        // Copy headers
        for (index, header) in sheet.headers.enumerated() {
            if let cell = newSheet.getCell(row: 0, column: index) {
                cell.value = .string(header)
            }
        }

        // Add sentiment header
        if let cell = newSheet.getCell(row: 0, column: sheet.columnCount) {
            cell.value = .string("Sentiment")
        }

        // Copy data and add sentiments
        for row in 1..<sheet.rowCount {
            for col in 0..<sheet.columnCount {
                if let sourceCell = sheet.getCell(row: row, column: col),
                   let targetCell = newSheet.getCell(row: row, column: col) {
                    targetCell.value = sourceCell.value
                }
            }

            // Add sentiment
            if row - 1 < sentiments.count,
               let sentimentCell = newSheet.getCell(row: row, column: sheet.columnCount) {
                sentimentCell.value = .string(sentiments[row - 1].rawValue)
            }
        }

        return newSheet
    }
}

// MARK: - Data Structures

struct SentimentAnalysis: Identifiable {
    let id = UUID()
    let columnName: String
    let totalEntries: Int
    let distribution: SentimentDistribution
    let sentiments: [Sentiment]
    let themes: [Theme]
    let summary: String
    let analyzedDate: Date
}

struct SentimentDistribution {
    let positive: Double
    let neutral: Double
    let negative: Double

    var dominantSentiment: Sentiment {
        if positive > neutral && positive > negative {
            return .positive
        } else if negative > positive && negative > neutral {
            return .negative
        } else {
            return .neutral
        }
    }
}

enum Sentiment: String, Codable {
    case positive = "Positive"
    case neutral = "Neutral"
    case negative = "Negative"

    var color: String {
        switch self {
        case .positive: return "green"
        case .neutral: return "gray"
        case .negative: return "red"
        }
    }

    var emoji: String {
        switch self {
        case .positive: return "😊"
        case .neutral: return "😐"
        case .negative: return "😞"
        }
    }
}

struct Theme: Codable, Identifiable {
    var id: String { name }
    let name: String
    let count: Int
    let sentiment: String
}
