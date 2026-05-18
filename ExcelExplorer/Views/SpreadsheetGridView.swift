//
//  SpreadsheetGridView.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import SwiftUI

struct SpreadsheetGridView: View {
    @EnvironmentObject var dataManager: ExcelDataManager
    @State private var selectedCell: CellReference?
    @State private var selectedCells: Set<CellReference> = []
    @State private var scrollPosition: CGPoint = .zero
    @State private var visibleRange: (rows: Range<Int>, columns: Range<Int>) = (0..<50, 0..<26)
    @State private var zoomLevel: Double = 100

    // Find functionality
    @State private var showFindPanel = false
    @State private var findText = ""
    @State private var findResults: [CellReference] = []
    @State private var currentFindIndex = 0

    // Cell dimensions
    private let cellWidth: CGFloat = 120
    private let cellHeight: CGFloat = 30
    private let headerWidth: CGFloat = 50
    private let headerHeight: CGFloat = 30

    var body: some View {
        GeometryReader { geometry in
            if let sheet = dataManager.currentSheet {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        // Main grid content
                        VStack(spacing: 0) {
                            // Column headers row
                            HStack(spacing: 0) {
                                // Top-left corner cell
                                Rectangle()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .frame(width: headerWidth, height: headerHeight)
                                    .border(Color.secondary.opacity(0.3), width: 0.5)

                                // Column headers (A, B, C, ...)
                                ForEach(visibleRange.columns, id: \.self) { col in
                                    Text(columnLetter(col))
                                        .font(.system(size: 11, weight: .medium))
                                        .frame(width: cellWidth * (zoomLevel / 100), height: headerHeight)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .border(Color.secondary.opacity(0.3), width: 0.5)
                                }
                            }

                            // Data rows
                            ForEach(visibleRange.rows, id: \.self) { row in
                                HStack(spacing: 0) {
                                    // Row number
                                    Text("\(row + 1)")
                                        .font(.system(size: 11, weight: .medium))
                                        .frame(width: headerWidth, height: cellHeight * (zoomLevel / 100))
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .border(Color.secondary.opacity(0.3), width: 0.5)

                                    // Cells
                                    ForEach(visibleRange.columns, id: \.self) { col in
                                        if let cell = sheet.getCell(row: row, column: col) {
                                            CellView(
                                                cell: cell,
                                                isSelected: selectedCell == cell.reference,
                                                width: cellWidth * (zoomLevel / 100),
                                                height: cellHeight * (zoomLevel / 100)
                                            )
                                            .onTapGesture {
                                                selectCell(cell.reference)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .onChange(of: dataManager.currentSheet?.id) { _ in
                    // Reset scroll and visible range when sheet changes
                    visibleRange = (0..<50, 0..<26)
                    selectedCell = nil
                }
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        HStack {
                            Button(action: { zoomLevel = max(50, zoomLevel - 10) }) {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            .help("Zoom out")

                            Text("\(Int(zoomLevel))%")
                                .frame(width: 50)
                                .font(.caption)

                            Button(action: { zoomLevel = min(200, zoomLevel + 10) }) {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .help("Zoom in")

                            Button(action: { zoomLevel = 100 }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .help("Reset zoom")
                        }
                    }
                }
            } else {
                Text("No sheet loaded")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func columnLetter(_ col: Int) -> String {
        var column = col
        var letter = ""
        while column >= 0 {
            letter = String(UnicodeScalar(65 + (column % 26))!) + letter
            column = column / 26 - 1
            if column < 0 { break }
        }
        return letter
    }

    private func selectCell(_ reference: CellReference) {
        selectedCell = reference
        NotificationCenter.default.post(name: .cellSelected, object: reference)
    }
}

// MARK: - Cell View
struct CellView: View {
    @ObservedObject var cell: CellData
    let isSelected: Bool
    let width: CGFloat
    let height: CGFloat

    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            if isEditing {
                // Editing mode
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 4)
                    .focused($isFocused)
                    .onSubmit {
                        commitEdit()
                    }
                    .onAppear {
                        editText = cell.value.rawValue
                        isFocused = true
                    }
            } else {
                // Display mode
                Text(cell.displayValue)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        startEditing()
                    }
            }
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(isSelected ? Color.cyan.opacity(0.15) : Color.clear)
        )
        .border(
            isSelected ? Color.cyan : Color.secondary.opacity(0.3),
            width: isSelected ? 2 : 0.5
        )
    }

    private func startEditing() {
        isEditing = true
    }

    private func commitEdit() {
        // Update cell value through data manager
        // This will be handled by ExcelDataManager
        isEditing = false
        isFocused = false
    }
}
