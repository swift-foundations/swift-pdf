//
//  PDF.Render.Client+Convenience.swift
//  swift-html-to-pdf
//
//  Convenience methods built on the core primitives
//

import Foundation
import Dependencies

extension PDF.Render.Client {

    // MARK: - Single Document Conveniences

    /// Render a single document to PDF
    ///
    /// Convenience wrapper around the `documents` primitive.
    ///
    /// - Parameter document: Document to render
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    public func document(
        _ document: PDF.Document
    ) async throws -> URL {
        var result: URL?
        for try await r in try await documents([document]) {
            result = r.url
        }
        guard let url = result else {
            throw PrintingError.noResultProduced
        }
        return url
    }

    /// Render HTML string to PDF file
    ///
    /// Convenience wrapper that creates a Document and renders it.
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
        let doc = PDF.Document(htmlString: html, destination: destination)
        return try await document(doc)
    }

    // MARK: - Batch HTML Convenience

    /// Render multiple HTML strings to a directory
    ///
    /// Returns results as a stream for progressive processing.
    /// Files are named using the configured `namingStrategy`.
    ///
    /// - Parameters:
    ///   - htmls: Array of HTML strings to render
    ///   - directory: Directory to save PDFs in
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func html(
        _ htmls: [String],
        to directory: URL
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        @Dependency(\.pdf.render.configuration) var config

        let documents = htmls.enumerated().map { index, html in
            let filename = config.namingStrategy.filename(for: index)
            return PDF.Document(htmlString: html, title: filename, in: directory)
        }

        return try await self.documents(documents)
    }

    // MARK: - Data Convenience

    /// Render HTML string to PDF data (convenience)
    ///
    /// Convenience wrapper that converts String to ContiguousArray<UInt8>.
    ///
    /// - Parameter htmlString: HTML content to render
    /// - Returns: PDF data
    /// - Throws: Rendering errors
    public func data(_ htmlString: String) async throws -> Data {
        try await data(ContiguousArray(htmlString.utf8))
    }
}
