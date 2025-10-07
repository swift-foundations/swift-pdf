//
//  PDF.Render.Result.swift
//  swift-html-to-pdf
//
//  Result type for batch PDF operations
//

import Foundation

extension PDF.Render {
    /// Result of a single PDF generation operation
    ///
    /// Returned as PDFs complete during batch rendering operations. Provides timing
    /// information, pagination details, and verification data.
    ///
    /// ## Usage in Batch Operations
    ///
    /// Results are streamed as each PDF completes, enabling real-time progress tracking:
    ///
    /// ```swift
    /// @Dependency(\.pdf.render.client) var renderClient
    ///
    /// var completed = 0
    /// let total = documents.count
    ///
    /// for try await result in try await renderClient.documents(documents) {
    ///     completed += 1
    ///     print("[\(completed)/\(total)] Generated \(result.url.lastPathComponent)")
    ///     print("  Duration: \(result.duration)")
    ///     print("  Pages: \(result.pageCount)")
    ///     print("  Mode: \(result.paginationMode)")
    /// }
    /// ```
    ///
    /// ## Automatic Pagination Detection
    ///
    /// When using `.automatic()` pagination mode, the `paginationMode` property
    /// reveals which mode was selected based on content analysis:
    ///
    /// ```swift
    /// for try await result in try await renderClient.documents(documents) {
    ///     switch result.paginationMode {
    ///     case .continuous:
    ///         print("Fast path used (continuous rendering)")
    ///     case .paginated:
    ///         print("Print-ready (\(result.pageCount) pages)")
    ///     case .automatic:
    ///         // Should not happen - automatic resolves to concrete mode
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// ## Page Dimensions
    ///
    /// The `pageDimensions` array provides exact size of each generated page:
    /// - **Continuous mode**: Single entry with full content height (width matches paperSize)
    /// - **Paginated mode**: Multiple entries, all matching configured `paperSize`
    ///
    /// Use this for verification or analytics:
    ///
    /// ```swift
    /// // Find PDFs with unusually tall pages
    /// let tallPages = results.filter { result in
    ///     result.pageDimensions.contains { $0.height > 2000 }
    /// }
    ///
    /// // Calculate total page count across batch
    /// let totalPages = results.map(\.pageCount).reduce(0, +)
    /// ```
    ///
    /// ## Performance Analysis
    ///
    /// Results include precise timing for each PDF:
    ///
    /// ```swift
    /// let results = try await Array(renderClient.documents(documents))
    ///
    /// // Average render time
    /// let totalDuration = results.map(\.duration).reduce(.zero, +)
    /// let average = totalDuration / results.count
    ///
    /// // Identify slow PDFs
    /// let slowPDFs = results.filter { $0.duration > .seconds(5) }
    /// ```
    public struct Result: Sendable {
        /// The URL where the PDF was saved
        public let url: URL

        /// The index of this document in the batch
        public let index: Int

        /// How long it took to render this PDF
        public let duration: Duration

        /// The pagination mode that was actually used for rendering
        public let paginationMode: PDF.PaginationMode

        /// Number of pages in the generated PDF
        public let pageCount: Int

        /// Dimensions of each page in the PDF
        public let pageDimensions: [CGSize]

        package init(
            url: URL,
            index: Int,
            duration: Duration,
            paginationMode: PDF.PaginationMode,
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
