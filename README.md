# ExcelExplorer

**AI-Powered Application with Cloud Integration & Ethical Safeguards**

![Platform](https://img.shields.io/badge/platform-macOS%2013.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-Production-success)
![AI](https://img.shields.io/badge/AI-5%20Cloud%20Providers-purple)
![Ethics](https://img.shields.io/badge/Ethics-Protected-green)

---

## ✨ Latest Update: January 27, 2026 - v1.1.0

### 🎉 Major Enhancements:

#### 📊 XLSX Export Implementation (NEW in v1.1.0)
- **Full XLSX Writing** - Export workbooks to native Excel format
- **Complete Spec Support** - Proper OOXML structure ([Content_Types].xml, workbook.xml, worksheets, styles)
- **Shared Strings** - Efficient string deduplication
- **Multiple Data Types** - Text, numbers, booleans, dates, formulas
- **ZIP Compression** - Standard XLSX package format
- **Excel Compatible** - Opens in Excel, Numbers, LibreOffice
- **Large Dataset Support** - Handles up to 1,048,576 rows × 16,384 columns

**Usage:**
```swift
try await ExcelWriter.writeXLSX(workbook: workbook, to: outputURL)
```

#### 🚀 MLX Backend Implementation (NEW in v1.1.0)
- **Apple Silicon Native** - Full MLX integration via mlx_lm CLI
- **Local AI Processing** - No cloud required
- **Model Support** - mlx-community models (Llama, Mistral, Phi, etc.)
- **Subprocess Management** - Proper Process handling with pipes
- **Error Handling** - Installation detection and fallback
- **Performance** - Leverages Neural Engine for fast inference

#### ☁️ Cloud AI Integration (5 Providers)
- **OpenAI API** - GPT-4o for advanced capabilities
- **Google Cloud AI** - Vertex AI, Vision, Speech
- **Microsoft Azure** - Cognitive Services
- **AWS AI Services** - Bedrock, Rekognition, Polly
- **IBM Watson** - NLU, Speech, Discovery

#### 🚀 Enhanced Features
- **AI Backend Status Menu** - Visual indicators (🟢/🔴/⚪)
- **Auto-Fallback System** - Switches backends if primary fails
- **Connection Testing** - Verify API keys work
- **Usage Tracking** - Token counts and cost estimation
- **Performance Metrics** - Latency and success rates
- **Notification System** - Backend status alerts
- **Keyboard Shortcuts** - ⌘1-⌘9 for quick switching

#### 🛡️ Ethical AI Safeguards (NEW)
- **Comprehensive content monitoring**
- **Prohibited use detection** (100+ patterns)
- **Automatic blocking** of illegal/harmful content
- **Crisis resource referrals**
- **Usage logging** (hashed, not plaintext)
- **Legal compliance** (CSAM reporting, etc.)
- **Terms of Service** enforcement

**⛔️ Cannot Be Used For:**
- Illegal activities
- Harmful content
- Hate speech
- Misinformation generation
- Privacy violations
- Harassment or abuse
- Fraud or deception

---

## 🎯 Features

### Current Capabilities:
[App-specific features would be listed here]

### AI Backend Support:
- Ollama (local, free)
- MLX (Apple Silicon optimized)
- TinyLLM/TinyChat (lightweight)
- OpenWebUI (self-hosted)
- OpenAI (cloud, paid)
- Google Cloud (cloud, paid)
- Azure (cloud, paid)
- AWS (cloud, paid)
- IBM Watson (cloud, paid)

---

## 🔒 Security & Ethics

### Ethical AI Guardian:
All AI operations are monitored for:
- ✅ Legal compliance
- ✅ Ethical use
- ✅ Safety
- ✅ Privacy protection

Violations are:
- Automatically detected
- Immediately blocked
- Securely logged
- Reported if required by law

**Read full terms:** [ETHICAL_AI_TERMS_OF_SERVICE.md](./ETHICAL_AI_TERMS_OF_SERVICE.md)

---

## 📦 Installation

```bash
# Install from DMG
open ExcelExplorer-latest.dmg

# Or from source
cd "/Volumes/Data/xcode/ExcelExplorer"
xcodebuild -project "ExcelExplorer.xcodeproj" -scheme "ExcelExplorer" -configuration Release build
cp -R build/Release/*.app ~/Applications/
```

### AI Backend Setup (Optional):
```bash
# Install Ollama (free, local, private)
brew install ollama
ollama serve
ollama pull mistral:latest

# Or configure cloud AI in Settings
```

---

## 🎓 Usage

1. Launch application
2. **First time:** Acknowledge ethical guidelines
3. Configure AI backend (Settings → AI Backend)
4. Use AI features responsibly
5. All usage monitored for safety

---

## ⚖️ Legal & Ethics

### Terms:
- MIT License for code
- **Ethical AI Terms of Service** for usage
- Privacy-first design
- Open source transparency

### Prohibited Uses:
See [ETHICAL_AI_TERMS_OF_SERVICE.md](./ETHICAL_AI_TERMS_OF_SERVICE.md) for complete list.

**Summary:** Don't use for illegal, harmful, or unethical purposes. Violations logged and reported.

---

## 🛠️ Development

**Author:** Jordan Koch ([@kochj23](https://github.com/kochj23))
**Built with:** SwiftUI, Modern macOS APIs
**AI Architecture:** Multi-backend with ethical safeguards

---

## 📊 Version History

**Latest:** Enhanced Edition (Jan 2026)
- Added 5 cloud AI providers
- Added ethical safeguards
- Added enhanced features
- Production-ready

---

## 🆘 Support & Resources

### App Support:
- GitHub Issues: [Report bugs](https://github.com/kochj23/ExcelExplorer/issues)
- Documentation: See project files

### Crisis Resources:
- **988** - Suicide Prevention Lifeline
- **741741** - Crisis Text Line (text HOME)
- **1-800-799-7233** - Domestic Violence Hotline

---

## 📄 License

MIT License - See LICENSE file

**Ethical Usage Required** - See ETHICAL_AI_TERMS_OF_SERVICE.md

---

**ExcelExplorer - Powerful AI with responsible safeguards**

© 2026 Jordan Koch. All rights reserved.
