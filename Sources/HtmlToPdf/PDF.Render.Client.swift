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

        // MARK: - Core Rendering Operations

        /// Render documents to PDF files, yielding results as they complete
        ///
        /// This is the primary rendering operation. Documents are rendered concurrently
        /// based on configuration settings, with results streamed as each completes.
        ///
        /// - Parameter documents: Documents to render
        /// - Returns: Stream of results as PDFs are generated
        /// - Throws: Rendering errors
        @DependencyEndpoint
        public var documents: @Sendable (
            _ documents: [PDF.Document]
        ) async throws -> AsyncThrowingStream<PDF.Result, Error>

        /// Render a single document to PDF
        ///
        /// - Parameter document: Document to render
        /// - Returns: URL of the generated PDF
        /// - Throws: Rendering errors
        @DependencyEndpoint
        public var document: @Sendable (
            _ document: PDF.Document
        ) async throws -> URL

        /// Render HTML string to PDF file
        ///
        /// - Parameters:
        ///   - html: HTML content to render
        ///   - destination: File URL for the PDF
        /// - Returns: URL of the generated PDF (same as destination)
        /// - Throws: Rendering errors
        @DependencyEndpoint
        public var html: @Sendable (
            _ html: String,
            _ destination: URL
        ) async throws -> URL

        /// Render HTML to PDF data (in-memory, no file I/O)
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
