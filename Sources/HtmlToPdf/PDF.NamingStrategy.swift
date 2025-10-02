//
//  PDF.NamingStrategy.swift
//  swift-html-to-pdf
//
//  Naming strategies for batch PDF operations
//

import Foundation

extension PDF {
    /// Strategy for naming files in batch operations
    public struct NamingStrategy: Sendable {
        private let _filename: @Sendable (Int) -> String

        /// Create a custom naming strategy
        public init(filename: @escaping @Sendable (Int) -> String) {
            self._filename = filename
        }

        /// Generate filename for given index
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
