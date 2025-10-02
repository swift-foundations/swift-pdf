//
//  PDF.swift
//  swift-html-to-pdf
//
//  Core namespace for PDF rendering operations
//

import Dependencies
import Foundation

/// PDF domain containing client and configuration
///
/// This type serves as the unified entry point for all PDF operations.
/// Access the client for rendering operations and configuration for settings.
///
/// ## Basic Usage
///
/// ```swift
/// @Dependency(\.pdf) var pdf
///
/// // Render with defaults
/// try await pdf.render(html, to: url)
///
/// // Configure and render
/// try await withDependencies {
///     $0.pdf.configuration.paperSize = .letter
///     $0.pdf.configuration.margins = .wide
/// } operation: {
///     try await pdf.render(html, to: url)
/// }
/// ```
///
/// ## Direct Subdomain Access
///
/// ```swift
/// @Dependency(\.pdf.client) var client
/// @Dependency(\.pdf.configuration) var config
///
/// // Access client directly
/// let stream = try await client.render(documents)
///
/// // Access configuration directly
/// let poolSize = config.concurrency
/// ```
public struct PDF: Sendable {
    /// Client for rendering operations
    public var client: Client

    /// Configuration for PDF rendering
    public var configuration: Configuration

    public init(
        client: Client,
        configuration: Configuration
    ) {
        self.client = client
        self.configuration = configuration
    }
}

// MARK: - Convenience Forwarding

extension PDF {

    // MARK: - Core Primitive

    /// Render documents to PDF files, yielding results as they complete
    ///
    /// This forwards to `client.render()` for convenience.
    ///
    /// - Parameter documents: Documents to render
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func render(
        _ documents: [Document]
    ) async throws -> AsyncThrowingStream<Result, Error> {
        try await client.render(documents)
    }

    // MARK: - Single Document Convenience

    /// Render a single document to PDF
    public func render(_ document: Document) async throws -> URL {
        try await client.render(document)
    }

    /// Render HTML string to PDF file
    public func render(_ html: String, to destination: URL) async throws -> URL {
        try await client.render(html, to: destination)
    }

    /// Render HTML string to PDF file (unlabeled destination)
    public func render(_ html: String, _ destination: URL) async throws -> URL {
        try await client.render(html, destination)
    }

    /// Render HTML string to PDF with a title in a directory
    public func render(_ html: String, title: String, in directory: URL) async throws -> URL {
        try await client.render(html, title: title, in: directory)
    }

    /// Render HTML to PDF data (in-memory, no file I/O)
    public func renderToData(_ html: String) async throws -> Data {
        try await client.renderToData(html)
    }

    // MARK: - Batch Convenience

    /// Render multiple documents, collecting all URLs
    public func renderSync(_ documents: [Document]) async throws -> [URL] {
        try await client.renderSync(documents)
    }

    /// Render multiple HTML strings to a directory
    public func renderBatch(
        _ htmls: [String],
        to directory: URL
    ) async throws -> AsyncThrowingStream<Result, Error> {
        try await client.renderBatch(htmls, to: directory)
    }

    /// Render multiple HTML strings to a directory (unlabeled directory)
    public func renderBatch(
        _ htmls: [String],
        _ directory: URL
    ) async throws -> AsyncThrowingStream<Result, Error> {
        try await client.renderBatch(htmls, directory)
    }

    /// Render multiple HTML strings to a directory, collecting all URLs
    public func renderBatchSync(
        _ htmls: [String],
        to directory: URL
    ) async throws -> [URL] {
        try await client.renderBatchSync(htmls, to: directory)
    }

    /// Render multiple HTML strings to a directory, collecting all URLs (unlabeled directory)
    public func renderBatchSync(
        _ htmls: [String],
        _ directory: URL
    ) async throws -> [URL] {
        try await client.renderBatchSync(htmls, directory)
    }

    // MARK: - Platform Capabilities

    /// Get capabilities of current implementation
    public func capabilities() -> Capabilities {
        client.capabilities()
    }
}

// MARK: - Dependency Registration

extension PDF: TestDependencyKey {
    public static let testValue = PDF(
        client: .testValue,
        configuration: .testValue
    )
}

extension DependencyValues {
    public var pdf: PDF {
        get { self[PDF.self] }
        set { self[PDF.self] = newValue }
    }
}
