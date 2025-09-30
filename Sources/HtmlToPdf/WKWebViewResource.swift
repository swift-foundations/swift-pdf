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
    /// Shared process pool for all WebViews
    @MainActor public static let sharedProcessPool = WKProcessPool()

    /// Whether to use persistent data store
    public let usePersistentDataStore: Bool

    public init(usePersistentDataStore: Bool = false) {
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
    public static func create(config: Config) async throws -> WKWebViewResource {
        let webViewConfig = WKWebViewConfiguration()

        // Share the same process pool to reduce process spawning
        webViewConfig.processPool = WKWebViewResourceConfig.sharedProcessPool

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

        #if os(iOS)
        webViewConfig.allowsInlineMediaPlayback = true
        #endif

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)

        // Disable background drawing on macOS
        #if os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
        #endif

        return WKWebViewResource(webView: webView)
    }

    /// Validate that the resource is still usable
    public func validate() async -> Bool {
        // For now, always return true - WebViews are generally stable
        // Could add more sophisticated validation later if needed
        return true
    }

    /// Reset the resource for reuse
    public func reset() async throws {
        // Stop any ongoing loads
        webView.stopLoading()

        // Clear navigation delegate
        webView.navigationDelegate = nil

        // Check if document is ready (without loading new content)
        _ = try? await webView.evaluateJavaScript("document.readyState")
    }
}

#endif