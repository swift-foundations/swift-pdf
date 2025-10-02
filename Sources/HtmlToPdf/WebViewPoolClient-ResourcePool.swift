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

/// Adaptive throughput optimizer that monitors performance and triggers optimizations
private actor AdaptiveThroughputOptimizer {
    struct MetricsWindow: Sendable {
        let timestamp: Date
        let pdfsCompleted: Int
        let throughput: Double // PDFs/sec
    }

    enum OptimizationAction {
        case triggerPoolReplacement
        case none
    }

    private var windows: [MetricsWindow] = []
    private let windowDuration: TimeInterval = 5.0
    private let maxWindows = 10 // Keep last 50 seconds of history
    private var windowStartTime: Date = Date()
    private var windowPDFCount: Int = 0
    private var absolutePeakThroughput: Double = 0.0 // Track peak across entire run

    /// Record a completed PDF and update metrics
    func recordPDF() -> OptimizationAction? {
        windowPDFCount += 1

        let now = Date()
        let elapsed = now.timeIntervalSince(windowStartTime)

        // Complete window if duration exceeded
        if elapsed >= windowDuration {
            let throughput = Double(windowPDFCount) / elapsed
            let window = MetricsWindow(
                timestamp: now,
                pdfsCompleted: windowPDFCount,
                throughput: throughput
            )

            windows.append(window)

            // Update absolute peak
            if throughput > absolutePeakThroughput {
                absolutePeakThroughput = throughput
            }

            // Keep only recent windows
            if windows.count > maxWindows {
                windows.removeFirst()
            }

            // Reset window
            windowStartTime = now
            windowPDFCount = 0

            // Check if optimization needed
            return shouldOptimize()
        }

        return nil
    }

    /// Detect if throughput is degrading and optimization is needed
    private func shouldOptimize() -> OptimizationAction? {
        // Need at least 5 windows to establish reliable baseline (25 seconds of data)
        guard windows.count >= 5 else { return nil }

        // Get recent average (last 3 windows = 15 seconds)
        let recentWindows = Array(windows.suffix(3))
        let recentAverage = recentWindows.map(\.throughput).reduce(0, +) / Double(recentWindows.count)

        // Get peak from the last 5 windows (local peak within recent history)
        let localPeak = windows.suffix(5).map(\.throughput).max()!

        // Trigger if recent average drops >5% from local peak
        // This balances early detection with avoiding false positives
        // 5% degradation is significant enough to warrant pool replacement
        if localPeak > 1500 && recentAverage < localPeak * 0.95 {
            print("📊 Adaptive replacement: \(String(format: "%.0f", recentAverage)) PDFs/sec (recent avg) vs \(String(format: "%.0f", localPeak)) PDFs/sec (local peak) - \(String(format: "%.1f", (1.0 - recentAverage/localPeak) * 100))% degradation")
            return .triggerPoolReplacement
        }

        return nil
    }

    /// Reset peak after pool replacement to allow new baseline
    func resetPeak() {
        absolutePeakThroughput = 0.0
        windows.removeAll()
        windowStartTime = Date()
        windowPDFCount = 0
    }

    /// Get current throughput statistics
    func getStats() -> (current: Double?, peak: Double?, windows: Int) {
        let currentThroughput = windows.last?.throughput
        let peakThroughput = windows.map(\.throughput).max()
        return (currentThroughput, peakThroughput, windows.count)
    }
}

/// Global shared pool actor to ensure only one pool exists across all consumers
/// Adds batch replacement capability to mitigate WebKit process-level memory leaks
/// Now includes adaptive throughput optimization
@globalActor
private actor WebViewPoolActor {
    static let shared = WebViewPoolActor()

    private var sharedPool: ResourcePool<WKWebViewResource>?
    private var totalPDFsGenerated: Int = 0
    private var batchReplacementThreshold = 30_000 // Reduced from 50K for better sustained performance
    private var poolProvider: (@Sendable () async throws -> ResourcePool<WKWebViewResource>)?
    private var isReplacing: Bool = false  // Prevent concurrent replacements
    private var adaptiveOptimizer: AdaptiveThroughputOptimizer?
    private var adaptiveOptimizationEnabled: Bool = false

    func getOrCreatePool(
        provider: @escaping @Sendable () async throws -> ResourcePool<WKWebViewResource>,
        adaptiveOptimization: Bool = false
    ) async throws -> ResourcePool<WKWebViewResource> {
        // Store provider for pool replacement
        if poolProvider == nil {
            poolProvider = provider
        }

        // Enable adaptive optimization if requested
        if adaptiveOptimization && adaptiveOptimizer == nil {
            adaptiveOptimizer = AdaptiveThroughputOptimizer()
            adaptiveOptimizationEnabled = true
            print("🎯 Adaptive throughput optimization ENABLED")
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

        // Adaptive optimization: monitor throughput and trigger early optimization
        if adaptiveOptimizationEnabled, let optimizer = adaptiveOptimizer {
            if let action = await optimizer.recordPDF() {
                switch action {
                case .triggerPoolReplacement:
                    // Adaptive optimizer detected degradation - trigger early replacement
                    if !isReplacing, let provider = poolProvider {
                        try await triggerPoolReplacement(provider: provider, reason: "adaptive optimization")
                    }
                case .none:
                    break
                }
            }
        }

        // Check if we've hit the batch replacement threshold (fallback/safety mechanism)
        // Use isReplacing flag to prevent race condition where multiple PDFs trigger replacement
        if totalPDFsGenerated >= batchReplacementThreshold,
           !isReplacing,
           let provider = poolProvider {
            try await triggerPoolReplacement(provider: provider, reason: "threshold reached")
        }
    }

    /// Trigger pool replacement
    private func triggerPoolReplacement(
        provider: @Sendable () async throws -> ResourcePool<WKWebViewResource>,
        reason: String
    ) async throws {
        isReplacing = true
        let oldCount = totalPDFsGenerated
        print("🔄 Batch replacement triggered at \(oldCount) PDFs (\(reason)) - replacing entire pool")

        // Create new pool (warmup will happen in background)
        let newPool = try await provider()

        // Swap to new pool immediately
        // The old pool will be released when all current operations complete
        // Swift's ARC will handle cleanup automatically
        sharedPool = newPool
        totalPDFsGenerated = 0

        // Reset adaptive optimizer to establish new baseline
        if let optimizer = adaptiveOptimizer {
            await optimizer.resetPeak()
        }

        isReplacing = false

        print("✅ Batch replacement complete - fresh pool ready, old pool will cleanup automatically")
    }
}

/// Client for managing WebView pool using ResourcePool
public struct WebViewPoolClient: Sendable {
    /// Lazy-initialized resource pool provider
    private let poolProvider: @Sendable () async throws -> ResourcePool<WKWebViewResource>

    init(
        poolProvider: @escaping @Sendable () async throws -> ResourcePool<WKWebViewResource>
    ) {
        self.poolProvider = poolProvider
    }

    /// Get the pool, creating it if necessary (globally shared)
    private func getPool() async throws -> ResourcePool<WKWebViewResource> {
        // Read configuration dynamically at pool creation time (not client creation time)
        // This ensures withDependencies overrides are properly captured
        @Dependency(\.pdf.render.configuration) var configuration

        return try await WebViewPoolActor.shared.getOrCreatePool(
            provider: poolProvider,
            adaptiveOptimization: configuration.adaptiveThroughputOptimization
        )
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
        return WebViewPoolClient(
            poolProvider: { @MainActor in
                @Dependency(\.envVars) var env

                // Determine pool size
                let poolSize: Int
                if let envPoolSize = env["WEBVIEW_POOL_SIZE"],
                   let customSize = Int(envPoolSize), customSize > 0 {
                    poolSize = customSize
                } else {
                    // Use intelligent defaults based on hardware
                    poolSize = PDF.ConcurrencyStrategy.calculateDefaultConcurrency()
                }

                // Create configuration
                let usePersistentDataStore = env["WEBVIEW_PERSISTENT_DATA_STORE"]?.lowercased() == "true"
                let config = WKWebViewResourceConfig(
                    usePersistentDataStore: usePersistentDataStore
                )

                // Create pool with warmup
                // Batch replacement (every 30K PDFs) handles memory leaks at pool level
                return try await ResourcePool<WKWebViewResource>(
                    capacity: poolSize,
                    resourceConfig: config,
                    warmup: true,
                    maxUsesBeforeCycling: nil  // No per-resource cycling - using batch replacement
                )
            }
        )
    }

    public static var testValue: WebViewPoolClient {
        WebViewPoolClient(poolProvider: { @MainActor in
            let config = WKWebViewResourceConfig(usePersistentDataStore: false)
            return try await ResourcePool<WKWebViewResource>(
                capacity: 2,
                resourceConfig: config,
                warmup: false
            )
        })
    }
}

extension DependencyValues {
    public var webViewPool: WebViewPoolClient {
        get { self[WebViewPoolClient.self] }
        set { self[WebViewPoolClient.self] = newValue }
    }
}

#endif
