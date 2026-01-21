//
//  CellData.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import Foundation

// MARK: - Cell Reference
struct CellReference: Hashable, Codable {
    let column: Int
    let row: Int

    var excelNotation: String {
        columnLetter(column) + "\(row + 1)"
    }

    private func columnLetter(_ col: Int) -> String {
        var column = col
        var letter = ""
        while column >= 0 {
            letter = String(UnicodeScalar(65 + (column % 26))!) + letter
            column = column / 26 - 1
        }
        return letter
    }

    init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }

    init?(excelNotation: String) {
        let pattern = "^([A-Z]+)(\\d+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: excelNotation, range: NSRange(location: 0, length: excelNotation.count)),
              match.numberOfRanges == 3 else {
            return nil
        }

        let columnString = (excelNotation as NSString).substring(with: match.range(at: 1))
        let rowString = (excelNotation as NSString).substring(with: match.range(at: 2))

        guard let row = Int(rowString) else { return nil }

        var column = 0
        for (index, char) in columnString.enumerated() {
            let value = Int(char.asciiValue!) - 65
            column = column * 26 + value
            if index == columnString.count - 1 {
                column += 0
            } else {
                column += 1
            }
        }

        self.column = column
        self.row = row - 1
    }
}

// MARK: - Cell Value
indirect enum CellValue: Codable, Equatable {
    case empty
    case string(String)
    case number(Double)
    case date(Date)
    case bool(Bool)
    case formula(String, result: CellValue)

    var displayValue: String {
        switch self {
        case .empty:
            return ""
        case .string(let str):
            return str
        case .number(let num):
            return formatNumber(num)
        case .date(let date):
            return formatDate(date)
        case .bool(let bool):
            return bool ? "TRUE" : "FALSE"
        case .formula(_, let result):
            return result.displayValue
        }
    }

    var rawValue: String {
        switch self {
        case .empty:
            return ""
        case .string(let str):
            return str
        case .number(let num):
            return String(num)
        case .date(let date):
            return formatDate(date)
        case .bool(let bool):
            return bool ? "TRUE" : "FALSE"
        case .formula(let formula, _):
            return formula
        }
    }

    private func formatNumber(_ num: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = num.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: num)) ?? String(num)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Cell Formatting
struct CellFormatting: Codable {
    var isBold: Bool = false
    var isItalic: Bool = false
    var fontSize: Double = 12
    var textColor: String? = nil
    var backgroundColor: String? = nil
    var alignment: TextAlignment = .left
    var numberFormat: String? = nil

    enum TextAlignment: String, Codable {
        case left
        case center
        case right
    }
}

// MARK: - Cell Data
class CellData: Codable, Identifiable, ObservableObject {
    let id = UUID()
    var reference: CellReference
    @Published var value: CellValue
    @Published var formatting: CellFormatting

    var displayValue: String {
        value.displayValue
    }

    var isFormula: Bool {
        if case .formula = value {
            return true
        }
        return false
    }

    init(reference: CellReference, value: CellValue = .empty, formatting: CellFormatting = CellFormatting()) {
        self.reference = reference
        self.value = value
        self.formatting = formatting
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case reference, value, formatting
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reference = try container.decode(CellReference.self, forKey: .reference)
        value = try container.decode(CellValue.self, forKey: .value)
        formatting = try container.decode(CellFormatting.self, forKey: .formatting)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(reference, forKey: .reference)
        try container.encode(value, forKey: .value)
        try container.encode(formatting, forKey: .formatting)
    }
}
