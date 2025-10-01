//
//  PDF.NamingStrategy.swift
//  swift-html-to-pdf
//
//  Naming strategies for batch PDF operations
//

import Foundation

extension PDF {
    /// Strategy for naming files in batch operations
    public enum NamingStrategy: Sendable {
        /// Sequential numbering: "1.pdf", "2.pdf", ...
        case sequential

        /// UUID-based names
        case uuid

        /// Custom naming function
        case custom(@Sendable (Int) -> String)

        /// Generate filename for given index
        public func filename(for index: Int) -> String {
            switch self {
            case .sequential:
                return "\(index + 1)"
            case .uuid:
                return UUID().uuidString
            case .custom(let closure):
                return closure(index)
            }
        }
    }
}
