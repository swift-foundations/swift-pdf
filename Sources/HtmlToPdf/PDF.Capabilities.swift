//
//  PDF.Capabilities.swift
//  swift-html-to-pdf
//
//  Platform capabilities for PDF rendering
//

import Foundation

extension PDF {
    /// Platform-specific capabilities
    public struct Capabilities: Sendable {
        /// Whether this platform supports WebView pooling for performance
        public let supportsWebViewPooling: Bool

        /// Whether this platform supports background rendering
        public let supportsBackgroundRendering: Bool

        /// Whether this platform supports custom fonts
        public let supportsCustomFonts: Bool

        /// Maximum recommended concurrent operations for this platform
        public let maxConcurrentOperations: Int

        public init(
            supportsWebViewPooling: Bool,
            supportsBackgroundRendering: Bool,
            supportsCustomFonts: Bool,
            maxConcurrentOperations: Int
        ) {
            self.supportsWebViewPooling = supportsWebViewPooling
            self.supportsBackgroundRendering = supportsBackgroundRendering
            self.supportsCustomFonts = supportsCustomFonts
            self.maxConcurrentOperations = maxConcurrentOperations
        }
    }
}

// MARK: - Platform Presets

extension PDF.Capabilities {
    /// macOS capabilities
    public static let macOS = PDF.Capabilities(
        supportsWebViewPooling: true,
        supportsBackgroundRendering: true,
        supportsCustomFonts: true,
        maxConcurrentOperations: 16
    )

    /// iOS capabilities
    public static let iOS = PDF.Capabilities(
        supportsWebViewPooling: true,
        supportsBackgroundRendering: false,
        supportsCustomFonts: true,
        maxConcurrentOperations: 8
    )

    /// Linux capabilities (future)
    public static let linux = PDF.Capabilities(
        supportsWebViewPooling: false,
        supportsBackgroundRendering: true,
        supportsCustomFonts: true,
        maxConcurrentOperations: 32
    )

    /// Mock/test capabilities
    public static let mock = PDF.Capabilities(
        supportsWebViewPooling: false,
        supportsBackgroundRendering: false,
        supportsCustomFonts: false,
        maxConcurrentOperations: 1
    )
}
