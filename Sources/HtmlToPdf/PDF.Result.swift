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
    /// and verification data.
    public struct Result: Sendable {
        /// The URL where the PDF was saved
        public let url: URL

        /// The index of this document in the batch
        public let index: Int

        /// How long it took to render this PDF
        public let duration: Duration

        /// The pagination mode that was actually used for rendering
        public let paginationMode: PaginationMode

        /// Number of pages in the generated PDF
        public let pageCount: Int

        /// Dimensions of each page in the PDF
        public let pageDimensions: [CGSize]

        public init(
            url: URL,
            index: Int,
            duration: Duration,
            paginationMode: PaginationMode,
            pageCount: Int,
            pageDimensions: [CGSize]
        ) {
            self.url = url
            self.index = index
            self.duration = duration
            self.paginationMode = paginationMode
            self.pageCount = pageCount
            self.pageDimensions = pageDimensions
        }
    }
}
