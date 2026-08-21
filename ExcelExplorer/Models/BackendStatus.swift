//
//  BackendStatus.swift
//  ExcelExplorer
//
//  Connection status for an LLM backend. Extracted verbatim from AIStudio's
//  BackendConfiguration.swift so the ported multi-model load balancer compiles
//  without pulling in AIStudio's image-generation backend types.
//
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Connection status for a backend
enum BackendStatus: Sendable, Equatable {
    case connected
    case disconnected
    case checking
    case error(String)

    var displayText: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .checking: return "Checking..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var statusColor: String {
        switch self {
        case .connected: return "green"
        case .disconnected: return "gray"
        case .checking: return "yellow"
        case .error: return "red"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
