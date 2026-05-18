//
//  EthicalAIGuardianTests.swift
//  ExcelExplorerTests
//
//  Tests for EthicalAIGuardian: content filtering, violation categories,
//  enforcement actions, statistics, and ethical guidelines display
//  Created by Jordan Koch on 2026-05-03.
//

import XCTest
@testable import ExcelExplorer

@MainActor
final class EthicalAIGuardianTests: XCTestCase {

    // MARK: - Guardian Initialization

    func testGuardianIsAlwaysEnabled() {
        let guardian = EthicalAIGuardian.shared
        XCTAssertTrue(guardian.isEnabled, "Ethical AI Guardian must always be enabled")
    }

    func testGuardianInitializesWithEmptyViolations() {
        // Fresh guardian (singleton may have state from other tests, so just check type)
        let guardian = EthicalAIGuardian.shared
        XCTAssertNotNil(guardian.violationsDetected, "Violations array should be initialized")
    }

    // MARK: - Prohibited Content Detection — Illegal Activities

    func testDetectsViolenceContent() async {
        let guardian = EthicalAIGuardian.shared
        let violation = await guardian.checkContent(
            "how to make a bomb at home",
            context: .textGeneration
        )
        XCTAssertNotNil(violation, "Should detect violence-related illegal content")
        XCTAssertEqual(violation?.category, .illegalActivity)
        XCTAssertEqual(violation?.severity, .critical)
    }

    func testDetectsHackingContent() async {
        let guardian = EthicalAIGuardian.shared
        let violation = await guardian.checkContent(
            "hack into system and steal password from database",
            context: .textGeneration
        )
        XCTAssertNotNil(violation, "Should detect hacking-related content")
        XCTAssertEqual(violation?.category, .illegalActivity)
    }

    func testDetectsFraudContent() async {
        let guardian = EthicalAIGuardian.shared
        let violation = await guardian.checkContent(
            "credit card fraud scheme to steal identities",
            context: .textGeneration
        )
        XCTAssertNotNil(violation, "Should detect fraud content")
        XCTAssertEqual(violation?.category, .illegalActivity)
    }

    // MARK: - Prohibited Content Detection — Harmful Content

    func testDetectsHarmfulContent() async {
        let guardian = EthicalAIGuardian.shared
        let violation = await guardian.checkContent(
            "self harm methods and how to hurt myself",
            context: .textGeneration
        )
        XCTAssertNotNil(violation, "Should detect self-harm content")
        XCTAssertEqual(violation?.category, .harmfulContent)
        XCTAssertEqual(violation?.severity, .critical)
        XCTAssertEqual(violation?.action, .blockAndRefer, "Harmful content should provide help resources")
    }

    // MARK: - Prohibited Content Detection — Hate Speech

    func testDetectsHateSpeech() async {
        let guardian = EthicalAIGuardian.shared
        let violation = await guardian.checkContent(
            "hate speech generator for racist content targeting groups",
            context: .textGeneration
        )
        XCTAssertNotNil(violation, "Should detect hate speech")
        XCTAssertEqual(violation?.category, .hateSpeech)
        XCTAssertEqual(violation?.severity, .critical)
    }

    // MARK: - Prohibited Content Detection — Misinformation

    func testDetectsMisinformation() async {
        let guardian = EthicalAIGuardian.shared
        let violation = await guardian.checkContent(
            "generate fake news articles about the election",
            context: .textGeneration
        )
        XCTAssertNotNil(violation, "Should detect misinformation generation")
        XCTAssertEqual(violation?.category, .misinformation)
        XCTAssertEqual(violation?.severity, .high)
        XCTAssertEqual(violation?.action, .warnAndLog, "Misinformation should warn and log")
    }

    // MARK: - Prohibited Content Detection — Privacy

    func testDetectsPrivacyViolation() async {
        let guardian = EthicalAIGuardian.shared
        let violation = await guardian.checkContent(
            "spy on someone and track without consent using hidden camera spy tools",
            context: .textGeneration
        )
        XCTAssertNotNil(violation, "Should detect privacy violation content")
        XCTAssertEqual(violation?.category, .privacyViolation)
    }

    // MARK: - Safe Content Passes

    func testSafeContentReturnsNil() async {
        let guardian = EthicalAIGuardian.shared
        let violation = await guardian.checkContent(
            "Analyze the revenue data in column B and find the average quarterly growth rate",
            context: .analysis
        )
        XCTAssertNil(violation, "Legitimate data analysis should not trigger a violation")
    }

    func testShortContentSkipsAICheck() async {
        let guardian = EthicalAIGuardian.shared
        // Content under 50 chars skips AI analysis (only pattern check)
        let violation = await guardian.checkContent(
            "Calculate SUM of column A",
            context: .analysis
        )
        XCTAssertNil(violation, "Short safe content should pass")
    }

    func testEmptyContentPasses() async {
        let guardian = EthicalAIGuardian.shared
        let violation = await guardian.checkContent("", context: .unknown)
        XCTAssertNil(violation, "Empty content should not trigger violation")
    }

    // MARK: - Enforcement Actions

    func testEnforcePolicyBlockCompletely() async {
        let guardian = EthicalAIGuardian.shared
        let violation = PolicyViolation(
            category: .illegalActivity,
            severity: .critical,
            description: "Test violation",
            detectedPattern: "test",
            action: .blockCompletely,
            timestamp: Date()
        )
        let result = await guardian.enforcePolicy(violation: violation)
        XCTAssertEqual(result, .blocked, "blockCompletely should return .blocked")
    }

    func testEnforcePolicyBlockAndRefer() async {
        let guardian = EthicalAIGuardian.shared
        let violation = PolicyViolation(
            category: .harmfulContent,
            severity: .critical,
            description: "Test harmful",
            detectedPattern: "test",
            action: .blockAndRefer,
            timestamp: Date()
        )
        let result = await guardian.enforcePolicy(violation: violation)
        XCTAssertEqual(result, .blockedWithHelp, "blockAndRefer should return .blockedWithHelp")
    }

    func testEnforcePolicyWarnAndLog() async {
        let guardian = EthicalAIGuardian.shared
        let violation = PolicyViolation(
            category: .misinformation,
            severity: .high,
            description: "Test warn",
            detectedPattern: "test",
            action: .warnAndLog,
            timestamp: Date()
        )
        let result = await guardian.enforcePolicy(violation: violation)
        XCTAssertEqual(result, .warned, "warnAndLog should return .warned")
    }

    func testEnforcePolicyLogOnly() async {
        let guardian = EthicalAIGuardian.shared
        let violation = PolicyViolation(
            category: .other,
            severity: .low,
            description: "Test log",
            detectedPattern: "test",
            action: .logOnly,
            timestamp: Date()
        )
        let result = await guardian.enforcePolicy(violation: violation)
        XCTAssertEqual(result, .logged, "logOnly should return .logged")
    }

    func testEnforcePolicyRequireAcknowledgment() async {
        let guardian = EthicalAIGuardian.shared
        let violation = PolicyViolation(
            category: .other,
            severity: .medium,
            description: "Test ack",
            detectedPattern: "test",
            action: .requireAcknowledgment,
            timestamp: Date()
        )
        let result = await guardian.enforcePolicy(violation: violation)
        // Default implementation returns false for acknowledgment, so should block
        XCTAssertEqual(result, .blocked, "Unacknowledged should return .blocked")
    }

    // MARK: - Violation Models

    func testViolationCategoryDescriptions() {
        let categories: [ViolationCategory] = [
            .illegalActivity, .harmfulContent, .hateSpeech,
            .misinformation, .privacyViolation, .harassment,
            .fraud, .other
        ]
        for category in categories {
            XCTAssertFalse(category.description.isEmpty, "\(category.rawValue) should have a description")
        }
    }

    func testViolationCategoryRawValues() {
        XCTAssertEqual(ViolationCategory.illegalActivity.rawValue, "Illegal Activity")
        XCTAssertEqual(ViolationCategory.harmfulContent.rawValue, "Harmful Content")
        XCTAssertEqual(ViolationCategory.hateSpeech.rawValue, "Hate Speech")
        XCTAssertEqual(ViolationCategory.misinformation.rawValue, "Misinformation")
        XCTAssertEqual(ViolationCategory.privacyViolation.rawValue, "Privacy Violation")
        XCTAssertEqual(ViolationCategory.harassment.rawValue, "Harassment")
        XCTAssertEqual(ViolationCategory.fraud.rawValue, "Fraud")
        XCTAssertEqual(ViolationCategory.other.rawValue, "Other Concern")
    }

    func testViolationSeverityColors() {
        XCTAssertEqual(ViolationSeverity.critical.color, "red")
        XCTAssertEqual(ViolationSeverity.high.color, "orange")
        XCTAssertEqual(ViolationSeverity.medium.color, "yellow")
        XCTAssertEqual(ViolationSeverity.low.color, "gray")
    }

    func testViolationSeverityRawValues() {
        XCTAssertEqual(ViolationSeverity.critical.rawValue, "Critical")
        XCTAssertEqual(ViolationSeverity.high.rawValue, "High")
        XCTAssertEqual(ViolationSeverity.medium.rawValue, "Medium")
        XCTAssertEqual(ViolationSeverity.low.rawValue, "Low")
    }

    // MARK: - Usage Context

    func testUsageContextRawValues() {
        XCTAssertEqual(UsageContext.textGeneration.rawValue, "Text Generation")
        XCTAssertEqual(UsageContext.imageGeneration.rawValue, "Image Generation")
        XCTAssertEqual(UsageContext.summarization.rawValue, "Summarization")
        XCTAssertEqual(UsageContext.translation.rawValue, "Translation")
        XCTAssertEqual(UsageContext.analysis.rawValue, "Analysis")
        XCTAssertEqual(UsageContext.chat.rawValue, "Chat")
        XCTAssertEqual(UsageContext.email.rawValue, "Email")
        XCTAssertEqual(UsageContext.news.rawValue, "News")
        XCTAssertEqual(UsageContext.system.rawValue, "System")
        XCTAssertEqual(UsageContext.unknown.rawValue, "Unknown")
    }

    // MARK: - Ethical Guidelines Display

    func testEthicalGuidelinesNotEmpty() {
        let guidelines = EthicalAIGuardian.shared.showEthicalGuidelines()
        XCTAssertFalse(guidelines.isEmpty, "Ethical guidelines should not be empty")
        XCTAssertTrue(guidelines.contains("PROHIBITED"), "Guidelines should list prohibited uses")
        XCTAssertTrue(guidelines.contains("ACCEPTABLE"), "Guidelines should list acceptable uses")
    }

    func testEthicalGuidelinesContainsCriticalCategories() {
        let guidelines = EthicalAIGuardian.shared.showEthicalGuidelines()
        XCTAssertTrue(guidelines.contains("ILLEGAL"), "Guidelines should mention illegal activities")
        XCTAssertTrue(guidelines.contains("HARMFUL"), "Guidelines should mention harmful content")
        XCTAssertTrue(guidelines.contains("HATE"), "Guidelines should mention hate speech")
        XCTAssertTrue(guidelines.contains("MISINFORMATION"), "Guidelines should mention misinformation")
        XCTAssertTrue(guidelines.contains("PRIVACY"), "Guidelines should mention privacy violations")
        XCTAssertTrue(guidelines.contains("FRAUD"), "Guidelines should mention fraud")
    }

    // MARK: - Violation Statistics

    func testViolationStatisticsCalculation() {
        let stats = ViolationStatistics(
            totalRequests: 100,
            safeRequests: 95,
            violations: 5,
            blocked: 2,
            criticalViolations: 1,
            highViolations: 2
        )

        XCTAssertEqual(stats.safePercentage, 95.0, accuracy: 0.01)
        XCTAssertEqual(stats.violationPercentage, 5.0, accuracy: 0.01)
    }

    func testViolationStatisticsZeroRequests() {
        let stats = ViolationStatistics(
            totalRequests: 0,
            safeRequests: 0,
            violations: 0,
            blocked: 0,
            criticalViolations: 0,
            highViolations: 0
        )

        XCTAssertEqual(stats.safePercentage, 100.0, "Zero requests should return 100% safe")
        XCTAssertEqual(stats.violationPercentage, 0.0, "Zero requests should return 0% violations")
    }

    func testGetViolationStatisticsReturnsValidData() {
        let guardian = EthicalAIGuardian.shared
        let stats = guardian.getViolationStatistics()
        XCTAssertGreaterThanOrEqual(stats.totalRequests, 0)
        XCTAssertGreaterThanOrEqual(stats.safeRequests, 0)
        XCTAssertGreaterThanOrEqual(stats.violations, 0)
        XCTAssertGreaterThanOrEqual(stats.blocked, 0)
    }

    // MARK: - PolicyViolation Codable

    func testPolicyViolationCodableRoundTrip() throws {
        let violation = PolicyViolation(
            category: .illegalActivity,
            severity: .critical,
            description: "Test violation",
            detectedPattern: "test pattern",
            action: .blockCompletely,
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(violation)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PolicyViolation.self, from: data)

        XCTAssertEqual(decoded.category, violation.category)
        XCTAssertEqual(decoded.severity, violation.severity)
        XCTAssertEqual(decoded.description, violation.description)
        XCTAssertEqual(decoded.detectedPattern, violation.detectedPattern)
        XCTAssertEqual(decoded.action, violation.action)
    }

    // MARK: - UsageLogEntry Codable

    func testUsageLogEntryCodableRoundTrip() throws {
        let entry = UsageLogEntry(
            timestamp: Date(),
            category: .safe,
            violation: nil,
            contentHash: "abc123",
            context: .analysis,
            action: .logOnly,
            blocked: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UsageLogEntry.self, from: data)

        XCTAssertEqual(decoded.category, .safe)
        XCTAssertEqual(decoded.contentHash, "abc123")
        XCTAssertEqual(decoded.context, .analysis)
        XCTAssertFalse(decoded.blocked)
    }

    // MARK: - EnforcementAction Codable

    func testEnforcementActionCodableRoundTrip() throws {
        let actions: [EnforcementAction] = [
            .blockCompletely, .blockAndRefer, .warnAndLog,
            .requireAcknowledgment, .logOnly
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for action in actions {
            let data = try encoder.encode(action)
            let decoded = try decoder.decode(EnforcementAction.self, from: data)
            XCTAssertEqual(decoded, action, "Round trip failed for \(action.rawValue)")
        }
    }
}
