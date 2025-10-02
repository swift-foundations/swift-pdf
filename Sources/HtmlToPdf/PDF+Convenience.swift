//
//  PDF+Convenience.swift
//  swift-html-to-pdf
//
//  Top-level convenience methods for common operations
//

import Foundation

extension PDF {

    // MARK: - Most Common Operations

    /// Render documents to PDF files, yielding results as they complete
    ///
    /// Top-level convenience for the most common operation.
    /// Forwards to `render.documents()`.
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
    /// for try await result in try await pdf.documents(documents) {
    ///     print("Generated \(result.url)")
    /// }
    /// ```
    ///
    /// - Parameter documents: Documents to render
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func documents(
        _ documents: [PDF.Document]
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await render.documents(documents)
    }

    /// Render HTML to PDF file
    ///
    /// Top-level convenience for single HTML to file rendering.
    /// Forwards to `render.html()`.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let html = "<html><body><h1>Hello</h1></body></html>"
    /// let url = try await pdf.html(html, to: fileURL)
    /// ```
    ///
    /// - Parameters:
    ///   - html: HTML content to render
    ///   - destination: File URL for the PDF
    /// - Returns: URL of the generated PDF (same as destination)
    /// - Throws: Rendering errors
    public func html(
        _ html: String,
        to destination: URL
    ) async throws -> URL {
        try await render.html(html, destination)
    }

    /// Render HTML to PDF data (in-memory)
    ///
    /// Top-level convenience for in-memory PDF generation.
    /// Forwards to `render.data()`.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let html = "<html><body><h1>Hello</h1></body></html>"
    /// let pdfData = try await pdf.data(html)
    /// ```
    ///
    /// - Parameter html: HTML content to render
    /// - Returns: PDF data
    /// - Throws: Rendering errors
    public func data(
        _ html: String
    ) async throws -> Data {
        try await render.data(html)
    }

}
