//
//  LLMChatMessage.swift
//  ExcelExplorer
//
//  Ported from AIStudio's ChatMessage. Renamed to LLMChatMessage / LLMChatRole
//  to avoid colliding with ExcelExplorer's existing UI `ChatMessage` type in
//  AIConversationView. Used by the multi-model load balancer's request builders.
//
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Role in a chat conversation
enum LLMChatRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

/// A single chat message for the LLM backend layer
struct LLMChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let role: LLMChatRole
    var content: String
    let timestamp: Date

    init(role: LLMChatRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}
