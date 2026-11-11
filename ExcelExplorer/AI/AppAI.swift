//
//  AppAI.swift
//  ExcelExplorer
//
//  The app's one AI object (NovaAIKit 1.0.0). Settings persist in UserDefaults (no secrets); keys live only in the
//  Keychain under com.jkoch.excelexplorer.<backend>. Every AI feature goes through `AppAI.shared` and has a
//  built-in (non-AI) fallback, so the app works with AI off or every backend down.
//

import Foundation
import NovaAIKit

@MainActor
enum AppAI {
    nonisolated static let appID = "excelexplorer"
    nonisolated static let appName = "Excel Explorer"

    static let shared: NovaAI = {
        let configuration = NovaAIConfiguration(appID: appID, appName: appName)
        if isRunningTests {
            // Unit tests host the app: never read or migrate the real settings/Keychain there.
            return NovaAI(configuration: configuration, storage: NovaAIMemoryStorage(), keyStore: NovaAIMemoryKeyStore())
        }
        let ai = NovaAI(configuration: configuration)
        AppAI.migrateLegacy(ai)
        return ai
    }()

    /// True when the app is the host of an XCTest run.
    nonisolated static var isRunningTests: Bool {
        // Environment only: NSClassFromString("XCTestCase") is non-nil in normal runs on current macOS.
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Footer shown under the AI settings.
    static let settingsFooter = "When AI is off or no backend answers, Excel Explorer uses its built-in analysis: "
        + "column statistics, rule-based chart and pivot suggestions, a linear-trend forecast, keyword sentiment "
        + "and data-quality checks. Nothing leaves this Mac unless you pick a cloud backend."
}

// MARK: - One-time migration from the pre-NovaAIKit AI manager and load balancer

extension AppAI {
    /// Old Keychain service of the copy-pasted AI manager (accounts were the UserDefaults key names).
    static let legacyKeychainService = "com.jordankoch.ExcelExplorer"
    /// Old Keychain service of the multi-model balancer's OpenRouter key (ExcelExplorer's own).
    static let legacyOpenRouterService = "com.jordankoch.excelexplorer.openrouter"
    /// Accounts the old AI manager used for the removed Google/Azure/AWS/IBM backends.
    static let legacyObsoleteAccounts = [
        "AIBackend_GoogleCloud_Key", "AIBackend_Azure_Key", "AIBackend_Azure_Endpoint",
        "AIBackend_AWS_AccessKey", "AIBackend_AWS_SecretKey", "AIBackend_IBM_Key", "AIBackend_IBM_URL",
    ] + NovaAIKeys.obsoleteLegacyAccounts
    /// UserDefaults keys of the old balancer (`LLMAppSettings`) and settings tab that have no successor.
    static let legacyBalancerKeys = [
        "LLM_activeBackendType", "LLM_enableAllFrontierModels", "LLM_novaGatewayURL", "LLM_ollamaURL",
        "LLM_openRouterURL", "LLM_openWebUIURL", "LLM_pythonPath", "LLM_selectedOllamaModel",
        "LLM_selectedOpenRouterModel", "LLM_tinyChatURL", "LLM_tinyLLMURL", "LLM_useAllLocalModels",
        "LLM_useNovaGateway", "aiBackendURL", "aiModel", "aiTemperature", "aiMaxTokens",
    ]

    /// Runs once per launch; every step is idempotent.
    static func migrateLegacy(_ ai: NovaAI, defaults: UserDefaults = .standard) {
        // 3a. Old AI manager UserDefaults: backend, URLs, Ollama model, on/off. A plaintext OpenAI key in
        //     UserDefaults moves to the Keychain; Google/Azure/AWS/IBM secrets and the guardian prompt log are deleted.
        ai.migrateFromLegacyAIBackendManager(defaults: defaults)
        migrateBalancerSettings(ai, defaults: defaults)

        // 3b. Old Keychain items → com.jkoch.excelexplorer.<backend> (copy, verify, then delete: ExcelExplorer's own).
        //     The old manager used the UserDefaults key names as Keychain accounts.
        for account in NovaAILegacySettings.openAIKeyKeys {
            ai.migrateLegacyKey(service: legacyKeychainService, account: account, to: .openAI, deleteLegacy: true)
        }
        ai.migrateLegacyKey(service: legacyOpenRouterService, account: "apiKey", to: .openRouter, deleteLegacy: true)

        // 3c. Delete the removed backends' secrets (deletes only; never reads them out).
        ai.keys.deleteObsoleteLegacyItems(service: legacyKeychainService, accounts: legacyObsoleteAccounts)
    }

    /// The old load balancer kept its own URLs/models under `LLM_*`. Import the ones that differ from the
    /// defaults (once, before NovaAIKit settings exist), then drop all of them.
    static func migrateBalancerSettings(_ ai: NovaAI, defaults: UserDefaults) {
        guard legacyBalancerKeys.contains(where: { defaults.object(forKey: $0) != nil }) else { return }
        var s = ai.settings
        let urlKeys: [(String, NovaAIBackend)] = [
            ("LLM_ollamaURL", .ollama), ("LLM_tinyLLMURL", .tinyLLM), ("LLM_tinyChatURL", .tinyChat),
            ("LLM_openWebUIURL", .openWebUI), ("LLM_novaGatewayURL", .novaGateway),
        ]
        for (key, backend) in urlKeys where s.urls[backend.rawValue] == nil {
            if let v = defaults.string(forKey: key), !v.isEmpty { s.setURL(v, for: backend) }
        }
        if s.models[NovaAIBackend.ollama.rawValue] == nil, let m = defaults.string(forKey: "LLM_selectedOllamaModel"), !m.isEmpty {
            s.setModel(m, for: .ollama)
        }
        if s.models[NovaAIBackend.openRouter.rawValue] == nil, let m = defaults.string(forKey: "LLM_selectedOpenRouterModel"), !m.isEmpty {
            s.setModel(m, for: .openRouter)
        }
        if s != ai.settings { ai.settings = s }
        legacyBalancerKeys.forEach { defaults.removeObject(forKey: $0) }
    }
}

// MARK: - Request helper

extension NovaAI {
    /// One-shot text with the never-throwing contract: AI reply (validated) or `fallback` when AI is off,
    /// unreachable or the reply is rejected twice.
    func ask(_ prompt: String, system: String, temperature: Double, maxTokens: Int,
             validate: @escaping @Sendable (String) throws -> String = ExcelAIValidators.analysisText,
             fallback: @escaping @Sendable () -> String) async -> NovaAIResult<String> {
        await text(NovaAIRequest(prompt: prompt, system: system, temperature: temperature, maxTokens: maxTokens),
                   validate: validate, fallback: fallback)
    }
}

extension NovaAIResult where Value == String {
    /// The value with a one-line source footer ("AI · Ollama (qwen3:8b)" / "Built-in analysis (AI is off)").
    var labeled: String { "\(value)\n\n— \(source.detailLabel)" }
}
