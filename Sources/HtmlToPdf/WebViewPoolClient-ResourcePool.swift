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
/// Adds batch replacement capability to mitigate WebKit process-level memory leaks
@globalActor
private actor WebViewPoolActor {
    static let shared = WebViewPoolActor()

    private var sharedPool: ResourcePool<WKWebViewResource>?
    private var totalPDFsGenerated: Int = 0
    private let batchReplacementThreshold = 50_000
    private var poolProvider: (@Sendable () async throws -> ResourcePool<WKWebViewResource>)?
    private var isReplacing: Bool = false  // Prevent concurrent replacements

    func getOrCreatePool(
        provider: @escaping @Sendable () async throws -> ResourcePool<WKWebViewResource>
    ) async throws -> ResourcePool<WKWebViewResource> {
        // Store provider for pool replacement
        if poolProvider == nil {
            poolProvider = provider
        }

        if let existing = sharedPool {
            return existing
        }

        let newPool = try await provider()
        sharedPool = newPool
        return newPool
    }

    /// Record PDF generation and trigger batch replacement if threshold reached
    func recordPDFGenerated() async throws {
        totalPDFsGenerated += 1

        // Check if we've hit the batch replacement threshold
        // Use isReplacing flag to prevent race condition where multiple PDFs trigger replacement
        if totalPDFsGenerated >= batchReplacementThreshold,
           !isReplacing,
           let provider = poolProvider {

            isReplacing = true
            let oldCount = totalPDFsGenerated
            print("🔄 Batch replacement triggered at \(oldCount) PDFs - replacing entire pool")

            // Create new pool (warmup will happen in background)
            let newPool = try await provider()

            // Swap to new pool immediately
            // The old pool will be released when all current operations complete
            // Swift's ARC will handle cleanup automatically
            sharedPool = newPool
            totalPDFsGenerated = 0
            isReplacing = false

            print("✅ Batch replacement complete - fresh pool ready, old pool will cleanup automatically")
        }
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

    /// Record that a PDF was generated (triggers batch replacement if threshold reached)
    public func recordPDFGenerated() async throws {
        try await WebViewPoolActor.shared.recordPDFGenerated()
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
            let config = WKWebViewResourceConfig(
                usePersistentDataStore: usePersistentDataStore
            )

            // Create pool with warmup
            // Batch replacement (every 50K PDFs) handles memory leaks at pool level
            return try await ResourcePool<WKWebViewResource>(
                capacity: poolSize,
                resourceConfig: config,
                warmup: true,
                maxUsesBeforeCycling: nil  // No per-resource cycling - using batch replacement
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
