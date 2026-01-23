# Excel Explorer

<div align="center">

🧠 **AI-Powered Excel/Spreadsheet Viewer and Editor for macOS**

[![Platform](https://img.shields.io/badge/platform-macOS%2013.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

</div>

---

## 🌟 Features

### Core Functionality
- ✅ **Full Editing Capabilities** - Edit cells, formulas, and data
- 📊 **Multiple File Formats** - Support for `.xlsx`, `.xls`, `.csv` (`.numbers` coming soon)
- 📑 **Multi-Sheet Support** - Navigate and edit multiple worksheets
- 🔍 **Formula Evaluation** - Basic formula support (SUM, AVERAGE, COUNT, MIN, MAX)
- 💾 **Export Options** - Export to CSV, PDF, and Excel formats

### AI-Powered Analysis
- 🤖 **Conversational Data Analysis** - Ask questions about your data in natural language
- 📈 **Pattern Detection** - AI identifies trends, correlations, and anomalies
- 🎯 **Predictions** - Forecast values based on existing data
- 📊 **Smart Chart Suggestions** - AI recommends the best chart type for your data
- 💡 **Column Explanations** - Understand what each column represents

### Advanced AI Features (v1.1+)
- 📊 **Predictive Analytics Dashboard** - Time series forecasting with confidence intervals, trend analysis, and seasonal patterns
- 🔄 **Smart Pivot Table Builder** - Create pivot tables from natural language ("Show total sales by region")
- 🔗 **Data Relationship Discovery** - Automatically find foreign keys, correlations, and dependencies across sheets
- 🎤 **Voice Commands** - Control spreadsheet with voice ("Go to Sheet 2", "Sum column B")
- 😊 **Sentiment Analysis** - Analyze text columns for sentiment, extract themes, generate insights

### Modern Interface
- 🎨 **Modern SwiftUI Design** - Clean, intuitive macOS-native interface
- 🔭 **Zoom Controls** - Adjust view from 50% to 200%
- ⌨️ **Keyboard Shortcuts** - Efficient workflow with macOS shortcuts
- 🎯 **Inline Editing** - Double-click cells to edit
- 📊 **Formula Bar** - View and edit formulas like in Excel

## 📸 Screenshots

![Excel Explorer Welcome Screen](assets/welcome-screen.png)
![Spreadsheet View with AI Panel](assets/main-view.png)
![AI Data Analysis](assets/ai-analysis.png)

## 🚀 Getting Started

### Installation

**Option 1: Download Pre-built Binary**
1. Download the latest release from [Releases](https://github.com/kochj23/ExcelExplorer/releases)
2. Drag `ExcelExplorer.app` to your `/Applications` folder
3. Launch Excel Explorer

**Option 2: Build from Source**
```bash
# Clone the repository
git clone https://github.com/kochj23/ExcelExplorer.git
cd ExcelExplorer

# Open in Xcode
open ExcelExplorer.xcodeproj

# Build and run (⌘R)
```

### System Requirements
- macOS 13.0 (Ventura) or later
- 100 MB free disk space
- Internet connection for AI features

## 🧠 AI Backend Configuration

Excel Explorer supports multiple AI backends:

- **Ollama** (Recommended) - `http://localhost:11434`
- **TinyLLM**
- **TinyChat**
- **OpenWebUI**
- **MLX** - Apple Silicon optimized

### Setting Up Ollama (Recommended)

1. Install Ollama from [ollama.com](https://ollama.com)
2. Pull a model:
   ```bash
   ollama pull mistral
   ```
3. Launch Excel Explorer and open Settings
4. Verify the backend URL: `http://localhost:11434`
5. Select your model (e.g., `mistral`)

## 📖 Usage

### Opening Files
- **File → Open** or `⌘O`
- Drag and drop supported files
- Supports: `.xlsx`, `.csv`, `.xls`

### Editing Cells
1. Click a cell to select it
2. Double-click to edit
3. Type your value or formula (start with `=`)
4. Press `Enter` to save

### Using AI Features

**Ask Questions**
```
"Summarize this data"
"What are the trends in sales?"
"Which product category has the highest revenue?"
"Predict next month's values"
```

**Quick Actions**
- 📋 **Summarize** - Get an overview of the sheet
- 🔍 **Find Patterns** - Identify trends and correlations
- 📊 **Generate Chart** - AI suggests visualization
- 🎯 **Predict Values** - Forecast future data

### Exporting Data
- **CSV Export** - `File → Export to CSV`
- **PDF Export** - `File → Export to PDF`
- **Excel Export** - `File → Export to Excel`

## 🎨 Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘O` | Open File |
| `⌘S` | Save |
| `⌘E` | Export |
| `⌘I` | Toggle AI Panel |
| `⇧⌘A` | Analyze Data |
| `⇧⌘B` | **Advanced AI Features** ⭐ |
| `⌘,` | Settings |
| `⌘Q` | Quit |

## 🛠️ Technical Details

### Architecture
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **AI Integration**: Custom AIBackendManager
- **Excel Parsing**: CoreXLSX (planned)
- **PDF Generation**: Core Graphics

### Project Structure
```
ExcelExplorer/
├── ExcelExplorerApp.swift       # App entry point
├── ContentView.swift             # Main UI
├── ExcelDataManager.swift        # Data management
├── Models/
│   ├── CellData.swift            # Cell model
│   ├── SheetData.swift           # Sheet model
│   └── WorkbookData.swift        # Workbook model
├── Views/
│   ├── SpreadsheetGridView.swift # Grid display
│   ├── AIConversationView.swift  # AI chat
│   ├── FormulaBar.swift          # Formula input
│   ├── SheetTabBar.swift         # Sheet switcher
│   └── SettingsView.swift        # Settings panel
├── AI/
│   └── AIDataAnalyzer.swift      # AI analysis
├── Parsers/
│   ├── CSVParser.swift           # CSV parsing
│   └── ExcelParser.swift         # Excel parsing
└── Export/
    ├── CSVExporter.swift         # CSV export
    ├── PDFExporter.swift         # PDF export
    └── ExcelWriter.swift         # Excel writing
```

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup
```bash
# Install dependencies
# (None currently - self-contained project)

# Build and run
open ExcelExplorer.xcodeproj
```

## 🐛 Known Issues & Limitations

- **Legacy .xls Support**: Limited support for binary Excel format (.xls). Please convert to .xlsx or .csv.
- **Formula Complexity**: Only basic formulas supported (SUM, AVG, COUNT, MIN, MAX). Complex Excel functions not yet implemented.
- **Large Files**: Performance may degrade with 100k+ rows. Pagination helps but large datasets are better handled in dedicated tools.
- **CoreXLSX Integration**: Full .xlsx parsing to be implemented in future update.

## 📚 Resources

- [Documentation](https://github.com/kochj23/ExcelExplorer/wiki)
- [Issue Tracker](https://github.com/kochj23/ExcelExplorer/issues)
- [Release Notes](https://github.com/kochj23/ExcelExplorer/releases)

## 🙏 Acknowledgments

- **CoreXLSX** - Excel parsing library
- **Ollama** - Local AI backend
- **Swift Charts** - Data visualization framework

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2026 Jordan Koch

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 👨‍💻 Author

**Jordan Koch**
- GitHub: [@kochj23](https://github.com/kochj23)

## 🌟 Star History

If you find this project useful, please consider giving it a ⭐!

---

<div align="center">
Built with ❤️ using SwiftUI and AI
</div>

---

**Last Updated:** January 22, 2026
**Status:** ✅ Production Ready
