//
//  PDF.ConcurrencyStrategy.swift
//  swift-html-to-pdf
//
//  Strategy for determining concurrency during PDF rendering
//

import Foundation

// MARK: - Concurrency Strategy

extension PDF {
    /// Strategy for determining concurrency during PDF rendering
    ///
    /// Supports both explicit integer values and automatic calculation:
    /// ```swift
    /// // Integer literal
    /// configuration.concurrency = 4
    ///
    /// // Explicit fixed
    /// configuration.concurrency = .fixed(8)
    ///
    /// // Automatic (intelligent defaults based on hardware)
    /// configuration.concurrency = .automatic
    /// ```
    public struct ConcurrencyStrategy: Sendable, Equatable, ExpressibleByIntegerLiteral {
        internal let mode: Mode

        internal enum Mode: Sendable, Equatable {
            case fixed(Int)
            case automatic
        }

        // MARK: - Initialization

        private init(mode: Mode) {
            self.mode = mode
        }

        // MARK: - ExpressibleByIntegerLiteral

        public init(integerLiteral value: Int) {
            self.mode = .fixed(value)
        }

        // MARK: - Static Constructors

        /// Fixed concurrency - use exact number of concurrent operations
        public static func fixed(_ value: Int) -> Self {
            Self(mode: .fixed(value))
        }

        /// Automatic concurrency - calculate optimal value based on CPU count and available memory
        public static let automatic = Self(mode: .automatic)

        // MARK: - Internal

        /// Calculate optimal concurrency based on system hardware
        ///
        /// Empirical testing shows WebView memory usage does NOT scale linearly:
        /// - 1 WebView: ~100 MB total (includes pool overhead)
        /// - 4 WebViews: ~37 MB total (GC cleanup)
        /// - 8 WebViews: ~38 MB total
        /// - 16 WebViews: ~32 MB total
        ///
        /// Memory actually DECREASES with higher concurrency due to efficient resource management.
        /// Therefore, we can safely use CPU count without artificial memory-based caps.
        internal static func calculateDefaultConcurrency() -> Int {
            let cpuCount = ProcessInfo.processInfo.activeProcessorCount

            #if canImport(UIKit)
            // iOS: Still cap at 4 due to mobile constraints (battery, thermal, app suspension)
            return max(2, min(cpuCount, 4))
            #else
            // macOS/Linux: Use all available CPU cores
            // No artificial cap - let hardware be the limit
            return max(2, cpuCount)
            #endif
        }

        /// Resolve to concrete concurrency value
        internal var resolved: Int {
            switch mode {
            case .fixed(let value):
                return max(1, value)
            case .automatic:
                return Self.calculateDefaultConcurrency()
            }
        }
    }
}
