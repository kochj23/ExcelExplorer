//
//  AIFallbacks.swift
//  ExcelExplorer
//
//  The app-side half of the NovaAIKit contract:
//  - `ExcelAIValidators` reject or clamp AI replies (no code in analyses, formulas must parse, chart/pivot columns
//    must exist, enums and counts clamped, forecast figures must come from the data).
//  - `BuiltInAnalysis` is what every AI feature shows when AI is off, unreachable or its reply is rejected:
//    deterministic statistics and rule-based suggestions computed from the sheet itself.
//

import Foundation
import NovaAIKit

// MARK: - Validators

enum ExcelAIValidators {
    static let maxReplyCharacters = 8000

    /// Markers of code/commands the analysis prompts forbid.
    static let codeMarkers = ["```python", "```sql", "```r\n", "import pandas", "pd.read_", "df.groupby", "df[",
                              "select * from", "dataframe.describe"]

    /// Analysis text: non-empty, no code or commands, capped.
    static let analysisText: @Sendable (String) throws -> String = { raw in
        let t = try NovaAI.nonEmpty(raw)
        let lower = t.lowercased()
        if codeMarkers.contains(where: { lower.contains($0) }) {
            throw NovaAIValidationError("the reply contained code or commands; give the findings directly")
        }
        return String(t.prefix(maxReplyCharacters))
    }

    /// Short plain text (voice confirmations, formula explanations).
    static func shortText(maxCharacters: Int) -> @Sendable (String) throws -> String {
        { raw in
            let t = NovaAIText.plain(try NovaAI.nonEmpty(raw), max: maxCharacters)
            if t.isEmpty { throw NovaAIValidationError("empty reply") }
            return t
        }
    }

    /// Forecast commentary: analysis rules, plus every decimal figure must appear in the forecast data.
    static func forecastText(source: String) -> @Sendable (String) throws -> String {
        { raw in
            let t = try analysisText(raw)
            let invented = NovaAIText.numbers(t).filter { $0.contains(".") }.subtracting(NovaAIText.numbers(source))
            if !invented.isEmpty {
                throw NovaAIValidationError("figures not in the data: \(invented.sorted().prefix(3).joined(separator: ", "))")
            }
            return t
        }
    }

    /// An Excel formula: one line starting with "=", balanced parentheses and quotes, at most 500 characters.
    static let formula: @Sendable (String) throws -> String = { raw in
        let cleaned = (NovaAIText.clean(raw) ?? "").replacingOccurrences(of: "`", with: "")
        guard let line = cleaned.components(separatedBy: .newlines)
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .first(where: { $0.hasPrefix("=") }) else {
            throw NovaAIValidationError("reply only with the formula, starting with =")
        }
        let f = line.hasSuffix(".") ? String(line.dropLast()) : line
        guard f.count >= 2, f.count <= 500 else { throw NovaAIValidationError("formula length out of range") }
        var depth = 0
        for c in f {
            if c == "(" { depth += 1 } else if c == ")" { depth -= 1; if depth < 0 { break } }
        }
        guard depth == 0 else { throw NovaAIValidationError("unbalanced parentheses") }
        guard f.filter({ $0 == "\"" }).count % 2 == 0 else { throw NovaAIValidationError("unbalanced quotes") }
        return f
    }

    /// Canonical header for a name (exact, then case-insensitive), or nil.
    static func match(_ name: String, in headers: [String]) -> String? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let h = headers.first(where: { $0 == n }) { return h }
        return headers.first { $0.caseInsensitiveCompare(n) == .orderedSame }
    }

    /// Chart suggestion: type clamped to bar/line/pie, X must be a real column, Y a numeric column or "count".
    static func chart(headers: [String], numeric: [String]) -> @Sendable (ChartSuggestion) throws -> ChartSuggestion {
        { s in
            let type = ["bar", "line", "pie"].contains(s.chartType.lowercased()) ? s.chartType.lowercased() : "bar"
            guard let x = match(s.xColumn, in: headers) else {
                throw NovaAIValidationError("xColumn '\(s.xColumn.prefix(60))' is not a column; use one of: \(headers.prefix(20).joined(separator: ", "))")
            }
            let y: String
            if s.yColumn.lowercased() == "count" {
                y = "count"
            } else if let m = match(s.yColumn, in: numeric) {
                y = m
            } else {
                throw NovaAIValidationError("yColumn must be a numeric column (\(numeric.prefix(20).joined(separator: ", "))) or \"count\"")
            }
            return ChartSuggestion(chartType: type, xColumn: x, yColumn: y,
                                   reasoning: NovaAIText.plain(s.reasoning, max: 500))
        }
    }

    /// Pivot spec: only real columns, at least one row dimension and one value, counts capped.
    static func pivot(headers: [String]) -> @Sendable (PivotSpec) throws -> PivotSpec {
        { s in
            let rows = Array(s.rowDimensions.compactMap { match($0, in: headers) }.prefix(3))
            let cols = Array(s.columnDimensions.compactMap { match($0, in: headers) }.filter { !rows.contains($0) }.prefix(2))
            let values = Array(s.values.compactMap { v in match(v.column, in: headers).map { PivotSpec.ValueSpec(column: $0, aggregation: v.aggregation) } }.prefix(5))
            guard !rows.isEmpty else { throw NovaAIValidationError("rowDimensions must name existing columns") }
            guard !values.isEmpty else { throw NovaAIValidationError("values must name existing columns") }
            return PivotSpec(rowDimensions: rows, columnDimensions: cols, values: values)
        }
    }

    /// Action plan: action must be one of the executable actions; parameters capped.
    static let actionPlan: @Sendable (ActionPlanJSON) throws -> ActionPlanJSON = { p in
        let action = p.action.lowercased().trimmingCharacters(in: .whitespaces)
        guard ActionType(rawValue: action) != nil else {
            throw NovaAIValidationError("action must be one of summarize, visualize, filter, calculate, export, pivot, forecast, clean")
        }
        var params: [String: String] = [:]
        for (k, v) in p.parameters.prefix(10) { params[String(k.prefix(40))] = String(v.prefix(200)) }
        return ActionPlanJSON(action: action, parameters: params, reasoning: NovaAIText.plain(p.reasoning, max: 300))
    }

    /// Themes: at most 5, names non-empty, counts within 0...total, sentiment clamped.
    static func themes(total: Int) -> @Sendable ([Theme]) throws -> [Theme] {
        { list in
            var seen = Set<String>()
            let out: [Theme] = list.compactMap { t in
                let name = NovaAIText.plain(t.name, max: 60)
                guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { return nil }
                let sentiment = ["positive", "negative", "neutral"].contains(t.sentiment.lowercased()) ? t.sentiment.lowercased() : "neutral"
                return Theme(name: name, count: min(max(t.count, 0), total), sentiment: sentiment)
            }
            guard !out.isEmpty else { throw NovaAIValidationError("no themes") }
            return Array(out.prefix(5))
        }
    }

    /// Insights: non-empty text, importance clamped to high/medium/low, at most 10.
    static let insights: @Sendable ([InsightJSON]) throws -> [InsightJSON] = { list in
        let out: [InsightJSON] = list.compactMap { i in
            let text = NovaAIText.plain(i.insight, max: 500)
            guard !text.isEmpty else { return nil }
            let imp = (i.importance ?? "medium").lowercased()
            return InsightJSON(insight: text, importance: ["high", "medium", "low"].contains(imp) ? imp : "medium",
                               evidence: NovaAIText.plain(i.evidence ?? "", max: 300))
        }
        guard !out.isEmpty else { throw NovaAIValidationError("no insights") }
        return Array(out.prefix(10))
    }

    /// Voice "open file" extraction: a bare file name (no path), known locations and types only.
    static let fileInfo: @Sendable (FileInfo) throws -> FileInfo = { f in
        let name = f.filename.flatMap { n -> String? in
            let base = (n as NSString).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            return base.isEmpty || base == "null" || base.hasPrefix(".") ? nil : String(base.prefix(200))
        }
        let loc = f.location?.lowercased()
        let type = f.fileType?.lowercased()
        return FileInfo(filename: name,
                        location: ["downloads", "desktop", "documents"].contains(loc ?? "") ? loc : nil,
                        fileType: ["xlsx", "xls", "csv"].contains(type ?? "") ? type : nil)
    }
}

/// Wire shape of one AI insight.
struct InsightJSON: Codable, Equatable {
    let insight: String
    let importance: String?
    let evidence: String?
}

// MARK: - Built-in (non-AI) analysis

enum BuiltInAnalysis {
    struct NumericColumn { let index: Int; let name: String; let stats: ColumnStatistics }

    static func numericColumns(_ sheet: SheetData) -> [NumericColumn] {
        guard sheet.rowCount > 1 else { return [] }
        return sheet.headers.enumerated().compactMap { i, h in
            guard let s = sheet.columnStats(i), !s.numbers.isEmpty, s.numbers.count * 2 >= s.count else { return nil }
            return NumericColumn(index: i, name: h.isEmpty ? "Column \(i + 1)" : h, stats: s)
        }
    }

    static func categoricalColumns(_ sheet: SheetData) -> [(index: Int, name: String)] {
        let numeric = Set(numericColumns(sheet).map(\.index))
        return sheet.headers.enumerated().filter { !numeric.contains($0.offset) && !$0.element.isEmpty }.map { ($0.offset, $0.element) }
    }

    static func values(_ sheet: SheetData, column: Int) -> [String] {
        guard sheet.rowCount > 1, column >= 0, column < sheet.columnCount else { return [] }
        return (1..<sheet.rowCount).map { sheet.cells[$0][column].displayValue }
    }

    static func fmt(_ d: Double) -> String { String(format: "%.2f", d) }

    /// Overview: dimensions, numeric column statistics, text columns with distinct counts, empty cells.
    static func summary(_ sheet: SheetData) -> String {
        let dataRows = max(sheet.rowCount - 1, 0)
        var out = "Sheet \"\(sheet.name)\": \(dataRows) data rows × \(sheet.columnCount) columns."
        let numeric = numericColumns(sheet)
        if !numeric.isEmpty {
            out += "\n\nNumeric columns:"
            for c in numeric.prefix(12) {
                out += "\n• \(c.name): \(c.stats.numbers.count) values, total \(fmt(c.stats.sum)), average \(fmt(c.stats.average)), min \(fmt(c.stats.min)), max \(fmt(c.stats.max))"
            }
        }
        let text = categoricalColumns(sheet)
        if !text.isEmpty {
            out += "\n\nText columns:"
            for c in text.prefix(12) {
                let vals = values(sheet, column: c.index).filter { !$0.isEmpty }
                let top = mostCommon(vals)
                out += "\n• \(c.name): \(Set(vals).count) distinct values" + (top.map { ", most common \"\($0.value)\" (\($0.count))" } ?? "")
            }
        }
        let empty = emptyCellCount(sheet)
        if empty > 0 { out += "\n\n\(empty) empty cells." }
        return out
    }

    static func mostCommon(_ vals: [String]) -> (value: String, count: Int)? {
        let counts = Dictionary(vals.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }.map { ($0.key, $0.value) }
    }

    static func emptyCellCount(_ sheet: SheetData) -> Int {
        guard sheet.rowCount > 1 else { return 0 }
        return (1..<sheet.rowCount).reduce(0) { n, r in n + sheet.cells[r].filter { $0.displayValue.isEmpty }.count }
    }

    /// Trends (first vs second half), the strongest correlation and outliers (> 2σ).
    static func patterns(_ sheet: SheetData) -> String {
        let numeric = numericColumns(sheet)
        guard !numeric.isEmpty else { return "No numeric columns to find trends in.\n\n" + summary(sheet) }
        var lines: [String] = []
        for c in numeric.prefix(8) {
            let n = c.stats.numbers
            guard n.count >= 4 else { continue }
            let half = n.count / 2
            let a = n.prefix(half).reduce(0, +) / Double(half)
            let b = n.suffix(n.count - half).reduce(0, +) / Double(n.count - half)
            let dir = b > a ? "rises" : (b < a ? "falls" : "is flat")
            lines.append("• \(c.name) \(dir): first-half average \(fmt(a)), second-half average \(fmt(b)).")
            let mean = c.stats.average
            let sd = sqrt(n.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(n.count))
            let outliers = sd > 0 ? n.filter { abs($0 - mean) > 2 * sd } : []
            if !outliers.isEmpty {
                lines.append("  \(outliers.count) outlier(s) beyond 2σ, e.g. \(fmt(outliers[0])).")
            }
        }
        if let best = strongestCorrelation(numeric) {
            lines.append("• Strongest correlation: \(best.a) and \(best.b) (r = \(fmt(best.r))).")
        }
        return lines.isEmpty ? summary(sheet) : "Patterns:\n" + lines.joined(separator: "\n")
    }

    static func pearson(_ x: [Double], _ y: [Double]) -> Double {
        let n = min(x.count, y.count)
        guard n > 1 else { return 0 }
        let xs = Array(x.prefix(n)), ys = Array(y.prefix(n))
        let mx = xs.reduce(0, +) / Double(n), my = ys.reduce(0, +) / Double(n)
        var num = 0.0, dx = 0.0, dy = 0.0
        for i in 0..<n { num += (xs[i] - mx) * (ys[i] - my); dx += pow(xs[i] - mx, 2); dy += pow(ys[i] - my, 2) }
        let den = sqrt(dx * dy)
        return den > 0 ? num / den : 0
    }

    static func strongestCorrelation(_ cols: [NumericColumn]) -> (a: String, b: String, r: Double)? {
        var best: (String, String, Double)?
        for i in cols.indices { for j in cols.indices where j > i {
            let r = pearson(cols[i].stats.numbers, cols[j].stats.numbers)
            if abs(r) >= 0.5, abs(r) > abs(best?.2 ?? 0) { best = (cols[i].name, cols[j].name, r) }
        } }
        return best.map { ($0.0, $0.1, $0.2) }
    }

    /// Next value per numeric column from a least-squares line.
    static func predictions(_ sheet: SheetData, target: String? = nil) -> String {
        var cols = numericColumns(sheet)
        if let t = target, let m = cols.first(where: { $0.name.caseInsensitiveCompare(t) == .orderedSame }) { cols = [m] }
        let lines: [String] = cols.prefix(8).compactMap { c in
            let y = c.stats.numbers
            guard y.count >= 3 else { return nil }
            let (slope, intercept) = linearFit(y)
            let next = slope * Double(y.count) + intercept
            return "• \(c.name): next value ≈ \(fmt(next)) (linear trend, slope \(fmt(slope)) per row)."
        }
        return lines.isEmpty ? "Not enough numeric data (at least 3 values per column) to project values."
            : "Linear-trend projections:\n" + lines.joined(separator: "\n")
    }

    static func linearFit(_ y: [Double]) -> (slope: Double, intercept: Double) {
        let n = Double(y.count)
        let xs = (0..<y.count).map(Double.init)
        let mx = xs.reduce(0, +) / n, my = y.reduce(0, +) / n
        var num = 0.0, den = 0.0
        for i in 0..<y.count { num += (xs[i] - mx) * (y[i] - my); den += (xs[i] - mx) * (xs[i] - mx) }
        let slope = den == 0 ? 0 : num / den
        return (slope, my - slope * mx)
    }

    /// Type, distinct values and a sample for one column.
    static func explainColumn(_ sheet: SheetData, columnIndex: Int) -> String {
        guard columnIndex >= 0, columnIndex < sheet.columnCount else { return "Unknown column." }
        let name = sheet.headers[columnIndex]
        let vals = values(sheet, column: columnIndex).filter { !$0.isEmpty }
        let stats = sheet.columnStats(columnIndex)
        let kind = (stats?.numbers.count ?? 0) * 2 >= max(vals.count, 1) && !(stats?.numbers.isEmpty ?? true) ? "numeric" : "text"
        var out = "\(name): \(kind) column, \(vals.count) values, \(Set(vals).count) distinct."
        if kind == "numeric", let s = stats { out += " " + s.summary + "." }
        if !vals.isEmpty { out += " Sample: \(vals.prefix(5).joined(separator: ", "))." }
        return out
    }

    /// Bar of a numeric column by the first low-cardinality text column, or a count.
    static func chartSuggestion(_ sheet: SheetData) -> ChartSuggestion {
        let numeric = numericColumns(sheet)
        let text = categoricalColumns(sheet).sorted {
            Set(values(sheet, column: $0.index)).count < Set(values(sheet, column: $1.index)).count
        }
        if let x = text.first, let y = numeric.first {
            return ChartSuggestion(chartType: "bar", xColumn: x.name, yColumn: y.name,
                                   reasoning: "\(y.name) is numeric and \(x.name) groups the rows into few categories.")
        }
        if let x = text.first {
            return ChartSuggestion(chartType: "bar", xColumn: x.name, yColumn: "count",
                                   reasoning: "No numeric column; counting rows per \(x.name).")
        }
        if numeric.count >= 2 {
            return ChartSuggestion(chartType: "line", xColumn: numeric[0].name, yColumn: numeric[1].name,
                                   reasoning: "Two numeric columns; showing \(numeric[1].name) against \(numeric[0].name).")
        }
        let first = sheet.headers.first ?? "A"
        return ChartSuggestion(chartType: "bar", xColumn: first, yColumn: numeric.first?.name ?? "count",
                               reasoning: "Default chart of the first column.")
    }

    /// Duplicate rows, empty cells, leading/trailing whitespace, mixed-type columns.
    static func dataQuality(_ sheet: SheetData) -> String {
        guard sheet.rowCount > 1 else { return "The sheet has no data rows." }
        var seen = Set<String>(), dupes = 0, whitespace = 0
        for r in 1..<sheet.rowCount {
            let row = sheet.cells[r].map(\.displayValue)
            if row.allSatisfy(\.isEmpty) { continue }
            if !seen.insert(row.joined(separator: "\u{1F}")).inserted { dupes += 1 }
            whitespace += row.filter { !$0.isEmpty && $0 != $0.trimmingCharacters(in: .whitespaces) }.count
        }
        let mixed = sheet.headers.enumerated().filter { i, _ in
            guard let s = sheet.columnStats(i), !s.numbers.isEmpty else { return false }
            return s.numbers.count < s.count
        }.map(\.element)
        var lines = ["Duplicate rows: \(dupes)", "Empty cells: \(emptyCellCount(sheet))", "Cells with extra whitespace: \(whitespace)"]
        if !mixed.isEmpty { lines.append("Columns mixing numbers and text: \(mixed.prefix(10).joined(separator: ", "))") }
        return "Data quality check:\n• " + lines.joined(separator: "\n• ")
    }

    /// Rule-based pivot: columns named in the request (or the first text + numeric columns), aggregation from keywords.
    static func pivotSpec(query: String, sheet: SheetData) -> PivotSpec? {
        let q = query.lowercased()
        let numeric = numericColumns(sheet).map(\.name)
        let text = categoricalColumns(sheet).map(\.name)
        let agg: AggregationType = q.contains("average") || q.contains("mean") || q.contains("avg") ? .average
            : q.contains("count") || q.contains("how many") ? .count
            : q.contains("min") || q.contains("lowest") ? .min
            : q.contains("max") || q.contains("highest") ? .max : .sum
        let rows = text.filter { q.contains($0.lowercased()) }
        let vals = numeric.filter { q.contains($0.lowercased()) }
        guard let row = rows.first ?? text.first, let val = vals.first ?? numeric.first ?? (agg == .count ? row : nil) else { return nil }
        return PivotSpec(rowDimensions: Array(([row] + rows.dropFirst()).prefix(2)), columnDimensions: [],
                         values: [PivotSpec.ValueSpec(column: val, aggregation: agg)])
    }

    /// Spreadsheet column letter for a 0-based index.
    static func columnLetter(_ index: Int) -> String {
        var n = index, s = ""
        repeat { s = String(UnicodeScalar(65 + n % 26)!) + s; n = n / 26 - 1 } while n >= 0
        return s
    }

    /// Rule-based formula for "sum/average/count/min/max of <column name or letter>".
    static func formula(for request: String, headers: [String]) -> String? {
        let q = request.lowercased()
        let fn = q.contains("average") || q.contains("mean") ? "AVERAGE"
            : q.contains("count") ? "COUNTA"
            : q.contains("min") || q.contains("lowest") ? "MIN"
            : q.contains("max") || q.contains("highest") ? "MAX"
            : q.contains("sum") || q.contains("total") ? "SUM" : nil
        guard let fn else { return nil }
        var col: String?
        if let i = headers.firstIndex(where: { !$0.isEmpty && q.contains($0.lowercased()) }) {
            col = columnLetter(i)
        } else if let m = q.range(of: #"column ([a-z]{1,2})\b"#, options: .regularExpression) {
            col = String(q[m].dropFirst("column ".count)).uppercased()
        }
        guard let col else { return nil }
        return "=\(fn)(\(col):\(col))"
    }

    /// Workbook overview for the explainer/report.
    static func workbookOverview(_ workbook: WorkbookData) -> String {
        var out = "\(workbook.filename): \(workbook.sheets.count) sheet(s)."
        for sheet in workbook.sheets.prefix(5) { out += "\n\n" + summary(sheet) }
        return out
    }

    /// Chat answer without AI: route the question to the matching built-in analysis.
    static func answer(_ query: String, sheet: SheetData) -> String {
        let q = query.lowercased()
        if q.contains("chart") || q.contains("visual") || q.contains("graph") {
            let c = chartSuggestion(sheet)
            return "Suggested chart: \(c.chartType) of \(c.yColumn) by \(c.xColumn). \(c.reasoning)"
        }
        if q.contains("predict") || q.contains("forecast") || q.contains("next") { return predictions(sheet) }
        if q.contains("pattern") || q.contains("trend") || q.contains("correlat") || q.contains("outlier") { return patterns(sheet) }
        if q.contains("quality") || q.contains("duplicate") || q.contains("missing") || q.contains("error") { return dataQuality(sheet) }
        if q.contains("pivot"), let p = pivotSpec(query: query, sheet: sheet) {
            return "Suggested pivot: \(p.values.map { "\($0.aggregation.rawValue) of \($0.column)" }.joined(separator: ", ")) by \(p.rowDimensions.joined(separator: ", "))."
        }
        if q.contains("column") {
            return (0..<min(sheet.columnCount, 20)).map { explainColumn(sheet, columnIndex: $0) }.joined(separator: "\n")
        }
        return summary(sheet)
    }
}

extension NovaAISource {
    /// "AI · Ollama (qwen3:8b)" or "Built-in analysis (AI is off)" etc.
    var detailLabel: String {
        switch self {
        case .ai: return label
        case .fallback(.disabled): return "Built-in analysis (AI is off)"
        case .fallback(.unavailable): return "Built-in analysis (AI unavailable)"
        case .fallback(.validationFailed): return "Built-in analysis (AI reply rejected)"
        }
    }
}
