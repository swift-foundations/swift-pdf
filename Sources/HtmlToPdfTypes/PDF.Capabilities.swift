//
//  PDF.Capabilities.swift
//  swift-html-to-pdf
//
//  Platform concurrency limits
//

import Foundation

extension PDF {
    /// Platform-specific maximum concurrent operations
    ///
    /// These constants define safe concurrency limits for each platform based on:
    /// - Memory constraints (especially iOS)
    /// - WebView process limits
    /// - Thermal management (mobile devices)
    ///
    /// Used for:
    /// - Validating requested concurrency doesn't exceed platform max
    /// - Capping automatic concurrency calculation
    public enum PlatformConcurrencyLimit {
        /// macOS maximum: 16 concurrent WebViews
        ///
        /// Based on:
        /// - Desktop-class memory
        /// - Active cooling
        /// - Background process support
        public static let macOS = 16

        /// iOS maximum: 8 concurrent WebViews
        ///
        /// Based on:
        /// - Mobile memory constraints
        /// - Thermal management
        /// - App suspension policies
        public static let iOS = 8

        /// Linux maximum: 32 concurrent operations
        ///
        /// Future support via wkhtmltopdf or headless Chrome
        public static let linux = 32

        /// Mock/test limit: 1 for deterministic testing
        public static let mock = 1
    }
}
