//
//  PDF+Convenience.swift
//  swift-html-to-pdf
//
//  Top-level convenience methods for common operations
//

import Foundation
import PointFreeHTML

extension PDF {

    // MARK: - Render Operations

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

    /// Render type-safe HTML to PDF file
    ///
    /// ## Usage
    ///
    /// ```swift
    /// import HTML
    ///
    /// struct MyPage: HTML {
    ///     var body: some HTML {
    ///         html {
    ///             head { title { "My Document" } }
    ///             body { h1 { "Hello, World!" } }
    ///         }
    ///     }
    /// }
    ///
    /// @Dependency(\.pdf) var pdf
    /// try await pdf.render(html: MyPage(), to: fileURL)
    /// ```
    ///
    /// - Parameters:
    ///   - html: Type-safe HTML content
    ///   - destination: File URL for the PDF
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    public func render<H: HTML>(
        html: H,
        to destination: URL
    ) async throws -> URL {
        let document = PDF.Document(html: html, destination: destination)
        return try await render.document(document)
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

    /// Render type-safe HTML to PDF data (in-memory)
    ///
    /// ## Usage
    ///
    /// ```swift
    /// import HTML
    ///
    /// @Dependency(\.pdf) var pdf
    /// let pdfData = try await pdf.render(html: MyPage())
    /// ```
    ///
    /// - Parameter html: Type-safe HTML content
    /// - Returns: PDF data
    /// - Throws: Rendering errors
    public func render<H: HTML>(
        html: H
    ) async throws -> Data {
        let htmlString = String(decoding: html.render(), as: UTF8.self)
        return try await render.data(htmlString)
    }

    // MARK: - Batch Operations

    /// Render multiple HTML strings to a directory
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let htmls = [
    ///     "<html><body><h1>Doc 1</h1></body></html>",
    ///     "<html><body><h1>Doc 2</h1></body></html>"
    /// ]
    ///
    /// for try await result in try await pdf.render(htmls: htmls, to: directory) {
    ///     print("Generated \(result.url.lastPathComponent)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - htmls: HTML strings to render
    ///   - directory: Directory to save PDFs in
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func render(
        htmls: some Sequence<String>,
        to directory: URL
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await render.html(htmls, to: directory)
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
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await render.documents(documents)
    }

}
