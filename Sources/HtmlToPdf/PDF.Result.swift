//
//  PDF.Result.swift
//  swift-html-to-pdf
//
//  Result type for batch PDF operations
//

import Foundation

extension PDF {
    /// Result of a single PDF generation operation
    ///
    /// Returned by batch rendering operations to provide progress information
    public struct Result: Sendable {
        /// The URL where the PDF was saved
        public let url: URL

        /// The index of this document in the batch
        public let index: Int

        /// How long it took to render this PDF
        public let duration: Duration

        public init(url: URL, index: Int, duration: Duration) {
            self.url = url
            self.index = index
            self.duration = duration
        }
    }
}
