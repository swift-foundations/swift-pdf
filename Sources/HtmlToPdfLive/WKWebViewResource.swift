//
//  WKWebViewResource.swift
//  swift-html-to-pdf
//
//  Adapter for WKWebView to work with ResourcePool
//

#if canImport(WebKit)
import Foundation
import WebKit
import ResourcePool
import Dependencies
import LoggingExtras

/// WKWebView wrapper that conforms to PoolableResource
@MainActor
package final class WKWebViewResource: PoolableResource {
    package struct Config: Sendable {
        package var maxUsesBeforeRecreate: Int
        package var clearCachesEvery: Int  // 0 = disabled

        package init(
            maxUsesBeforeRecreate: Int = 2000,
            clearCachesEvery: Int = 0  // Disabled by default - rely on TTL recycling
        ) {
            self.maxUsesBeforeRecreate = maxUsesBeforeRecreate
            self.clearCachesEvery = clearCachesEvery
        }
    }

    /// The underlying WKWebView
    package let webView: WKWebView
    private let config: Config
    private var uses: Int = 0

    private init(webView: WKWebView, config: Config) {
        self.webView = webView
        self.config = config
    }

    /// Create a new WKWebView resource
    @MainActor
    package static func create(config: Config) async throws -> WKWebViewResource {
        let webViewConfig = WKWebViewConfiguration()

        // Note: WKProcessPool is deprecated as of macOS 12.0+
        // "Creating and using multiple instances of WKProcessPool no longer has any effect."
        // WebKit now manages process pools internally, so we cannot force separate pools
        // per ResourcePool generation. Must rely on other cleanup mechanisms.

        // Use non-persistent data store (correct for stateless PDF generation)
        webViewConfig.websiteDataStore = .nonPersistent()

        // Disable GPU acceleration features we don't need for PDF
        webViewConfig.suppressesIncrementalRendering = true

        // Enable JavaScript for WebKit internal heuristics (recommended by experts)
        // Keep HTML isolated with baseURL and no network requests
        if #available(macOS 11.0, iOS 14.0, *) {
            webViewConfig.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            webViewConfig.preferences.setValue(true, forKey: "javaScriptEnabled")
        }
        webViewConfig.preferences.javaScriptCanOpenWindowsAutomatically = false
        webViewConfig.preferences.minimumFontSize = 0

        // Disable fraud warning
        if #available(macOS 11.0, iOS 14.0, *) {
            webViewConfig.preferences.isFraudulentWebsiteWarningEnabled = false
        }

        // Suppress WebKit logging warnings (IMPORTANT: false prevents log spam)
        webViewConfig.preferences.setValue(false, forKey: "logsPageMessagesToSystemConsoleEnabled")
        webViewConfig.preferences.setValue(false, forKey: "developerExtrasEnabled")

        #if os(iOS)
        webViewConfig.allowsInlineMediaPlayback = true
        webViewConfig.suppressesIncrementalRendering = true
        #endif

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)

        // Disable background drawing on macOS
        #if os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
        #endif

        // Disable scrolling and gestures (not needed for PDF rendering)
        #if os(iOS)
        webView.scrollView.isScrollEnabled = false
        #endif
        #if os(macOS)
        webView.allowsBackForwardNavigationGestures = false
        #endif

        return WKWebViewResource(webView: webView, config: config)
    }

    /// Validate that the resource is still usable
    @MainActor
    package func validate() async -> Bool {
        // Check if we've exceeded max uses - proactive recycling
        if uses >= config.maxUsesBeforeRecreate {
            return false
        }

        // Check if WebView is still responsive (simple check, no timeout needed)
        // Timeout wrapper causes Swift 6 concurrency issues, and WebKit is reliable
        do {
            _ = try await webView.evaluateJavaScript("1 + 1")
            return true
        } catch {
            // WebView is unresponsive or in error state
            @Dependency(\.logger) var logger
            logger.warning("WebView validation failed, will be replaced", metadata: [
                "error": "\(error)",
                "error_type": "\(type(of: error))",
                "uses": "\(uses)"
            ])
            return false
        }
    }

    /// Reset the resource for reuse
    @MainActor
    package func reset() async throws {
        uses += 1

        // Stop any ongoing loads
        webView.stopLoading()

        // Clear navigation delegate
        webView.navigationDelegate = nil

        // Periodic cache clearing: Clear caches every N uses to prevent buildup
        // This is cheaper than clearing on every use (15% overhead) but prevents accumulation
        if config.clearCachesEvery > 0, uses % config.clearCachesEvery == 0 {
            let dataTypes: Set<String> = [
                WKWebsiteDataTypeDiskCache,
                WKWebsiteDataTypeMemoryCache
            ]
            await webView.configuration.websiteDataStore.removeData(
                ofTypes: dataTypes,
                modifiedSince: .distantPast
            )
        }

        // Note: We avoid loading blank HTML (10x degradation) and full data store clears on every use.
        // Instead, periodic cache clearing + use-count validation provides good balance.
    }
}

#endif
