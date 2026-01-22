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
        let yColumnIsNumeric = sheet.columnStats(yIndex)?.numbers.isEmpty == false

        var dataPoints: [(x: String, y: Double)] = []

        if yColumnIsNumeric {
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
        VStack(spacing: 20) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 30)

            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                    BarMark(
                        x: .value(xLabel, point.x),
                        y: .value(yLabel, point.y)
                    )
                    .foregroundStyle(Color.cyan.gradient)
                    .annotation(position: .top) {
                        Text(self.formatNumber(point.y))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(preset: .aligned) { value in
                    AxisValueLabel()
                        .font(.system(size: 12))
                }
            }
            .chartYAxis {
                AxisMarks(preset: .aligned) { value in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.system(size: 12))
                }
            }
            .frame(height: 600)
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

    // MARK: - Create Line Chart
    private func createLineChart(
        data: [(x: String, y: Double)],
        title: String,
        xLabel: String,
        yLabel: String
    ) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 30)

            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value(xLabel, index),
                        y: .value(yLabel, point.y)
                    )
                    .foregroundStyle(Color.cyan)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value(xLabel, index),
                        y: .value(yLabel, point.y)
                    )
                    .foregroundStyle(Color.cyan)
                    .annotation(position: .top) {
                        VStack(spacing: 2) {
                            Text(point.x)
                                .font(.system(size: 9))
                            Text(self.formatNumber(point.y))
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let index = value.as(Int.self), index < data.count {
                            Text(data[index].x)
                                .font(.system(size: 11))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(preset: .aligned) { value in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.system(size: 12))
                }
            }
            .frame(height: 600)
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

        guard let bitmapRep = hosting.view.bitmapImageRepForCachingDisplay(in: hosting.view.bounds) else {
            return nil
        }

        hosting.view.cacheDisplay(in: hosting.view.bounds, to: bitmapRep)

        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)

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
