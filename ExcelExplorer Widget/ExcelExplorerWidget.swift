//
//  ExcelExplorerWidget.swift
//  ExcelExplorer Widget
//
//  Created by Jordan Koch on 2026-02-04.
//  WidgetKit widget for ExcelExplorer - shows recent files, stats, and AI status
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct ExcelExplorerProvider: TimelineProvider {

    func placeholder(in context: Context) -> ExcelExplorerEntry {
        ExcelExplorerEntry(data: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (ExcelExplorerEntry) -> Void) {
        if context.isPreview {
            completion(ExcelExplorerEntry(data: .preview))
        } else {
            let data = SharedDataManager.shared.loadWidgetData()
            completion(ExcelExplorerEntry(data: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExcelExplorerEntry>) -> Void) {
        let data = SharedDataManager.shared.loadWidgetData()
        let entry = ExcelExplorerEntry(data: data)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Views

/// Small widget view - shows current file or quick open
struct SmallWidgetView: View {
    let data: ExcelExplorerWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "tablecells")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Spacer()
                if data.aiStatus.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Spacer()

            // Current file or empty state
            if let filename = data.currentFileStats.filename {
                VStack(alignment: .leading, spacing: 4) {
                    Text(filename)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    Text(data.currentFileStats.statsText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if data.currentFileStats.sheetCount > 1 {
                        Text("\(data.currentFileStats.sheetCount) sheets")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ExcelExplorer")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Tap to open a file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .widgetURL(WidgetDeepLink.openApp.url)
    }
}

/// Medium widget view - shows recent files list
struct MediumWidgetView: View {
    let data: ExcelExplorerWidgetData

    var body: some View {
        HStack(spacing: 16) {
            // Left side: Current file stats
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "tablecells")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    Text("ExcelExplorer")
                        .font(.headline)
                }

                Spacer()

                if let filename = data.currentFileStats.filename {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(filename)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        HStack(spacing: 12) {
                            Label("\(data.currentFileStats.rowCount.formatted())", systemImage: "arrow.down")
                            Label("\(data.currentFileStats.columnCount)", systemImage: "arrow.right")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    // AI Status
                    HStack(spacing: 4) {
                        Image(systemName: data.aiStatus.isAnalyzing ? "brain" : "checkmark.circle")
                            .foregroundColor(data.aiStatus.isAnalyzing ? .orange : .green)
                        Text(data.aiStatus.statusText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No file open")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Right side: Recent files
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                if data.recentFiles.isEmpty {
                    Text("No recent files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(data.recentFiles.prefix(3)) { file in
                        Link(destination: WidgetDeepLink.openFile(path: file.filePath).url!) {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(file.filename)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                    Text(file.formattedDate)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}

/// Large widget view - shows detailed stats, recent files, and AI analysis
struct LargeWidgetView: View {
    let data: ExcelExplorerWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "tablecells")
                    .font(.title)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("ExcelExplorer")
                        .font(.headline)
                    Text("AI-Powered Spreadsheet Viewer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if data.aiStatus.isAnalyzing {
                    ProgressView()
                }
            }

            Divider()

            // Current file section
            VStack(alignment: .leading, spacing: 8) {
                Text("Current File")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                if let filename = data.currentFileStats.filename {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(filename)
                                .font(.headline)
                                .lineLimit(1)

                            HStack(spacing: 16) {
                                StatBadge(value: data.currentFileStats.rowCount.formatted(), label: "Rows", icon: "arrow.down")
                                StatBadge(value: "\(data.currentFileStats.columnCount)", label: "Cols", icon: "arrow.right")
                                StatBadge(value: "\(data.currentFileStats.sheetCount)", label: "Sheets", icon: "doc.on.doc")
                            }
                        }
                        Spacer()

                        // Quick action button
                        Link(destination: WidgetDeepLink.startAnalysis.url!) {
                            VStack {
                                Image(systemName: "brain")
                                    .font(.title2)
                                Text("Analyze")
                                    .font(.caption2)
                            }
                            .foregroundColor(.accentColor)
                            .padding(8)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }

                    // AI Status bar
                    HStack {
                        Circle()
                            .fill(data.aiStatus.isAnalyzing ? Color.orange : Color.green)
                            .frame(width: 8, height: 8)
                        Text(data.aiStatus.statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let summary = data.aiStatus.summary {
                            Text("- \(summary)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No file open")
                            .foregroundColor(.secondary)
                        Spacer()
                        Link(destination: WidgetDeepLink.openRecent.url!) {
                            Text("Open File")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                }
            }

            Divider()

            // Recent files section
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Files")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                if data.recentFiles.isEmpty {
                    Text("No recent files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(data.recentFiles.prefix(4)) { file in
                        Link(destination: WidgetDeepLink.openFile(path: file.filePath).url!) {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.filename)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                    Text(file.statsDescription)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(file.formattedDate)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(file.formattedFileSize)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

/// Small stat badge component
struct StatBadge: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Widget Entry View

struct ExcelExplorerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ExcelExplorerEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        case .systemLarge:
            LargeWidgetView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
    }
}

// MARK: - Widget Configuration

struct ExcelExplorerWidget: Widget {
    let kind: String = "ExcelExplorerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExcelExplorerProvider()) { entry in
            ExcelExplorerWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ExcelExplorer")
        .description("View recent files, current file stats, and AI analysis status.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle (for multiple widgets if needed)

@main
struct ExcelExplorerWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExcelExplorerWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    ExcelExplorerWidget()
} timeline: {
    ExcelExplorerEntry(data: .preview)
    ExcelExplorerEntry(data: .empty)
}

#Preview("Medium", as: .systemMedium) {
    ExcelExplorerWidget()
} timeline: {
    ExcelExplorerEntry(data: .preview)
    ExcelExplorerEntry(data: .empty)
}

#Preview("Large", as: .systemLarge) {
    ExcelExplorerWidget()
} timeline: {
    ExcelExplorerEntry(data: .preview)
    ExcelExplorerEntry(data: .empty)
}
