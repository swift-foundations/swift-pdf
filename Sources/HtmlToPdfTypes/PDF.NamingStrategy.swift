//
//  PDF.NamingStrategy.swift
//  swift-html-to-pdf
//
//  Naming strategies for batch PDF operations
//

import Foundation

extension PDF {
    /// Strategy for naming files in batch operations
    ///
    /// `NamingStrategy` is a `Sendable` struct that wraps a closure for generating filenames.
    /// It provides type-safe, reusable naming patterns for batch PDF operations.
    ///
    /// ## Thread Safety
    ///
    /// All naming strategies must be `Sendable` and thread-safe since they may be called
    /// concurrently from multiple tasks during batch processing.
    ///
    /// ## Determinism and Collision Behavior
    ///
    /// - **Sequential strategy**: Deterministic, uses array index (0, 1, 2, ...). Provides
    ///   predictable naming but may collide if the same strategy is used multiple times
    ///   in the same directory without cleanup.
    ///
    /// - **UUID strategy**: Non-deterministic, generates unique names on each call. Guarantees
    ///   no collisions within a run and across runs, but filenames are not predictable.
    ///
    /// Under concurrent access:
    /// - Strategies themselves are thread-safe (immutable struct with `@Sendable` closure)
    /// - Multiple tasks can call `filename(for:)` concurrently without synchronization
    /// - The index parameter determines the filename, not the order of calls
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Sequential naming
    /// let strategy = PDF.NamingStrategy.sequential
    /// strategy.filename(for: 0)  // "1.pdf"
    /// strategy.filename(for: 1)  // "2.pdf"
    ///
    /// // UUID naming
    /// let uuidStrategy = PDF.NamingStrategy.uuid
    /// uuidStrategy.filename(for: 0)  // "550E8400-E29B-41D4-A716-446655440000.pdf"
    /// uuidStrategy.filename(for: 1)  // "A98C5E2F-3D4B-5C6D-7E8F-9A0B1C2D3E4F.pdf"
    ///
    /// // Custom strategy
    /// let dated = PDF.NamingStrategy { index in
    ///     let date = ISO8601DateFormatter().string(from: Date())
    ///     return "\(date)-\(index)"
    /// }
    /// ```
    public struct NamingStrategy: Sendable {
        private let _filename: @Sendable (Int) -> String

        /// Create a custom naming strategy
        ///
        /// - Parameter filename: A `Sendable` closure that generates a filename for a given index.
        ///   The closure must be thread-safe and should return consistent results for the same index
        ///   unless intentionally non-deterministic (like UUID-based strategies).
        public init(filename: @escaping @Sendable (Int) -> String) {
            self._filename = filename
        }

        /// Generate filename for given index
        ///
        /// - Parameter index: Zero-based index in the batch operation
        /// - Returns: Filename without extension (extension will be added by the system)
        public func filename(for index: Int) -> String {
            _filename(index)
        }
    }
}

// MARK: - Presets

extension PDF.NamingStrategy {
    /// Sequential numbering: "1.pdf", "2.pdf", ...
    public static let sequential = PDF.NamingStrategy { index in
        "\(index + 1)"
    }

    /// UUID-based names
    public static let uuid = PDF.NamingStrategy { _ in
        UUID().uuidString
    }
}
