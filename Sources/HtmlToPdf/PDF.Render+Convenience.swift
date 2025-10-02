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
    /// - Parameter documents: Documents to render (any sequence)
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func documents(
        _ documents: some Sequence<PDF.Document>
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

    // MARK: - Batch Operations

    /// Render multiple HTML strings to a directory
    ///
    /// Convenience method that forwards to `client.html()`.
    /// Returns results as a stream for progressive processing.
    ///
    /// - Parameters:
    ///   - htmls: HTML strings to render (any sequence)
    ///   - directory: Directory to save PDFs in
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func html(
        _ htmls: some Sequence<String>,
        to directory: URL
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await client.html(htmls, to: directory)
    }

    // MARK: - Data Operations

    /// Render multiple HTML strings to PDF data, yielding results as they complete
    ///
    /// Convenience method that forwards to `client.data()`.
    ///
    /// - Parameter htmlStrings: HTML strings to render (any sequence)
    /// - Returns: Stream of PDF data as each completes
    /// - Throws: Rendering errors
    public func data(
        _ htmlStrings: some Sequence<String>
    ) async throws -> AsyncThrowingStream<Data, Error> {
        try await client.data(htmlStrings)
    }

    /// Render a single HTML string to PDF data
    ///
    /// Convenience method that forwards to `client.data()`.
    ///
    /// - Parameter htmlString: HTML content to render
    /// - Returns: PDF data
    /// - Throws: Rendering errors
    public func data(_ htmlString: String) async throws -> Data {
        try await client.data(htmlString)
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
