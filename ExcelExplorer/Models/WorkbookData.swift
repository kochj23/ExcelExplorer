//
//  WorkbookData.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//

import Foundation
import AppKit

class WorkbookData: ObservableObject {
    @Published var filename: String
    @Published var sheets: [SheetData]
    @Published var metadata: FileMetadata
    @Published var embeddedImages: [NSImage]
    var fileURL: URL?

    init(filename: String, sheets: [SheetData] = [], metadata: FileMetadata = FileMetadata(), embeddedImages: [NSImage] = []) {
        self.filename = filename
        self.sheets = sheets
        self.metadata = metadata
        self.embeddedImages = embeddedImages
    }

    func getSheet(named name: String) -> SheetData? {
        sheets.first { $0.name == name }
    }

    func getSheet(at index: Int) -> SheetData? {
        guard index >= 0 && index < sheets.count else { return nil }
        return sheets[index]
    }

    func addSheet(_ sheet: SheetData) {
        sheets.append(sheet)
    }

    func removeSheet(at index: Int) {
        guard index >= 0 && index < sheets.count else { return }
        sheets.remove(at: index)
    }
}

// MARK: - File Metadata
struct FileMetadata {
    var createdDate: Date?
    var modifiedDate: Date?
    var author: String?
    var lastModifiedBy: String?
    var company: String?
    var fileSize: Int64?

    init(createdDate: Date? = nil, modifiedDate: Date? = nil, author: String? = nil, lastModifiedBy: String? = nil, company: String? = nil, fileSize: Int64? = nil) {
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.author = author
        self.lastModifiedBy = lastModifiedBy
        self.company = company
        self.fileSize = fileSize
    }
}
