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
import LoggingExtras
import ResourcePool
import IssueReporting

/// Global shared pool actor to ensure only one pool exists across all consumers
@globalActor
private actor WebViewPoolActor {
    static let shared = WebViewPoolActor()

    private var sharedPool: ResourcePool<WKWebViewResource>?

    func getOrCreatePool(
        provider: @escaping @Sendable () async throws -> ResourcePool<WKWebViewResource>
    ) async throws -> ResourcePool<WKWebViewResource> {
        if let existing = sharedPool {
            return existing
        }

        let newPool = try await provider()
        sharedPool = newPool
        @Dependency(\.logger) var logger
        logger.info("WebView pool initialized")
        return newPool
    }
}

// MARK: - Active Operations Tracker

/// Tracks the number of currently active WebView operations for pool utilization metrics
actor ActiveOperationsTracker {
    private var activeCount: Int = 0
    static let shared = ActiveOperationsTracker()

    func increment() {
        activeCount += 1
        updateMetrics()
    }

    func decrement() {
        activeCount -= 1
        updateMetrics()
    }

    private func updateMetrics() {
        @Dependency(\.pdf.render.metrics) var metrics
        metrics.updatePoolUtilization(activeCount)
    }
}

/// Client for managing WebView pool using ResourcePool
package struct WebViewPoolClient: Sendable {
    /// Lazy-initialized resource pool provider
    private let poolProvider: @Sendable () async throws -> ResourcePool<WKWebViewResource>

    init(
        poolProvider: @escaping @Sendable () async throws -> ResourcePool<WKWebViewResource>
    ) {
        self.poolProvider = poolProvider
    }

    /// Get the pool, creating it if necessary (globally shared)
    private func getPool() async throws -> ResourcePool<WKWebViewResource> {
        return try await WebViewPoolActor.shared.getOrCreatePool(provider: poolProvider)
    }

    /// The underlying resource pool (for direct access)
    package var pool: ResourcePool<WKWebViewResource> {
        get async throws {
            try await getPool()
        }
    }
}

extension WebViewPoolClient: DependencyKey {
    public static var liveValue: WebViewPoolClient {
        return WebViewPoolClient(
            poolProvider: { @MainActor in
                // Pool size comes from configuration via dependencies
                @Dependency(\.pdf.render.configuration) var configuration
                let poolSize = configuration.concurrency.resolved

                // Create pool with warmup and proactive WebView replacement
                // Strategy: Periodic cache clearing + TTL-based recycling
                // - maxUsesBeforeRecreate: 2000 = WebView lifecycle limit (validated in validate())
                // - clearCachesEvery: 100 = Periodic cache flush prevents memory buildup (empirically faster than 0)
                // - maxUsesBeforeCycling: nil = Let validation handle cycling based on use count
                return try await ResourcePool<WKWebViewResource>(
                    capacity: poolSize,
                    resourceConfig: WKWebViewResource.Config(
                        maxUsesBeforeRecreate: 2000,
                        clearCachesEvery: 100  // Empirically optimal - better than disabled
                    ),
                    warmup: true,
                    maxUsesBeforeCycling: nil  // Validation handles this via use count
                )
            }
        )
    }

    public static var testValue: WebViewPoolClient {
        WebViewPoolClient(poolProvider: { @MainActor in
            return try await ResourcePool<WKWebViewResource>(
                capacity: 2,
                resourceConfig: WKWebViewResource.Config(),
                warmup: false
            )
        })
    }
}

extension DependencyValues {
    package var webViewPool: WebViewPoolClient {
        get { self[WebViewPoolClient.self] }
        set { self[WebViewPoolClient.self] = newValue }
    }
}

#endif
