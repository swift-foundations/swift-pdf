//
//  WebViewPoolConfiguration.swift
//  swift-html-to-pdf
//
//  Created on 2025-09-29.
//

import Foundation
import Dependencies
import EnvironmentVariables

/// Configuration for WebViewPool derived from environment variables
public struct WebViewPoolConfiguration: Sendable {
    /// Custom pool size override from environment
    public let poolSize: Int?

    /// Whether to silence logging output
    public let silent: Bool

    /// Whether running in CI environment
    public let isCI: Bool

    /// Whether running in GitHub Actions
    public let isGitHubActions: Bool

    /// Maximum number of pending requests (multiplier of pool size)
    public let maxQueueMultiplier: Int

    /// Creates configuration from environment variables
    public init(env: EnvironmentVariables) {
        self.poolSize = env.int("WEBVIEW_POOL_SIZE")
        self.silent = env.bool("WEBVIEW_POOL_SILENT") ?? false
        self.isCI = env.bool("CI") ?? false
        self.isGitHubActions = env.bool("GITHUB_ACTIONS") ?? false

        // In CI, use smaller queue multiplier to conserve memory
        self.maxQueueMultiplier = isCI ? 2 : 4
    }

    /// Default configuration for testing
    public static var test: Self {
        Self(env: .local)
    }

    /// CI-like configuration for testing
    public static var ci: Self {
        var env = EnvironmentVariables.local
        env["CI"] = "true"
        env["GITHUB_ACTIONS"] = "true"
        env["WEBVIEW_POOL_SIZE"] = "2"
        env["WEBVIEW_POOL_SILENT"] = "true"
        return Self(env: env)
    }
}

// MARK: - EnvironmentVariables Dependency

extension EnvironmentVariables: @retroactive DependencyKey {
    public static var liveValue: Self {
        // For WebViewPool, we only need process environment variables
        // No need for file-based configuration
        try! EnvironmentVariables.live(
            environmentConfiguration: .none,
            requiredKeys: []
        )
    }
}

