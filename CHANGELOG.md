# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-11-11

### Changed
- AI: migrated to NovaAIKit 1.0.0 (one AI object `AppAI`, Settings › AI with on/off, backend picker for Auto/Ollama/MLX/TinyLLM/TinyChat/OpenWebUI/Nova Gateway/OpenRouter/OpenAI, model picker, editable URLs, Keychain-only https-only keys under `com.jkoch.excelexplorer.*`, status indicator, Auto failover with timeouts and retries).
- Every AI feature now has a built-in (non-AI) result and validates AI replies (charts and pivots must use real columns, formulas must parse, forecast figures must come from the data, no code in analyses); answers show their source.
- AI menu commands (Analyze, Explain, Insights, Report, Clean, Formula, Chart, Patterns, Predict) now run in the AI panel; previously they did nothing.
- Version and build number now come from the project settings (Info.plist used hard-coded values).

### Removed
- The app's own AI manager, status menu, ethics guardian, AI capability stubs, multi-model load balancer, OpenRouter client and in-process MLX generator (and the mlx-swift packages).
- Google Cloud, Azure, AWS and IBM Watson AI backends and their stored secrets.

### Security
- One-time migration moves the OpenAI/OpenRouter keys from `com.jordankoch.ExcelExplorer` / `com.jordankoch.excelexplorer.openrouter` to `com.jkoch.excelexplorer.*`, deletes the old items after a verified copy, and removes plaintext keys and the prompt log that older versions left in UserDefaults.
- Tests no longer read files from a hard-coded checkout path.

### Fixed
- All compiler warnings (unused values, deprecated `onChange`, missing asset colors).

## [1.0.0] - 2025-01-01

### Added
- Initial release
- Core functionality
- macOS native interface
- MIT License

---

*For detailed release notes, see [GitHub Releases](https://github.com/kochj23/ExcelExplorer/releases).*
