//
//  VoiceCommands.swift
//  ExcelExplorer
//
//  Created by Jordan Koch on 2026-01-21.
//  Voice command integration using Speech framework
//

import Foundation
import Speech
import AVFoundation

@MainActor
class VoiceCommandHandler: NSObject, ObservableObject {
    @Published var isListening: Bool = false
    @Published var transcribedText: String = ""
    @Published var lastCommand: String = ""
    @Published var error: String?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let aiManager = AIBackendManager.shared

    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }

    // MARK: - Request Authorization
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                self.authorizationStatus = status
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    self.error = "Speech recognition denied"
                case .restricted:
                    self.error = "Speech recognition restricted"
                case .notDetermined:
                    self.error = "Speech recognition not determined"
                @unknown default:
                    self.error = "Speech recognition unknown status"
                }
            }
        }
    }

    // MARK: - Start Listening
    func startListening() throws {
        // Cancel any previous task
        stopListening()

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceError.recognizerNotAvailable
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.cannotCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            Task { @MainActor in
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString

                    if result.isFinal {
                        self.processCommand(self.transcribedText)
                        self.stopListening()
                    }
                }

                if error != nil {
                    self.stopListening()
                }
            }
        }

        isListening = true
    }

    // MARK: - Stop Listening
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    // MARK: - Process Command
    private func processCommand(_ command: String) {
        lastCommand = command
        let lowercased = command.lowercased()

        // Parse and execute command
        if lowercased.contains("go to sheet") {
            handleGoToSheet(command: lowercased)
        } else if lowercased.contains("sum") || lowercased.contains("total") {
            handleSumCommand(command: lowercased)
        } else if lowercased.contains("chart") || lowercased.contains("graph") {
            handleChartCommand(command: lowercased)
        } else if lowercased.contains("export") {
            handleExportCommand(command: lowercased)
        } else if lowercased.contains("open") || lowercased.contains("load") {
            handleOpenCommand()
        } else if lowercased.contains("save") {
            handleSaveCommand()
        } else if lowercased.contains("analyze") {
            handleAnalyzeCommand(command: command)
        } else {
            // Use AI to interpret unknown commands
            Task {
                await interpretCommandWithAI(command: command)
            }
        }
    }

    // MARK: - Command Handlers
    private func handleGoToSheet(command: String) {
        // Extract sheet number or name
        let numbers = command.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }

        if let numberStr = numbers.first, let sheetIndex = Int(numberStr) {
            NotificationCenter.default.post(
                name: .voiceCommandGoToSheet,
                object: sheetIndex - 1
            )
        }
    }

    private func handleSumCommand(command: String) {
        // Extract column letter
        let pattern = "[A-Z]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let range = NSRange(command.startIndex..., in: command)
        if let match = regex.firstMatch(in: command, range: range),
           let range = Range(match.range, in: command) {
            let column = String(command[range])
            NotificationCenter.default.post(
                name: .voiceCommandSum,
                object: column
            )
        }
    }

    private func handleChartCommand(command: String) {
        NotificationCenter.default.post(name: .voiceCommandCreateChart, object: command)
    }

    private func handleExportCommand(command: String) {
        let format: String
        if command.contains("pdf") {
            format = "pdf"
        } else if command.contains("csv") {
            format = "csv"
        } else {
            format = "excel"
        }

        NotificationCenter.default.post(name: .voiceCommandExport, object: format)
    }

    private func handleOpenCommand() {
        NotificationCenter.default.post(name: .openFile, object: nil)
    }

    private func handleSaveCommand() {
        NotificationCenter.default.post(name: .saveFile, object: nil)
    }

    private func handleAnalyzeCommand(command: String) {
        NotificationCenter.default.post(name: .voiceCommandAnalyze, object: command)
    }

    // MARK: - AI Command Interpretation
    private func interpretCommandWithAI(command: String) async {
        let prompt = """
        The user said: "\(command)"

        This is a voice command for a spreadsheet application. Interpret what they want to do and respond with:
        1. The action type (navigate, calculate, export, analyze, modify)
        2. Specific parameters
        3. A brief confirmation message

        Keep response under 50 words.
        """

        do {
            let response = try await aiManager.generate(
                prompt: prompt,
                systemPrompt: "You are a voice command interpreter for spreadsheet software.",
                temperature: 0.3,
                maxTokens: 100
            )

            await MainActor.run {
                NotificationCenter.default.post(
                    name: .voiceCommandAI,
                    object: ["command": command, "interpretation": response]
                )
            }
        } catch {
            await MainActor.run {
                self.error = "Could not interpret command: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Quick Commands
    static let quickCommands = [
        "Go to Sheet 2",
        "Sum column B",
        "Create a chart showing sales by month",
        "Export this to PDF",
        "Analyze this data",
        "Open file",
        "Save",
        "Show me the total revenue"
    ]
}

// MARK: - Speech Recognizer Delegate
extension VoiceCommandHandler: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.error = "Speech recognition not available"
            }
        }
    }
}

// MARK: - Voice Error
enum VoiceError: Error {
    case recognizerNotAvailable
    case cannotCreateRequest
    case audioEngineError

    var localizedDescription: String {
        switch self {
        case .recognizerNotAvailable:
            return "Speech recognizer not available"
        case .cannotCreateRequest:
            return "Cannot create recognition request"
        case .audioEngineError:
            return "Audio engine error"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let voiceCommandGoToSheet = Notification.Name("voiceCommandGoToSheet")
    static let voiceCommandSum = Notification.Name("voiceCommandSum")
    static let voiceCommandCreateChart = Notification.Name("voiceCommandCreateChart")
    static let voiceCommandExport = Notification.Name("voiceCommandExport")
    static let voiceCommandAnalyze = Notification.Name("voiceCommandAnalyze")
    static let voiceCommandAI = Notification.Name("voiceCommandAI")
}
