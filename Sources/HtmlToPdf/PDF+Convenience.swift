//
//  PDF+Convenience.swift
//  swift-html-to-pdf
//
//  Top-level convenience methods for common operations
//

import Foundation

extension PDF {

    // MARK: - Most Common Operations

    /// Render a single document to PDF
    ///
    /// Top-level convenience for type-safe document rendering.
    /// Forwards to `render.document()`.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let document = PDF.Document(
    ///     htmlString: html,
    ///     destination: url,
    ///     paginationMode: .paginated
    /// )
    ///
    /// let result = try await pdf.document(document)
    /// print("Generated \(result)")
    /// ```
    ///
    /// - Parameter document: Document to render
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    public func document(
        _ document: PDF.Document
    ) async throws -> URL {
        try await render.document(document)
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
        try await render.html(html, to: destination)
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
