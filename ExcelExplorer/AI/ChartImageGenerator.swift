//
//  ChartImageGenerator.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  Generate actual readable chart images using Swift Charts
//

import Foundation
import SwiftUI
import Charts

@MainActor
class ChartImageGenerator: ObservableObject {

    // MARK: - Generate Chart Image from Data
    func generateChartImage(
        sheet: SheetData,
        chartType: String,
        xColumn: String,
        yColumn: String,
        title: String
    ) -> NSImage? {

        // Find column indices
        guard let xIndex = sheet.headers.firstIndex(of: xColumn),
              let yIndex = sheet.headers.firstIndex(of: yColumn) else {
            print("❌ Could not find columns: '\(xColumn)' or '\(yColumn)'")
            print("Available headers: \(sheet.headers.joined(separator: ", "))")
            return nil
        }

        // Check if Y column is numeric - if not, we need to do aggregation
        // Also check if yColumn is "count" which signals we should do frequency analysis
        let yColumnIsNumeric = sheet.columnStats(yIndex)?.numbers.isEmpty == false
        let shouldAggregate = !yColumnIsNumeric || yColumn.lowercased() == "count"

        var dataPoints: [(x: String, y: Double)] = []

        if yColumnIsNumeric && !shouldAggregate {
            // Direct plotting: Y column has numeric values
            for row in 1..<min(sheet.rowCount, 21) {
                let xValue = sheet.cells[row][xIndex].displayValue

                // Try to get numeric Y value
                let yValue: Double?
                switch sheet.cells[row][yIndex].value {
                case .number(let num):
                    yValue = num
                case .date(let date):
                    // Convert date to timestamp for visualization
                    yValue = date.timeIntervalSince1970
                case .string(let str):
                    // Try parsing as number
                    yValue = Double(str)
                default:
                    yValue = nil
                }

                if let y = yValue {
                    dataPoints.append((x: xValue, y: y))
                }
            }
        } else {
            // Aggregation: Count occurrences of X values (for categorical data)
            print("📊 Y column is not numeric - creating frequency chart")

            var counts: [String: Int] = [:]

            for row in 1..<sheet.rowCount {
                let xValue = sheet.cells[row][xIndex].displayValue
                counts[xValue, default: 0] += 1
            }

            // Convert to data points (limit to top 20)
            let sortedCounts = counts.sorted { $0.value > $1.value }.prefix(20)
            dataPoints = sortedCounts.map { (x: $0.key, y: Double($0.value)) }

            print("📊 Aggregated \(counts.count) unique categories, showing top \(dataPoints.count)")
        }

        print("📊 Chart data extracted: \(dataPoints.count) points from columns '\(xColumn)' and '\(yColumn)'")
        if dataPoints.isEmpty {
            print("❌ No valid data found")
            print("   X column '\(xColumn)': \(sheet.cells[1][xIndex].displayValue)")
            print("   Y column '\(yColumn)': \(sheet.cells[1][yIndex].displayValue)")
        }

        guard !dataPoints.isEmpty else { return nil }

        // Create appropriate chart based on type
        let chartView: AnyView
        switch chartType.lowercased() {
        case "bar":
            chartView = AnyView(createBarChart(data: dataPoints, title: title, xLabel: xColumn, yLabel: yColumn))
        case "line":
            chartView = AnyView(createLineChart(data: dataPoints, title: title, xLabel: xColumn, yLabel: yColumn))
        case "pie":
            if #available(macOS 14.0, *) {
                chartView = AnyView(createPieChart(data: dataPoints, title: title))
            } else {
                // Fallback to bar chart on macOS 13
                chartView = AnyView(createBarChart(data: dataPoints, title: title, xLabel: xColumn, yLabel: yColumn))
            }
        default:
            chartView = AnyView(createBarChart(data: dataPoints, title: title, xLabel: xColumn, yLabel: yColumn))
        }

        // Render to image
        return renderViewAsImage(chartView, size: CGSize(width: 1200, height: 800))
    }

    // MARK: - Create Bar Chart
    private func createBarChart(
        data: [(x: String, y: Double)],
        title: String,
        xLabel: String,
        yLabel: String
    ) -> some View {
        VStack(spacing: 0) {
            // Title section with background
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)

                Text("\(yLabel) by \(xLabel)")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(Color.cyan.opacity(0.05))

            // Chart section
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                    BarMark(
                        x: .value(xLabel, point.x),
                        y: .value(yLabel, point.y)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan, Color.cyan.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                    .annotation(position: .top, alignment: .center) {
                        VStack(spacing: 2) {
                            Text(self.formatNumber(point.y))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                )
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(preset: .aligned) { _ in
                    AxisValueLabel()
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .chartYAxis {
                AxisMarks(preset: .aligned) { _ in
                    AxisValueLabel()
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.background(Color.white)
            }
            .frame(height: 550)
            .padding(50)

            // Footer
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.cyan)
                    Text("Generated by Excel Explorer")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(Date().formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 50)
            .padding(.bottom, 30)
        }
        .frame(width: 1200, height: 800)
        .background(
            LinearGradient(
                colors: [Color.white, Color.gray.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Create Line Chart
    private func createLineChart(
        data: [(x: String, y: Double)],
        title: String,
        xLabel: String,
        yLabel: String
    ) -> some View {
        VStack(spacing: 0) {
            // Title section with background
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)

                Text("\(yLabel) Trend")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(Color.cyan.opacity(0.05))

            // Chart section
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("Index", index),
                        y: .value(yLabel, point.y)
                    )
                    .foregroundStyle(Color.cyan)
                    .lineStyle(StrokeStyle(lineWidth: 4))

                    PointMark(
                        x: .value("Index", index),
                        y: .value(yLabel, point.y)
                    )
                    .foregroundStyle(Color.cyan)
                    .symbolSize(100)
                }
            }
            .chartXAxis {
                AxisMarks(preset: .aligned) { _ in
                    AxisValueLabel()
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .chartYAxis {
                AxisMarks(preset: .aligned) { _ in
                    AxisValueLabel()
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.background(Color.white)
            }
            .frame(height: 550)
            .padding(50)

            // Footer
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.cyan)
                    Text("Generated by Excel Explorer")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(Date().formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 50)
            .padding(.bottom, 30)
        }
        .frame(width: 1200, height: 800)
        .background(
            LinearGradient(
                colors: [Color.white, Color.gray.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Create Pie Chart
    @available(macOS 14.0, *)
    private func createPieChart(
        data: [(x: String, y: Double)],
        title: String
    ) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 30)

            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                    SectorMark(
                        angle: .value("Value", point.y),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", point.x))
                    .annotation(position: .overlay) {
                        Text(self.formatNumber(point.y))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .center) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                        HStack {
                            Circle()
                                .fill(self.colorForIndex(index))
                                .frame(width: 10, height: 10)
                            Text(point.x)
                                .font(.system(size: 12))
                        }
                    }
                }
            }
            .frame(height: 500)
            .padding(40)

            HStack {
                Text("Generated by Excel Explorer")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                Text(Date().formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(width: 1200, height: 800)
        .background(Color.white)
    }

    // MARK: - Render View as Image
    private func renderViewAsImage(_ view: AnyView, size: CGSize) -> NSImage? {
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = CGRect(origin: .zero, size: size)
        hosting.view.setFrameSize(size)

        // Force layout
        hosting.view.layoutSubtreeIfNeeded()
        hosting.view.displayIfNeeded()

        // Create bitmap representation
        guard let bitmapRep = hosting.view.bitmapImageRepForCachingDisplay(in: CGRect(origin: .zero, size: size)) else {
            print("❌ Could not create bitmap representation")
            return nil
        }

        hosting.view.cacheDisplay(in: CGRect(origin: .zero, size: size), to: bitmapRep)

        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)

        print("✅ Chart rendered: \(size.width)×\(size.height) - \(bitmapRep.pixelsWide)×\(bitmapRep.pixelsHigh) pixels")

        return image
    }

    // MARK: - Helper Functions
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2

        if value >= 1000000 {
            return String(format: "%.1fM", value / 1000000)
        } else if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        } else {
            return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        }
    }

    private func colorForIndex(_ index: Int) -> Color {
        let colors: [Color] = [.cyan, .blue, .purple, .green, .orange, .pink, .red, .yellow]
        return colors[index % colors.count]
    }
}
