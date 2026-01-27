# ExcelExplorer v1.1.0

**AI-powered Excel file analyzer with native XLSX export and local AI processing**

View, analyze, and export Excel files with AI-powered insights—all running locally on your Mac with Apple MLX.

---

## What is ExcelExplorer?

ExcelExplorer is a native macOS application for viewing, analyzing, and exporting Excel files (.xlsx, .xls, .csv) with built-in AI capabilities. It provides a fast, native interface for working with spreadsheets and includes AI-powered features for data analysis, all running locally on Apple Silicon.

**Key Benefits:**
- **Native XLSX Export (v1.1.0)**: Full Excel format writing with proper OOXML structure
- **AI Analysis**: Summarize data, detect patterns, generate insights
- **MLX Backend (v1.1.0)**: Apple Silicon AI processing, 100% local
- **Fast Performance**: Native Swift implementation, no Electron overhead
- **Privacy First**: All processing on your Mac

**Perfect For:**
- **Data Analysts**: Quick Excel file viewing and analysis
- **Privacy-Conscious**: Keep sensitive data local
- **Apple Silicon Users**: Optimized for M1/M2/M3/M4
- **Developers**: Programmatic Excel export from Swift

---

## What's New in v1.1.0 (January 2026)

### 📊 XLSX Export Implementation
**Full Excel format writing:**

- **Complete OOXML Spec**: Proper XML structure ([Content_Types].xml, workbook.xml, worksheets, styles)
- **Shared Strings**: Efficient string deduplication
- **Multiple Data Types**: Text, numbers, booleans, dates, formulas
- **ZIP Compression**: Standard XLSX package format
- **Excel Compatible**: Opens in Excel, Numbers, LibreOffice
- **Large Dataset Support**: Up to 1,048,576 rows × 16,384 columns

**Usage:**
```swift
try await ExcelWriter.writeXLSX(workbook: workbook, to: outputURL)
```

**Technical Details:**
- Creates proper directory structure (_rels/, xl/, xl/worksheets/)
- Generates workbook.xml with sheet references
- Writes sharedStrings.xml for text deduplication
- Creates styles.xml for formatting
- Packages as ZIP with .xlsx extension

### 🚀 MLX Backend Implementation
**Apple Silicon native AI:**

- **Local Processing**: No cloud, no internet required
- **Model Support**: mlx-community models (Llama, Mistral, Phi)
- **Process Management**: Proper subprocess handling
- **Error Handling**: Installation detection and fallback
- **Performance**: Neural Engine acceleration

---

## Features

### Core Functionality
- **Excel File Viewing**: .xlsx, .xls, .csv support
- **Multi-Sheet Support**: Navigate between sheets
- **Cell Editing**: Modify cell values and formulas
- **XLSX Export (v1.1.0)**: Write native Excel format
- **CSV Export**: Standard CSV with customizable delimiters
- **Search & Filter**: Find data quickly
- **Formula Evaluation**: Calculate formula results

### AI Features
- **Data Summarization**: AI-generated dataset summaries
- **Pattern Detection**: Identify trends and anomalies
- **Column Analysis**: Automatic data type detection
- **Insights Generation**: AI-powered data insights
- **Query Interface**: Natural language data queries
- **MLX Backend (v1.1.0)**: Local AI processing

### Data Operations
- **Sort**: Sort by any column
- **Filter**: Filter rows by criteria
- **Search**: Find text across all sheets
- **Statistics**: Basic stats (sum, avg, min, max)
- **Duplicate Detection**: Find duplicate rows
- **Data Validation**: Type checking and validation

---

## Security

### Privacy & Data Protection
- **100% Local Processing**: Files never leave your Mac
- **No Cloud Upload**: All operations offline
- **MLX Backend**: AI runs on-device via Apple Neural Engine
- **No Telemetry**: Zero analytics or tracking
- **Keychain Storage**: Secure credential storage (if cloud AI used)

### File Security
- **Read-Only by Default**: Protects original files
- **Backup Before Save**: .backup files created
- **Input Validation**: Prevents malformed file attacks
- **Memory Safety**: Bounds checking on all array access

---

## Requirements

### System Requirements
- **macOS 13.0 (Ventura) or later**
- **Architecture**: Universal (Apple Silicon recommended for MLX)

### For MLX Backend
- **Apple Silicon**: M1/M2/M3/M4
- **Python 3.9+**
- **mlx-lm**: `pip install mlx-lm`
- **8GB+ RAM**

### For Ollama Backend
- **Any Mac**
- **Ollama**: `brew install ollama`
- **8GB+ RAM**

### Dependencies
**Built-in:**
- SwiftUI, AppKit, Foundation

**Optional:**
- mlx-lm (for MLX AI)
- Ollama (for Ollama AI)

---

## Installation

### Pre-built Binary

```bash
open "/Volumes/Data/xcode/binaries/20260127-ExcelExplorer-v1.1.0/ExcelExplorer-v1.1.0-build2.dmg"
```

### Build from Source

```bash
git clone https://github.com/kochj23/ExcelExplorer.git
cd ExcelExplorer
open "ExcelExplorer.xcodeproj"
# Press ⌘R to build and run
```

---

## Usage

### Open Excel File

```bash
# Launch app
open ~/Applications/ExcelExplorer.app

# Or open file directly
open -a ExcelExplorer ~/Documents/data.xlsx
```

### Export to XLSX

1. Open file in ExcelExplorer
2. Make any edits
3. File → Export → XLSX
4. Choose location
5. File saved in Excel format

### AI Analysis

1. Select data range
2. Click "AI Analyze"
3. Choose analysis type (summarize, patterns, insights)
4. View AI-generated analysis

---

## Troubleshooting

**Can't Open File:**
- Verify file is valid Excel format
- Check file permissions
- Try opening in Excel/Numbers first

**XLSX Export Fails:**
- Check disk space available
- Verify write permissions
- Try smaller dataset first

**MLX Not Working:**
- Install: `pip install mlx-lm`
- Verify: `which mlx_lm.generate`
- Check Apple Silicon Mac

---

## Version History

### v1.1.0 (January 2026)
- XLSX export implementation
- MLX backend integration
- Performance improvements

### v1.0.0 (2025)
- Initial release
- Excel viewing
- CSV export
- Basic AI features

---

## License

MIT License - Copyright © 2026 Jordan Koch

---

**Last Updated:** January 27, 2026
**Status:** ✅ Production Ready
