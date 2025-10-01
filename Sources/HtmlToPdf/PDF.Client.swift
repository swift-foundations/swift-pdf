//
//  PDF.Client.swift
//  swift-html-to-pdf
//
//  Client interface for PDF rendering operations
//

import Dependencies
import DependenciesMacros
import Foundation

extension PDF {
    /// Client for rendering HTML to PDF
    ///
    /// Usage:
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// // Single document
    /// let url = try await pdf.render(html, to: fileURL)
    ///
    /// // Batch rendering with progress
    /// for try await result in try await pdf.renderBatch(htmls, to: directory) {
    ///     print("Generated \(result.url)")
    /// }
    /// ```
    public struct Client: Sendable {

        // MARK: - Single Document Operations

        /// Render HTML string to PDF file
        @DependencyEndpoint
        public var render: @Sendable (
            _ html: String,
            _ destination: URL
        ) async throws -> URL

        /// Render HTML string to PDF file with title
        @DependencyEndpoint
        public var renderWithTitle: @Sendable (
            _ html: String,
            _ title: String,
            _ directory: URL
        ) async throws -> URL

        /// Render HTML to PDF data (no file I/O)
        @DependencyEndpoint
        public var renderToData: @Sendable (
            _ html: String
        ) async throws -> Data

        /// Render document to PDF
        @DependencyEndpoint
        public var renderDocument: @Sendable (
            _ document: Document
        ) async throws -> URL

        // MARK: - Batch Operations

        /// Render multiple HTML strings to directory
        /// Returns AsyncSequence for progressive results
        @DependencyEndpoint
        public var renderBatch: @Sendable (
            _ htmls: [String],
            _ directory: URL
        ) async throws -> AsyncThrowingStream<Result, Error>

        /// Render multiple documents
        @DependencyEndpoint
        public var renderDocuments: @Sendable (
            _ documents: [Document]
        ) async throws -> AsyncThrowingStream<Result, Error>

        /// Render batch and collect all URLs (waits for completion)
        @DependencyEndpoint
        public var renderBatchSync: @Sendable (
            _ htmls: [String],
            _ directory: URL
        ) async throws -> [URL]

        // MARK: - Platform Capabilities

        /// Get capabilities of current implementation
        @DependencyEndpoint
        public var capabilities: @Sendable () -> Capabilities = { .mock }

        public init(
            render: @escaping @Sendable (String, URL) async throws -> URL,
            renderWithTitle: @escaping @Sendable (String, String, URL) async throws -> URL,
            renderToData: @escaping @Sendable (String) async throws -> Data,
            renderDocument: @escaping @Sendable (Document) async throws -> URL,
            renderBatch: @escaping @Sendable ([String], URL) async throws -> AsyncThrowingStream<Result, Error>,
            renderDocuments: @escaping @Sendable ([Document]) async throws -> AsyncThrowingStream<Result, Error>,
            renderBatchSync: @escaping @Sendable ([String], URL) async throws -> [URL],
            capabilities: @escaping @Sendable () -> Capabilities
        ) {
            self.render = render
            self.renderWithTitle = renderWithTitle
            self.renderToData = renderToData
            self.renderDocument = renderDocument
            self.renderBatch = renderBatch
            self.renderDocuments = renderDocuments
            self.renderBatchSync = renderBatchSync
            self.capabilities = capabilities
        }
    }
}

// MARK: - Dependency Registration

extension PDF.Client: TestDependencyKey {
    public static let testValue = PDF.Client(
        render: unimplemented("PDF.Client.render"),
        renderWithTitle: unimplemented("PDF.Client.renderWithTitle"),
        renderToData: unimplemented("PDF.Client.renderToData"),
        renderDocument: unimplemented("PDF.Client.renderDocument"),
        renderBatch: unimplemented("PDF.Client.renderBatch"),
        renderDocuments: unimplemented("PDF.Client.renderDocuments"),
        renderBatchSync: unimplemented("PDF.Client.renderBatchSync"),
        capabilities: unimplemented("PDF.Client.capabilities")
    )
}

extension DependencyValues {
    public var pdf: PDF.Client {
        get { self[PDF.Client.self] }
        set { self[PDF.Client.self] = newValue }
    }
}
