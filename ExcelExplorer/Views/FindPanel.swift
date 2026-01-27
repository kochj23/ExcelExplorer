//
//  FindPanel.swift
//  ExcelExplorer
//
//  Find and replace functionality for spreadsheets
//  Created by Jordan Koch on 2026-01-27
//

import SwiftUI

struct FindPanel: View {
    @Binding var isPresented: Bool
    @Binding var searchText: String
    @Binding var results: [CellReference]
    @Binding var currentIndex: Int

    let onNext: () -> Void
    let onPrevious: () -> Void
    let onReplaceAll: (String) -> Void

    @State private var replaceText = ""
    @State private var matchCase = false
    @State private var matchWholeCell = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                Text("Find in Sheet")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
            }

            Divider()

            // Find field
            HStack {
                TextField("Find", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Text("\(results.isEmpty ? 0 : currentIndex + 1) of \(results.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70)

                Button(action: onPrevious) {
                    Image(systemName: "chevron.up")
                }
                .disabled(results.isEmpty)
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Button(action: onNext) {
                    Image(systemName: "chevron.down")
                }
                .disabled(results.isEmpty)
                .keyboardShortcut("g", modifiers: .command)
            }

            // Replace field
            HStack {
                TextField("Replace with", text: $replaceText)
                    .textFieldStyle(.roundedBorder)

                Button("Replace All") {
                    onReplaceAll(replaceText)
                }
                .disabled(results.isEmpty || replaceText.isEmpty)
            }

            // Options
            HStack {
                Toggle("Match case", isOn: $matchCase)
                Toggle("Whole cell", isOn: $matchWholeCell)
                Spacer()
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 500)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
