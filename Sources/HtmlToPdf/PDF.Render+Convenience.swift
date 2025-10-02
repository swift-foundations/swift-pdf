//
//  PDF.Render+Convenience.swift
//  swift-html-to-pdf
//
//  Convenience methods that forward to client
//

import Foundation

extension PDF.Render {

    // MARK: - Core Operations

    /// Render documents to PDF files, yielding results as they complete
    ///
    /// Convenience method that forwards to `client.documents()`.
    ///
    /// - Parameter documents: Documents to render
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func documents(
        _ documents: [PDF.Document]
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await client.documents(documents)
    }

    /// Render a single document to PDF
    ///
    /// Convenience method that forwards to `client.document()`.
    ///
    /// - Parameter document: Document to render
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    public func document(
        _ document: PDF.Document
    ) async throws -> URL {
        try await client.document(document)
    }

    /// Render HTML string to PDF file
    ///
    /// Convenience method that forwards to `client.html()`.
    ///
    /// - Parameters:
    ///   - html: HTML content to render
    ///   - destination: File URL for the PDF
    /// - Returns: URL of the generated PDF (same as destination)
    /// - Throws: Rendering errors
    public func html(
        _ html: String,
        _ destination: URL
    ) async throws -> URL {
        try await client.html(html, destination)
    }

    /// Render HTML to PDF data (in-memory, no file I/O)
    ///
    /// Convenience method that forwards to `client.data()`.
    ///
    /// - Parameter html: HTML content to render
    /// - Returns: PDF data
    /// - Throws: Rendering errors
    public func data(
        _ html: String
    ) async throws -> Data {
        try await client.data(html)
    }

    // MARK: - Batch Operations

    /// Render multiple documents, collecting all URLs
    ///
    /// Convenience method that forwards to `client.renderSync()`.
    /// Waits for all documents to complete before returning.
    ///
    /// - Parameter documents: Documents to render
    /// - Returns: Array of URLs in the same order as input documents
    /// - Throws: Rendering errors
    public func renderSync(
        _ documents: [PDF.Document]
    ) async throws -> [URL] {
        try await client.renderSync(documents)
    }

    /// Render multiple HTML strings to a directory
    ///
    /// Convenience method that forwards to `client.renderBatch()`.
    /// Returns results as a stream for progressive processing.
    ///
    /// - Parameters:
    ///   - htmls: Array of HTML strings to render
    ///   - directory: Directory to save PDFs in
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func renderBatch(
        _ htmls: [String],
        to directory: URL
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await client.renderBatch(htmls, to: directory)
    }

    /// Render multiple HTML strings to a directory (unlabeled directory)
    ///
    /// Convenience method that forwards to `client.renderBatch()`.
    ///
    /// - Parameters:
    ///   - htmls: Array of HTML strings to render
    ///   - directory: Directory to save PDFs in
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func renderBatch(
        _ htmls: [String],
        _ directory: URL
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await client.renderBatch(htmls, directory)
    }

    /// Render multiple HTML strings to a directory, collecting all URLs
    ///
    /// Convenience method that forwards to `client.renderBatchSync()`.
    /// Waits for all documents to complete before returning.
    ///
    /// - Parameters:
    ///   - htmls: Array of HTML strings to render
    ///   - directory: Directory to save PDFs in
    /// - Returns: Array of URLs in the same order as input
    /// - Throws: Rendering errors
    public func renderBatchSync(
        _ htmls: [String],
        to directory: URL
    ) async throws -> [URL] {
        try await client.renderBatchSync(htmls, to: directory)
    }

    /// Render multiple HTML strings to a directory, collecting all URLs (unlabeled directory)
    ///
    /// Convenience method that forwards to `client.renderBatchSync()`.
    ///
    /// - Parameters:
    ///   - htmls: Array of HTML strings to render
    ///   - directory: Directory to save PDFs in
    /// - Returns: Array of URLs in the same order as input
    /// - Throws: Rendering errors
    public func renderBatchSync(
        _ htmls: [String],
        _ directory: URL
    ) async throws -> [URL] {
        try await client.renderBatchSync(htmls, directory)
    }

    // MARK: - Platform Capabilities

    /// Get capabilities of current implementation
    ///
    /// Convenience method that forwards to `client.capabilities()`.
    ///
    /// - Returns: Platform capabilities
    public func capabilities() -> PDF.Capabilities {
        client.capabilities()
    }
}
