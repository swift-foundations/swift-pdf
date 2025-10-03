//
//  PDF.Render.ConcurrencyLimit.swift
//  swift-html-to-pdf
//
//  Platform-specific concurrency limits for PDF rendering
//

import Foundation

extension PDF.Render {
    /// Platform concurrency limits - DOCUMENTATION ONLY (not enforced)
    ///
    /// These represent empirically tested values, not hard limits enforced by the system.
    /// The actual limits are determined by:
    /// - ResourcePool capacity (set via `configuration.concurrency`)
    /// - OS resource availability
    /// - Hardware capabilities
    ///
    /// ## No Enforcement
    ///
    /// These values are **reference only**. The system does NOT:
    /// - Cap automatic concurrency calculations
    /// - Throw errors for exceeding these values
    /// - Prevent higher concurrency settings
    ///
    /// Users can set any concurrency value:
    /// ```swift
    /// // ✅ Allowed - no validation against these limits
    /// config.concurrency = .fixed(32)
    /// config.concurrency = .fixed(100)
    /// ```
    ///
    /// ## Tested Values
    ///
    /// Based on empirical testing with real workloads:
    ///
    /// **macOS** (8-core M-series):
    /// - 24 WebViews: 1113 PDFs/sec (optimal - 3x CPU)
    /// - 32 WebViews: 1057 PDFs/sec (still excellent)
    /// - Memory efficient at all tested levels
    ///
    /// **iOS** (varies by device):
    /// - 4-8 WebViews: Conservative for thermal/battery
    /// - Test your specific device/use case
    ///
    /// ## Automatic Defaults
    ///
    /// When using `.automatic` concurrency:
    /// - **macOS**: 3x CPU count (uncapped, e.g., 24 on 8-core)
    /// - **iOS**: min(CPU count, 4) (conservative mobile default)
    ///
    /// ## Usage
    ///
    /// Use these as **guidelines** when tuning performance:
    /// ```swift
    /// // Reference for comparison
    /// #if os(macOS)
    /// let tested = PDF.Render.ConcurrencyLimit.testedMacOS  // 32
    /// #else
    /// let tested = PDF.Render.ConcurrencyLimit.testedIOS    // 8
    /// #endif
    ///
    /// // But you can exceed them if needed
    /// config.concurrency = .fixed(tested * 2)  // No error!
    /// ```
    public enum ConcurrencyLimit {
        /// Tested maximum for macOS (reference only, not enforced)
        ///
        /// Empirical testing shows 24-32 concurrent WebViews work excellently.
        /// No hard limit - you can set higher values if your workload benefits.
        public static let testedMacOS = 32

        /// Tested maximum for iOS (reference only, not enforced)
        ///
        /// Conservative value for mobile constraints (battery, thermal).
        /// Device-specific - test your target hardware.
        public static let testedIOS = 8

        /// Mock/test limit: 1 for deterministic testing
        public static let mock = 1
    }
}
