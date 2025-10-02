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
        /// This is the core primitive rendering operation. Documents are rendered concurrently
        /// based on configuration settings, with results streamed as each completes.
        ///
        /// All other rendering methods are composed from this primitive.
        ///
        /// - Parameter documents: Documents to render
        /// - Returns: Stream of results as PDFs are generated
        /// - Throws: Rendering errors
        @DependencyEndpoint
        public var documents: @Sendable (
            _ documents: [PDF.Document]
        ) async throws -> AsyncThrowingStream<PDF.Result, Error>

        /// Render HTML to PDF data (in-memory, no file I/O)
        ///
        /// This uses a different platform API (WKWebView.createPDF) and cannot be
        /// composed from file-based operations without inefficiency.
        ///
        /// - Parameter html: HTML content to render
        /// - Returns: PDF data
        /// - Throws: Rendering errors
        @DependencyEndpoint
        public var data: @Sendable (
            _ html: String
        ) async throws -> Data

        // MARK: - Platform Capabilities

        /// Get capabilities of current implementation
        @DependencyEndpoint
        public var capabilities: @Sendable () -> PDF.Capabilities = { .mock }
    }
}
