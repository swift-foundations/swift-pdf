//
//  PDF+Convenience.swift
//  swift-html-to-pdf
//
//  Top-level convenience methods for common operations (string-based)
//

import Dependencies
import Foundation

extension PDF {

    // MARK: - Render Operations (String-based)

    /// Render HTML string to PDF file
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let html = "<html><body><h1>Hello</h1></body></html>"
    /// try await pdf.render(html: html, to: fileURL)
    /// ```
    ///
    /// - Parameters:
    ///   - html: HTML content to render
    ///   - destination: File URL for the PDF
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    public func render(
        html: String,
        to destination: URL
    ) async throws -> URL {
        try await render.html(html, to: destination)
    }

    /// Render a document to PDF
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let document = PDF.Document(htmlString: html, destination: fileURL)
    /// try await pdf.render(document: document)
    /// ```
    ///
    /// - Parameter document: Document to render
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    public func render(
        document: PDF.Document
    ) async throws -> URL {
        try await render.document(document)
    }

    /// Render HTML string to PDF data (in-memory)
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let html = "<html><body><h1>Hello</h1></body></html>"
    /// let pdfData = try await pdf.render(html: html)
    /// ```
    ///
    /// - Parameter html: HTML content to render
    /// - Returns: PDF data
    /// - Throws: Rendering errors
    public func render(
        html: String
    ) async throws -> Data {
        try await render.data(html)
    }

    // MARK: - Batch Operations

    /// Render multiple HTML strings to a directory
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let html = [
    ///     "<html><body><h1>Doc 1</h1></body></html>",
    ///     "<html><body><h1>Doc 2</h1></body></html>"
    /// ]
    ///
    /// for try await result in try await pdf.render(html: html, to: directory) {
    ///     print("Generated \(result.url.lastPathComponent)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - html: HTML strings to render
    ///   - directory: Directory to save PDFs in
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func render(
        html: some Sequence<String>,
        to directory: URL
    ) async throws -> AsyncThrowingStream<PDF.Render.Result, Error> {
        try await render.html(html, to: directory)
    }

    /// Render multiple documents to PDFs
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let documents = [
    ///     PDF.Document(htmlString: html1, destination: url1),
    ///     PDF.Document(htmlString: html2, destination: url2)
    /// ]
    ///
    /// for try await result in try await pdf.render(documents: documents) {
    ///     print("Generated \(result.url.lastPathComponent)")
    /// }
    /// ```
    ///
    /// - Parameter documents: Documents to render
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func render(
        documents: some Sequence<PDF.Document>
    ) async throws -> AsyncThrowingStream<PDF.Render.Result, Error> {
        try await render.documents(documents)
    }

    // MARK: - Base URL Configuration

    /// Configure a base URL for resolving relative resources in HTML
    ///
    /// Returns a PDF instance that will use the specified base URL when rendering.
    /// This allows chaining: `pdf.withBaseURL(...).render(...)`
    ///
    /// - Parameter baseURL: The base URL to use for resolving relative URLs
    /// - Returns: A PDF instance configured with the base URL
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let html = #"<img src="logo.png">"#
    /// let assetsURL = URL(fileURLWithPath: "/path/to/assets")
    ///
    /// try await pdf
    ///     .withBaseURL(assetsURL)
    ///     .render(html: html, to: output)
    /// // Image will load from /path/to/assets/logo.png
    /// ```
    public func withBaseURL(_ baseURL: URL?) -> PDF {
        @Dependency(\.pdf) var currentPDF

        var modified = currentPDF
        modified.render.configuration.baseURL = baseURL
        return modified
    }

}
