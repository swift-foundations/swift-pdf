//
//  File.swift
//  swift-html-to-pdf
//
//  Created by Coen ten Thije Boonkkamp on 08/09/2024.
//

#if canImport(WebKit)
import Foundation
import WebKit
import Dependencies
import EnvironmentVariables

/// An actor for managing a pool of WKWebViews
actor WebViewPoolActor {
    // Pool for warmup WebViews (released after use)
    @MainActor private static var warmupWebView: WKWebView?
    /// Error types that can be thrown by the WebViewPool
    enum Error: Swift.Error, LocalizedError {
        case timeout
        case cancelled

        var errorDescription: String? {
            switch self {
            case .timeout: return "WebView acquisition timed out"
            case .cancelled: return "Request was cancelled"
            }
        }
    }

    /// Statistics for monitoring pool performance
    struct Statistics: Sendable {
        let available: Int
        let inUse: Int
        let pending: Int
        let totalAcquisitions: Int
        let totalTimeouts: Int
    }

    /// Wrapper for pending request callbacks
    private struct PendingRequest {
        let onSuccess: (WKWebView) -> Void
        let onError: (Swift.Error) -> Void
    }

    private var availableWebViews: [WKWebView]
    private var pendingRequests: [UUID: PendingRequest] = [:]
    private var pendingOrder: [UUID] = []  // FIFO queue for pending requests
    private let maxSize: Int
    private var isInitialized = false
    private var initializationCallbacks: [CheckedContinuation<Void, Never>] = []

    // Memory pressure monitoring
    #if os(macOS) || os(iOS)
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    #endif

    // Statistics tracking
    private var totalAcquisitions: Int = 0
    private var totalTimeouts: Int = 0
    private var actualPoolSize: Int = 0
    
    private let config: WebViewPoolConfiguration

    init(size: Int, config: WebViewPoolConfiguration) {
        self.maxSize = size
        self.config = config
        // Create web views on the main actor since WKWebView requires it
        self.availableWebViews = []

        // Set up memory pressure monitoring will be done after actor is created
        // since it requires actor isolation

        // Schedule creation of web views on the main actor
        Task { @MainActor in
            // Set up memory pressure monitoring now that actor is created
            #if os(macOS) || os(iOS)
            self.setupMemoryPressureMonitoring()
            #endif

            // Use shared process pool to avoid re-initialization
            let processPool = WebViewPoolClient.sharedProcessPool

            // Pre-warm if needed and release afterward
            if size > 0 && Self.warmupWebView == nil {
                let warmupConfig = WKWebViewConfiguration()
                warmupConfig.processPool = processPool
                warmupConfig.websiteDataStore = .nonPersistent()
                Self.warmupWebView = WKWebView(frame: .zero, configuration: warmupConfig)
                // Load a minimal page to trigger process initialization
                Self.warmupWebView?.loadHTMLString("<html></html>", baseURL: nil)

                // Schedule cleanup of warmup WebView after a delay
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    Self.warmupWebView = nil // Release warmup WebView
                }
            }

            // Create web views incrementally and notify as they become available
            for i in 0..<size {
                let config = WKWebViewConfiguration()
                // Share the same process pool to reduce process spawning
                config.processPool = processPool
                // Disable GPU acceleration features we don't need for PDF
                config.suppressesIncrementalRendering = true
                config.preferences.setValue(false, forKey: "acceleratedDrawingEnabled")
                config.preferences.setValue(false, forKey: "displayListDrawingEnabled")

                // Use data store based on configuration
                // Default is non-persistent for deterministic rendering
                config.websiteDataStore = self.config.usePersistentDataStore ? .default() : .nonPersistent()

                // Suppress various WebContent logs
                // Note: javaScriptEnabled is deprecated but still works for backward compatibility
                if #available(macOS 11.0, iOS 14.0, *) {
                    // Use the new API on newer systems
                    config.defaultWebpagePreferences.allowsContentJavaScript = false
                } else {
                    // Fallback for older systems
                    config.preferences.setValue(false, forKey: "javaScriptEnabled")
                }
                config.preferences.javaScriptCanOpenWindowsAutomatically = false
                config.preferences.minimumFontSize = 0

                // Disable features we don't need that might cause logs
                if #available(macOS 11.0, iOS 14.0, *) {
                    config.preferences.isFraudulentWebsiteWarningEnabled = false
                }

                #if os(iOS)
                config.allowsInlineMediaPlayback = true
                #endif

                let webView = WKWebView(frame: .zero, configuration: config)
                // Disable logs from WebView (macOS only - iOS doesn't support this KVC)
                #if os(macOS)
                webView.setValue(false, forKey: "drawsBackground")
                #endif

                // Add incrementally
                await self.addIncrementalWebView(webView, isLast: i == size - 1)
            }
        }
    }
    
    /// Add WebView incrementally during initialization
    private func addIncrementalWebView(_ webView: WKWebView, isLast: Bool) {
        availableWebViews.append(webView)
        actualPoolSize += 1

        // Mark as initialized when first WebView is ready
        if !isInitialized && actualPoolSize > 0 {
            isInitialized = true
            // Resume all waiting initialization callbacks
            for callback in initializationCallbacks {
                callback.resume()
            }
            initializationCallbacks.removeAll()
        }

        // Process any pending requests
        processPendingRequests()
    }

    #if os(macOS) || os(iOS)
    /// Set up memory pressure monitoring
    nonisolated private func setupMemoryPressureMonitoring() {
        Task {
            let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global())
            source.setEventHandler { [weak self] in
                guard let self = self else { return }
                Task {
                    await self.handleMemoryPressure()
                }
            }
            source.resume()
            await self.setMemoryPressureSource(source)
        }
    }

    private func setMemoryPressureSource(_ source: DispatchSourceMemoryPressure) {
        memoryPressureSource = source
    }

    /// Handle memory pressure events
    private func handleMemoryPressure() {
        // Don't shrink below minimum viable size
        let minPoolSize = 2
        guard availableWebViews.count > minPoolSize else { return }

        // Release 25% of available WebViews under memory pressure
        let toRelease = max(1, availableWebViews.count / 4)
        _ = availableWebViews.suffix(toRelease)

        availableWebViews.removeLast(toRelease)
        actualPoolSize -= toRelease

        print("[WebViewPool] Released \(toRelease) WebViews due to memory pressure. Pool size now: \(actualPoolSize)")
    }
    #endif

    /// Add a batch of web views to the pool
    func addWebViews(_ webViews: [WKWebView]) {
        availableWebViews.append(contentsOf: webViews)
        actualPoolSize += webViews.count
        processPendingRequests()
    }

    /// Process pending requests with available web views
    private func processPendingRequests() {
        while !pendingOrder.isEmpty, let webView = availableWebViews.popLast() {
            let id = pendingOrder.removeFirst()
            guard let request = pendingRequests.removeValue(forKey: id) else { continue }
            totalAcquisitions += 1
            // WebViews from the pool should already be clean, just deliver them
            request.onSuccess(webView)
        }
    }

    /// Request a web view from the pool with timeout support
    func acquireWebView(timeout: TimeInterval = 300) async throws -> WKWebView {
        // Clean WebView on acquisition if needed
        struct CleanWebView {
            @MainActor
            static func clean(_ webView: WKWebView) async {
                // Stop any ongoing loads
                webView.stopLoading()
                // Clear navigation delegate
                webView.navigationDelegate = nil
                // Simply check if document is ready without loading new content
                // Loading HTML here can cause hangs and process spawning issues
                _ = try? await webView.evaluateJavaScript("document.readyState")
            }
        }

        // Wait for initialization if needed
        if !isInitialized {
            await withCheckedContinuation { continuation in
                initializationCallbacks.append(continuation)
            }
        }

        // Instead of throwing on queue overload, just queue the request
        // The natural backpressure from the timeout mechanism will handle throttling

        // If we have available web views, clean and return one
        if let webView = availableWebViews.popLast() {
            totalAcquisitions += 1
            await CleanWebView.clean(webView)
            return webView
        }

        // Otherwise, wait for one to become available with timeout
        let requestId = UUID()

        return try await withTaskCancellationHandler {
            try await withUnsafeThrowingContinuation { continuation in
                var timeoutTask: Task<Void, Never>?

                // Create pending request with callbacks
                let request = PendingRequest(
                    onSuccess: { webView in
                        timeoutTask?.cancel() // Cancel immediately on success
                        continuation.resume(returning: webView)
                    },
                    onError: { error in
                        timeoutTask?.cancel() // Cancel immediately on error
                        continuation.resume(throwing: error)
                    }
                )

                // Store the request with FIFO ordering
                pendingRequests[requestId] = request
                pendingOrder.append(requestId)

                // Set up timeout
                timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    self.timeoutRequest(id: requestId)
                }
            }
        } onCancel: {
            Task {
                await self.cancelRequest(id: requestId)
            }
        }
    }

    /// Timeout a pending request
    private func timeoutRequest(id: UUID) {
        if let request = pendingRequests.removeValue(forKey: id) {
            pendingOrder.removeAll { $0 == id }  // Remove from order queue
            totalTimeouts += 1
            request.onError(Error.timeout)
        }
    }

    /// Cancel a pending request
    private func cancelRequest(id: UUID) {
        if let request = pendingRequests.removeValue(forKey: id) {
            pendingOrder.removeAll { $0 == id }  // Remove from order queue
            request.onError(Error.cancelled)
        }
    }

    /// Return a web view to the pool
    func releaseWebView(_ webView: WKWebView) {
        // Clean the WebView on the MainActor before returning to pool
        Task { @MainActor in
            // Clean WebView before returning to pool
            webView.stopLoading()
            webView.navigationDelegate = nil
            // Simply ensure WebView is ready before returning to pool
            // Don't load new HTML as it can cause process hangs
            _ = try? await webView.evaluateJavaScript("document.readyState")
            // Now add it back to the pool
            await self.addCleanedWebView(webView)
        }
    }

    /// Add a cleaned web view back to the pool
    private func addCleanedWebView(_ webView: WKWebView) {
        // Always put it back in the pool - this ensures proper accounting
        availableWebViews.append(webView)

        // Then process any pending requests
        processPendingRequests()
    }

    /// Get current pool statistics
    func getStatistics() -> Statistics {
        // Wait for initialization if needed
        if !isInitialized {
            return Statistics(
                available: 0,
                inUse: 0,
                pending: pendingRequests.count,
                totalAcquisitions: totalAcquisitions,
                totalTimeouts: totalTimeouts
            )
        }

        return Statistics(
            available: availableWebViews.count,
            inUse: max(0, actualPoolSize - availableWebViews.count),
            pending: pendingRequests.count,
            totalAcquisitions: totalAcquisitions,
            totalTimeouts: totalTimeouts
        )
    }

    /// Wait for pool initialization (at least one WebView ready)
    func waitForInitialization() async {
        if !isInitialized {
            await withCheckedContinuation { continuation in
                initializationCallbacks.append(continuation)
            }
        }
    }

    /// Wait for pool to be fully initialized (all WebViews created)
    func waitForFullInitialization() async {
        // First wait for basic initialization
        await waitForInitialization()

        // Then wait until we have the expected pool size
        while actualPoolSize < maxSize {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }

    deinit {
        #if os(macOS) || os(iOS)
        memoryPressureSource?.cancel()
        #endif
    }
}

/// Client for the WebViewPool using the dependencies library
struct WebViewPoolClient {
    /// Acquire a web view from the pool
    var acquireWebView: @Sendable () async throws -> WKWebView

    /// Release a web view back to the pool
    var releaseWebView: @Sendable (WKWebView) async -> Void

    /// Attempt to acquire a web view with retries
    var acquireWithRetry: @Sendable (Int, TimeInterval) async throws -> WKWebView

    /// Get pool statistics
    var getStatistics: @Sendable () async -> WebViewPoolActor.Statistics

    /// Wait for pool initialization
    var waitForInitialization: @Sendable () async -> Void

    /// Wait for pool to be fully initialized
    var waitForFullInitialization: @Sendable () async -> Void
}

extension WebViewPoolClient: DependencyKey {
    // Shared process pool across all instances to avoid re-initialization
    @MainActor static let sharedProcessPool = WKProcessPool()
    /// Calculate optimal pool size based on system resources
    /// This algorithm balances performance with resource usage across different systems
    static func calculatePoolSize(cpuCount: Int, memoryBytes: UInt64, isCI: Bool = false) -> Int {
        // CI environments need more conservative resource usage
        if isCI {
            // GitHub Actions runners have limited resources
            // Use minimal pool size to ensure stability
            return min(2, cpuCount)
        }

        // Memory-based calculation:
        // Each WebContent process uses ~150-250MB of memory in practice
        // We allocate up to 10% of system memory for WebView pool
        // Using 200MB as average per WebView for calculation
        let memoryForWebViews = Double(memoryBytes) * 0.10
        let memoryBasedLimit = Int(memoryForWebViews / (200 * 1024 * 1024))

        // CPU-based calculation:
        // For I/O-bound PDF generation, we can have more WebViews than CPU cores
        // But we limit to cores/2 to leave headroom for the app and system
        let cpuBasedLimit = max(2, min(cpuCount, 8))

        // Platform-specific adjustments
        #if os(iOS) || os(tvOS) || os(watchOS)
        // Mobile devices: be more conservative with resources
        let platformMax = 3
        #else
        // macOS: can handle more concurrent WebViews
        let platformMax = 8
        #endif

        // Final calculation: take minimum of all limits
        let calculatedSize = min(memoryBasedLimit, cpuBasedLimit, platformMax)

        // Ensure at least 2 for minimal concurrency, but not more than available cores
        return max(2, min(calculatedSize, cpuCount))
    }

    static func createPool(env: EnvironmentVariables) -> WebViewPoolClient {
        let config = WebViewPoolConfiguration(env: env)

        // Determine pool size from configuration or calculation
        let poolSize: Int
        if let customSize = config.poolSize, customSize > 0 {
            poolSize = customSize
            #if DEBUG
            if !config.silent {
                print("[WebViewPool] Using custom pool size from environment: \(poolSize)")
            }
            #endif
        } else {
            let processInfo = ProcessInfo.processInfo
            poolSize = calculatePoolSize(
                cpuCount: processInfo.activeProcessorCount,
                memoryBytes: processInfo.physicalMemory,
                isCI: config.isCI
            )
            #if DEBUG
            if !config.silent {
                let ciInfo = config.isCI ? " [CI MODE]" : ""
                print("[WebViewPool] Using calculated pool size: \(poolSize)\(ciInfo) (CPUs: \(ProcessInfo.processInfo.activeProcessorCount), Memory: \(ProcessInfo.processInfo.physicalMemory / (1024*1024*1024))GB)")
            }
            #endif
        }

        let actor = WebViewPoolActor(size: poolSize, config: config)

        return WebViewPoolClient(
            acquireWebView: {
                try await actor.acquireWebView(timeout: 300)
            },
            releaseWebView: { webView in
                await actor.releaseWebView(webView)
            },
            acquireWithRetry: { maxRetries, initialDelay in
                var lastError: Swift.Error?

                for attempt in 0..<maxRetries {
                    do {
                        // Calculate remaining budget to stay within overall timeout
                        let remainingTime = initialDelay * 8 - (initialDelay * Double(attempt))
                        // Use adaptive timeout, but cap to remaining budget
                        let timeout = min(30, min(remainingTime, initialDelay * Double(attempt + 1) * 2))
                        return try await actor.acquireWebView(timeout: timeout)
                    } catch WebViewPoolActor.Error.timeout {
                        lastError = WebViewPoolActor.Error.timeout

                        if attempt < maxRetries - 1 {
                            // Exponential backoff with jitter, capped to not exceed budget
                            let jitter = Double.random(in: 0.5...1.5)
                            let backoffDelay = min(initialDelay * pow(2, Double(attempt)) * jitter, 10.0)
                            let remainingBudget = initialDelay * 8 - (initialDelay * Double(attempt + 1))
                            let actualDelay = min(backoffDelay, remainingBudget / 2)  // Use at most half of remaining budget for backoff
                            if actualDelay > 0 {
                                try await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
                            }
                        }
                    } catch {
                        // For other errors, throw immediately
                        throw error
                    }
                }

                throw lastError ?? WebViewPoolActor.Error.timeout
            },
            getStatistics: {
                await actor.getStatistics()
            },
            waitForInitialization: {
                await actor.waitForInitialization()
            },
            waitForFullInitialization: {
                await actor.waitForFullInitialization()
            }
        )
    }

    static var liveValue: WebViewPoolClient {
        @Dependency(\.envVars) var env
        return createPool(env: env)
    }

    /// Test value that uses the real pool for integration testing
    static var testValue: WebViewPoolClient {
        // For tests, use the real pool so integration tests work properly
        // Tests can override env vars to configure the pool
        @Dependency(\.envVars) var env
        return createPool(env: env)
    }
}

extension DependencyValues {
    var webViewPool: WebViewPoolClient {
        get { self[WebViewPoolClient.self] }
        set { self[WebViewPoolClient.self] = newValue }
    }
}


#endif
