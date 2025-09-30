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

/// Client for managing WebView pool using ResourcePool
public struct WebViewPoolClient: Sendable {
    /// Lazy-initialized resource pool
    private let poolProvider: @Sendable () async throws -> ResourcePool<WKWebViewResource>

    /// Cache for the pool once created
    private let poolCache: LockIsolated<ResourcePool<WKWebViewResource>?>

    init(poolProvider: @escaping @Sendable () async throws -> ResourcePool<WKWebViewResource>) {
        self.poolProvider = poolProvider
        self.poolCache = LockIsolated(nil)
    }

    /// Get the pool, creating it if necessary
    private func getPool() async throws -> ResourcePool<WKWebViewResource> {
        if let cached = poolCache.value {
            return cached
        }

        let pool = try await poolProvider()
        poolCache.setValue(pool)
        return pool
    }

    /// The underlying resource pool (for direct access)
    public var pool: ResourcePool<WKWebViewResource> {
        get async throws {
            try await getPool()
        }
    }

    /// Acquire a web view with retry logic
    public var acquireWithRetry: @Sendable (Int, TimeInterval) async throws -> WKWebView {
        { maxRetries, timeout in
            var lastError: Error?

            for attempt in 0..<maxRetries {
                do {
                    let pool = try await self.getPool()
                    // Use withResource to get the WebView temporarily
                    // Note: This is a simplified approach - the WebView is returned immediately
                    // In the actual usage, we'll need to refactor to use withResource pattern properly
                    return try await pool.withResource(timeout: .seconds(timeout)) { resource in
                        resource.webView
                    }
                } catch {
                    lastError = error
                    if attempt < maxRetries - 1 {
                        // Simple exponential backoff
                        let backoffDelay = min(pow(2, Double(attempt)), 10.0)
                        try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                    }
                }
            }

            throw lastError ?? PoolError.timeout
        }
    }

    /// Release a web view back to the pool
    /// Note: With ResourcePool, this becomes a no-op as resources are managed via withResource
    public func releaseWebView(_ webView: WKWebView) async {
        // No-op: ResourcePool manages lifecycle through withResource pattern
        // This method exists for API compatibility during migration
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
