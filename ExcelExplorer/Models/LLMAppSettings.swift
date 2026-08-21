//
//  LLMAppSettings.swift
//  ExcelExplorer
//
//  Focused settings store for the multi-model LLM load balancer, mirroring the
//  subset of AIStudio's AppSettings that LLMBackendManager depends on. Named
//  LLMAppSettings (rather than the generic AppSettings) to keep ExcelExplorer's
//  global namespace clean. Values persist in UserDefaults; the OpenRouter API
//  key is never stored here — it lives in the Keychain via KeychainStore.
//
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

/// UserDefaults-backed settings for the LLM load-balancer subsystem.
final class LLMAppSettings: ObservableObject {
    static let shared = LLMAppSettings()

    private let defaults: UserDefaults

    // Backend endpoints (the manager subscribes to these publishers).
    @Published var ollamaURL: String { didSet { defaults.set(ollamaURL, forKey: "LLM_ollamaURL") } }
    @Published var tinyLLMURL: String { didSet { defaults.set(tinyLLMURL, forKey: "LLM_tinyLLMURL") } }
    @Published var tinyChatURL: String { didSet { defaults.set(tinyChatURL, forKey: "LLM_tinyChatURL") } }
    @Published var openWebUIURL: String { didSet { defaults.set(openWebUIURL, forKey: "LLM_openWebUIURL") } }
    @Published var openRouterURL: String { didSet { defaults.set(openRouterURL, forKey: "LLM_openRouterURL") } }
    @Published var novaGatewayURL: String { didSet { defaults.set(novaGatewayURL, forKey: "LLM_novaGatewayURL") } }

    // Selection / model state.
    @Published var activeLLMBackendType: String { didSet { defaults.set(activeLLMBackendType, forKey: "LLM_activeBackendType") } }
    @Published var selectedOllamaModel: String { didSet { defaults.set(selectedOllamaModel, forKey: "LLM_selectedOllamaModel") } }
    @Published var selectedOpenRouterModel: String { didSet { defaults.set(selectedOpenRouterModel, forKey: "LLM_selectedOpenRouterModel") } }
    @Published var pythonPath: String { didSet { defaults.set(pythonPath, forKey: "LLM_pythonPath") } }

    // The three load-balancing toggles.
    @Published var useAllLocalModels: Bool { didSet { defaults.set(useAllLocalModels, forKey: "LLM_useAllLocalModels") } }
    @Published var enableAllFrontierModels: Bool { didSet { defaults.set(enableAllFrontierModels, forKey: "LLM_enableAllFrontierModels") } }
    @Published var useNovaGateway: Bool { didSet { defaults.set(useNovaGateway, forKey: "LLM_useNovaGateway") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.ollamaURL = defaults.string(forKey: "LLM_ollamaURL") ?? "http://localhost:11434"
        self.tinyLLMURL = defaults.string(forKey: "LLM_tinyLLMURL") ?? "http://localhost:8000"
        self.tinyChatURL = defaults.string(forKey: "LLM_tinyChatURL") ?? "http://localhost:8000"
        self.openWebUIURL = defaults.string(forKey: "LLM_openWebUIURL") ?? "http://localhost:8080"
        self.openRouterURL = defaults.string(forKey: "LLM_openRouterURL") ?? OpenRouterProvider.baseURL
        self.novaGatewayURL = defaults.string(forKey: "LLM_novaGatewayURL") ?? ModelRegistry.novaGatewayDefaultURL
        self.activeLLMBackendType = defaults.string(forKey: "LLM_activeBackendType") ?? "auto"
        self.selectedOllamaModel = defaults.string(forKey: "LLM_selectedOllamaModel") ?? "mistral:latest"
        self.selectedOpenRouterModel = defaults.string(forKey: "LLM_selectedOpenRouterModel") ?? OpenRouterProvider.defaultModel
        self.pythonPath = defaults.string(forKey: "LLM_pythonPath") ?? "/opt/homebrew/bin/python3"
        self.useAllLocalModels = defaults.object(forKey: "LLM_useAllLocalModels") as? Bool ?? false
        self.enableAllFrontierModels = defaults.object(forKey: "LLM_enableAllFrontierModels") as? Bool ?? false
        self.useNovaGateway = defaults.object(forKey: "LLM_useNovaGateway") as? Bool ?? false
    }
}
