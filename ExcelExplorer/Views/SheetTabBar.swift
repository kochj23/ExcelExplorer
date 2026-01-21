//
//  SheetTabBar.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import SwiftUI

struct SheetTabBar: View {
    @EnvironmentObject var dataManager: ExcelDataManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if let workbook = dataManager.workbook {
                    ForEach(Array(workbook.sheets.enumerated()), id: \.element.id) { index, sheet in
                        SheetTab(
                            name: sheet.name,
                            isSelected: index == dataManager.currentSheetIndex,
                            action: {
                                dataManager.selectSheet(at: index)
                            }
                        )
                    }
                }

                // Add sheet button
                Button(action: addSheet) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .help("Add new sheet")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func addSheet() {
        guard let workbook = dataManager.workbook else { return }
        let newSheetNumber = workbook.sheets.count + 1
        let newSheet = SheetData(name: "Sheet \(newSheetNumber)", rows: 1000, columns: 26)
        workbook.addSheet(newSheet)
        dataManager.selectSheet(at: workbook.sheets.count - 1)
        dataManager.isDirty = true
    }
}

// MARK: - Individual Sheet Tab
struct SheetTab: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .frame(maxWidth: 120)

                // Close button (on hover)
                if isHovering {
                    Button(action: {}) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.cyan.opacity(0.2) : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? Color.cyan : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.borderless)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
