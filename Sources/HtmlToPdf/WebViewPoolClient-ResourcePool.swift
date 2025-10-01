//
//  WebViewPoolClient-ResourcePool.swift
//  swift-html-to-pdf
//
//  WebViewPoolClient implementation using ResourcePool
//

#if canImport(WebKit)
import Foundation
import WebKit
import Dependencies
import ResourcePool
import EnvironmentVariables
import IssueReporting

/// Global shared pool actor to ensure only one pool exists across all consumers
@globalActor
private actor WebViewPoolActor {
    static let shared = WebViewPoolActor()

    private var sharedPool: ResourcePool<WKWebViewResource>?

    func getOrCreatePool(
        provider: @Sendable () async throws -> ResourcePool<WKWebViewResource>
    ) async throws -> ResourcePool<WKWebViewResource> {
        if let existing = sharedPool {
            return existing
        }

        let newPool = try await provider()
        sharedPool = newPool
        return newPool
    }
}

/// Client for managing WebView pool using ResourcePool
public struct WebViewPoolClient: Sendable {
    /// Lazy-initialized resource pool provider
    private let poolProvider: @Sendable () async throws -> ResourcePool<WKWebViewResource>

    init(poolProvider: @escaping @Sendable () async throws -> ResourcePool<WKWebViewResource>) {
        self.poolProvider = poolProvider
    }

    /// Get the pool, creating it if necessary (globally shared)
    private func getPool() async throws -> ResourcePool<WKWebViewResource> {
        try await WebViewPoolActor.shared.getOrCreatePool(provider: poolProvider)
    }

    /// The underlying resource pool (for direct access)
    public var pool: ResourcePool<WKWebViewResource> {
        get async throws {
            try await getPool()
        }
    }
}

extension WebViewPoolClient: DependencyKey {
    public static var liveValue: WebViewPoolClient {
        WebViewPoolClient { @MainActor in
            @Dependency(\.envVars) var env

            // Determine pool size
            let poolSize: Int
            if let envPoolSize = env["WEBVIEW_POOL_SIZE"],
               let customSize = Int(envPoolSize), customSize > 0 {
                poolSize = customSize
            } else {
                // Simple calculation based on CPU count
                let cpuCount = ProcessInfo.processInfo.activeProcessorCount
                poolSize = max(2, min(cpuCount, 8))
            }

            // Create configuration
            let usePersistentDataStore = env["WEBVIEW_PERSISTENT_DATA_STORE"]?.lowercased() == "true"
            let config = WKWebViewResourceConfig(usePersistentDataStore: usePersistentDataStore)

            // Create pool with warmup
            return try await ResourcePool<WKWebViewResource>(
                capacity: poolSize,
                resourceConfig: config,
                warmup: true
            )
        }
    }

    public static var testValue: WebViewPoolClient {
        WebViewPoolClient { @MainActor in
            let config = WKWebViewResourceConfig(usePersistentDataStore: false)
            return try await ResourcePool<WKWebViewResource>(
                capacity: 2,
                resourceConfig: config,
                warmup: false
            )
        }
    }
}

extension DependencyValues {
    public var webViewPool: WebViewPoolClient {
        get { self[WebViewPoolClient.self] }
        set { self[WebViewPoolClient.self] = newValue }
    }
}

#endif
