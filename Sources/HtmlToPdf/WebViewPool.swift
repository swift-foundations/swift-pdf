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

/// An actor for managing a pool of WKWebViews
actor WebViewPoolActor {
    // Track if we've prewarmed the processes
    @MainActor private static var isPrewarmed = false
    /// Error types that can be thrown by the WebViewPool
    enum Error: Swift.Error, LocalizedError {
        case timeout
        case poolExhausted
        case queueOverload
        case cancelled

        var errorDescription: String? {
            switch self {
            case .timeout: return "WebView acquisition timed out"
            case .poolExhausted: return "WebView pool is exhausted"
            case .queueOverload: return "Too many pending requests"
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
    private let maxSize: Int
    private var isInitialized = false
    private var initializationCallbacks: [CheckedContinuation<Void, Never>] = []

    // Statistics tracking
    private var totalAcquisitions: Int = 0
    private var totalTimeouts: Int = 0
    private var actualPoolSize: Int = 0
    
    init(size: Int) {
        self.maxSize = size
        // Create web views on the main actor since WKWebView requires it
        self.availableWebViews = []

        // Schedule creation of web views on the main actor
        Task { @MainActor in
            // Use shared process pool to avoid re-initialization
            let processPool = WebViewPoolClient.sharedProcessPool

            // Pre-warm the first WebView to initialize GPU and Network processes
            if size > 0 && !Self.isPrewarmed {
                Self.isPrewarmed = true
                let warmupConfig = WKWebViewConfiguration()
                warmupConfig.processPool = processPool
                warmupConfig.websiteDataStore = .nonPersistent()
                let warmupWebView = WKWebView(frame: .zero, configuration: warmupConfig)
                // Load a minimal page to trigger process initialization
                warmupWebView.loadHTMLString("<html></html>", baseURL: nil)
            }

            // Create web views
            var webViews: [WKWebView] = []
            for _ in 0..<size {
                let config = WKWebViewConfiguration()
                // Share the same process pool to reduce process spawning
                config.processPool = processPool
                // Disable GPU acceleration features we don't need for PDF
                config.suppressesIncrementalRendering = true
                config.preferences.setValue(false, forKey: "acceleratedDrawingEnabled")
                config.preferences.setValue(false, forKey: "displayListDrawingEnabled")

                // Use non-persistent data store to reduce disk I/O and logs
                config.websiteDataStore = .nonPersistent()

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
                // Disable logs from WebView
                webView.setValue(false, forKey: "drawsBackground")

                webViews.append(webView)
            }
            await self.completeInitialization(webViews)
        }
    }
    
    /// Complete initialization with the created web views
    private func completeInitialization(_ webViews: [WKWebView]) {
        availableWebViews = webViews
        actualPoolSize = webViews.count
        isInitialized = true

        // Resume all waiting initialization callbacks
        for callback in initializationCallbacks {
            callback.resume()
        }
        initializationCallbacks.removeAll()

        // Process any pending requests
        processPendingRequests()
    }

    /// Add a batch of web views to the pool
    func addWebViews(_ webViews: [WKWebView]) {
        availableWebViews.append(contentsOf: webViews)
        actualPoolSize += webViews.count
        processPendingRequests()
    }

    /// Process pending requests with available web views
    private func processPendingRequests() {
        while !pendingRequests.isEmpty,
              let webView = availableWebViews.popLast(),
              let (id, request) = pendingRequests.first {
            pendingRequests.removeValue(forKey: id)
            totalAcquisitions += 1
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
                // Wait a bit for cleanup
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }

        // Wait for initialization if needed
        if !isInitialized {
            await withCheckedContinuation { continuation in
                initializationCallbacks.append(continuation)
            }
        }

        // Remove queue overload check - the pool should handle any number of pending requests
        // The pool will naturally queue them and process as WebViews become available

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

                // Store the request
                pendingRequests[requestId] = request

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
            totalTimeouts += 1
            request.onError(Error.timeout)
        }
    }

    /// Cancel a pending request
    private func cancelRequest(id: UUID) {
        if let request = pendingRequests.removeValue(forKey: id) {
            request.onError(Error.cancelled)
        }
    }

    /// Return a web view to the pool
    func releaseWebView(_ webView: WKWebView) {
        // Immediately return to pool without cleanup to avoid race conditions
        // Cleanup will happen on next acquisition if needed
        addCleanedWebView(webView)
    }

    /// Add a cleaned web view back to the pool
    private func addCleanedWebView(_ webView: WKWebView) {
        // If someone is waiting for a web view, give it to them directly
        if let (id, request) = pendingRequests.first {
            pendingRequests.removeValue(forKey: id)
            totalAcquisitions += 1
            request.onSuccess(webView)
        } else {
            // Otherwise, put it back in the pool
            availableWebViews.append(webView)
        }
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

    /// Wait for pool initialization
    func waitForInitialization() async {
        if !isInitialized {
            await withCheckedContinuation { continuation in
                initializationCallbacks.append(continuation)
            }
        }
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
}

extension WebViewPoolClient: DependencyKey {
    // Shared process pool across all instances to avoid re-initialization
    @MainActor static let sharedProcessPool = WKProcessPool()
    /// Calculate optimal pool size based on system resources
    /// This algorithm balances performance with resource usage across different systems
    private static func calculateOptimalPoolSize() -> Int {
        let processInfo = ProcessInfo.processInfo

        // Get system resources
        let cpuCount = processInfo.activeProcessorCount
        let memoryBytes = processInfo.physicalMemory

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

    static var liveValue: WebViewPoolClient {
        // Allow environment variable override for testing and tuning
        let poolSize: Int
        if let envPoolSize = ProcessInfo.processInfo.environment["WEBVIEW_POOL_SIZE"],
           let customSize = Int(envPoolSize), customSize > 0 {
            poolSize = customSize
            #if DEBUG
            if ProcessInfo.processInfo.environment["WEBVIEW_POOL_SILENT"] == nil {
                print("[WebViewPool] Using custom pool size from environment: \(poolSize)")
            }
            #endif
        } else {
            poolSize = calculateOptimalPoolSize()
            #if DEBUG
            if ProcessInfo.processInfo.environment["WEBVIEW_POOL_SILENT"] == nil {
                print("[WebViewPool] Using calculated pool size: \(poolSize) (CPUs: \(ProcessInfo.processInfo.activeProcessorCount), Memory: \(ProcessInfo.processInfo.physicalMemory / (1024*1024*1024))GB)")
            }
            #endif
        }

        let actor = WebViewPoolActor(size: poolSize)

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
                        // Adaptive timeout based on attempt
                        let timeout = min(30, initialDelay * Double(attempt + 1) * 2)
                        return try await actor.acquireWebView(timeout: timeout)
                    } catch WebViewPoolActor.Error.timeout {
                        lastError = WebViewPoolActor.Error.timeout

                        if attempt < maxRetries - 1 {
                            // Exponential backoff with jitter
                            let jitter = Double.random(in: 0.5...1.5)
                            let backoffDelay = min(initialDelay * pow(2, Double(attempt)) * jitter, 10.0)
                            try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
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
            }
        )
    }
    
    /// Test value that uses dummy web views for testing
    static var testValue: WebViewPoolClient {
        return liveValue
//        return WebViewPoolClient(
//            acquireWebView: { @MainActor in
//                // Create a dummy web view for testing
//                return WKWebView(frame: .zero)
//            },
//            releaseWebView: { _ in
//                // Do nothing in tests
//            },
//            acquireWithRetry: { _, _ in
//                // Just return a new web view in tests
//                @MainActor func createWebView() -> WKWebView {
//                    return WKWebView(frame: .zero)
//                }
//                return await createWebView()
//            }
//        )
    }
}

extension DependencyValues {
    var webViewPool: WebViewPoolClient {
        get { self[WebViewPoolClient.self] }
        set { self[WebViewPoolClient.self] = newValue }
    }
}


#endif
