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

/// Configuration for creating WKWebView resources
public struct WKWebViewResourceConfig: Sendable {
    /// Whether to use persistent data store
    public let usePersistentDataStore: Bool

    public init(
        usePersistentDataStore: Bool = false
    ) {
        self.usePersistentDataStore = usePersistentDataStore
    }
}

/// WKWebView wrapper that conforms to PoolableResource
@MainActor
public final class WKWebViewResource: PoolableResource {
    public typealias Config = WKWebViewResourceConfig

    /// The underlying WKWebView
    public let webView: WKWebView

    private init(webView: WKWebView) {
        self.webView = webView
    }

    /// Create a new WKWebView resource
    @MainActor
    public static func create(config: Config) async throws -> WKWebViewResource {
        let webViewConfig = WKWebViewConfiguration()

        // Note: processPool defaults to a shared instance, no need to set it explicitly
        // (avoiding deprecated WKProcessPool APIs)

        // Disable GPU acceleration features we don't need for PDF
        webViewConfig.suppressesIncrementalRendering = true
        webViewConfig.preferences.setValue(false, forKey: "acceleratedDrawingEnabled")
        webViewConfig.preferences.setValue(false, forKey: "displayListDrawingEnabled")

        // Use data store based on configuration
        webViewConfig.websiteDataStore = config.usePersistentDataStore ? .default() : .nonPersistent()

        // Disable JavaScript for PDF rendering
        if #available(macOS 11.0, iOS 14.0, *) {
            webViewConfig.defaultWebpagePreferences.allowsContentJavaScript = false
        } else {
            webViewConfig.preferences.setValue(false, forKey: "javaScriptEnabled")
        }
        webViewConfig.preferences.javaScriptCanOpenWindowsAutomatically = false
        webViewConfig.preferences.minimumFontSize = 0

        // Disable fraud warning
        if #available(macOS 11.0, iOS 14.0, *) {
            webViewConfig.preferences.isFraudulentWebsiteWarningEnabled = false
        }

        // Suppress WebKit logging warnings
        webViewConfig.preferences.setValue(true, forKey: "logsPageMessagesToSystemConsoleEnabled")
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

        return WKWebViewResource(webView: webView)
    }

    /// Validate that the resource is still usable
    @MainActor
    public func validate() async -> Bool {
        // Check if WebView is still responsive
        do {
            // Try a simple JavaScript evaluation to check responsiveness
            _ = try await webView.evaluateJavaScript("1 + 1")
            return true
        } catch {
            // WebView is unresponsive or in error state
            return false
        }
    }

    /// Reset the resource for reuse
    @MainActor
    public func reset() async throws {
        // Stop any ongoing loads
        webView.stopLoading()

        // Clear navigation delegate
        webView.navigationDelegate = nil

        // Lightweight cleanup - just verify document is ready
        // Note: Expensive operations like loading blank HTML and clearing data stores
        // caused 10x performance degradation. Instead, rely on resource cycling
        // (maxUsesBeforeCycling in ResourcePool) to periodically replace WebViews.
        _ = try? await webView.evaluateJavaScript("document.readyState")
    }
}

#endif