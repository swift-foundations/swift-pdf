//
//  PDF.Render.Client.swift
//  swift-html-to-pdf
//
//  Client interface for PDF rendering operations
//

import Dependencies
import DependenciesMacros
import Foundation

extension PDF.Render {
    /// Client for rendering HTML to PDF
    ///
    /// This client exposes core rendering operations following the domain-first pattern.
    /// All operations are defined as dependency endpoints for testability.
    ///
    /// ## Basic Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf.render.client) var renderClient
    ///
    /// let documents = [
    ///     PDF.Document(htmlString: html1, destination: url1),
    ///     PDF.Document(htmlString: html2, destination: url2)
    /// ]
    ///
    /// for try await result in try await renderClient.documents(documents) {
    ///     print("Generated \(result.url) in \(result.duration)")
    /// }
    /// ```
    @DependencyClient
    public struct Client: @unchecked Sendable {

        // MARK: - Primitive Operations

        /// Render documents to PDF files, yielding results as they complete
        ///
        /// This is the sole primitive rendering operation. Documents are rendered concurrently
        /// based on configuration settings, with results streamed as each completes.
        ///
        /// **Fail-Fast Behavior**: Throws on first error, stopping batch processing.
        /// For resilient batch processing that continues on individual failures, use ``documentsResilient(_:)``.
        ///
        /// All other rendering methods are composed from this primitive.
        ///
        /// - Parameter documents: Documents to render (any sequence)
        /// - Returns: Stream of results as PDFs are generated
        /// - Throws: Rendering errors (stops entire batch)
        @DependencyEndpoint
        public var documents: @Sendable (
            _ documents: any Sequence<PDF.Document>
        ) async throws -> AsyncThrowingStream<PDF.Result, Error>

        /// Render documents to PDF files, continuing on individual failures
        ///
        /// Resilient variant that reports failures without stopping the batch.
        /// Each document result is wrapped in a `Result` type - successes yield `.success(PDF.Result)`,
        /// failures yield `.failure(PDF.FailedDocument)`.
        ///
        /// **Resilient Behavior**: Never throws - individual failures are reported as `.failure` cases.
        ///
        /// ## Example
        ///
        /// ```swift
        /// for await result in await renderClient.documentsResilient(documents) {
        ///     switch result {
        ///     case .success(let pdf):
        ///         print("✅ \(pdf.url.lastPathComponent)")
        ///     case .failure(let failed):
        ///         print("❌ Document \(failed.index): \(failed.error)")
        ///         // Continue processing remaining documents
        ///     }
        /// }
        /// ```
        ///
        /// - Parameter documents: Documents to render (any sequence)
        /// - Returns: Stream of results (never throws)
        @DependencyEndpoint
        public var documentsResilient: @Sendable (
            _ documents: any Sequence<PDF.Document>
        ) async -> AsyncStream<PDF.Render.BatchResult> = { _ in
            AsyncStream { _ in }
        }

        // MARK: - Platform Capabilities

        /// Get capabilities of current implementation
        @DependencyEndpoint
        public var capabilities: @Sendable () -> PDF.Capabilities = { .mock }
    }
}
