//
//  FormulaBar.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import SwiftUI

struct FormulaBar: View {
    @EnvironmentObject var dataManager: ExcelDataManager
    @State private var selectedCell: CellReference?
    @State private var formulaText: String = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Cell reference label
            Text(selectedCell?.excelNotation ?? "A1")
                .font(.system(.body, design: .monospaced))
                .frame(width: 60, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                )

            // Formula input field
            TextField("Enter value or formula", text: $formulaText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isEditing ? Color.cyan : Color.secondary.opacity(0.3), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                )
                .focused($isEditing)
                .onSubmit {
                    commitEdit()
                }

            // Function button (fx)
            Button(action: {
                // Show function picker
            }) {
                Image(systemName: "function")
                    .font(.body)
            }
            .buttonStyle(.bordered)
            .help("Insert function")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .cellSelected)) { notification in
            if let reference = notification.object as? CellReference {
                selectedCell = reference
                updateFormulaText()
            }
        }
    }

    private func updateFormulaText() {
        guard let reference = selectedCell,
              let cell = dataManager.currentSheet?.getCell(at: reference) else {
            formulaText = ""
            return
        }

        // Show formula if it's a formula cell, otherwise show value
        if case .formula(let formula, _) = cell.value {
            formulaText = formula
        } else {
            formulaText = cell.value.rawValue
        }
    }

    private func commitEdit() {
        guard let reference = selectedCell else { return }
        dataManager.updateCell(at: reference, value: formulaText)
        isEditing = false
    }
}
