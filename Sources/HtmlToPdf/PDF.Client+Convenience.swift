//
//  PDF.Client+Convenience.swift
//  swift-html-to-pdf
//
//  Convenience methods built on the core primitive
//

import Foundation
import Dependencies

// MARK: - Single Document Convenience

extension PDF.Client {

    /// Render a single document to PDF
    ///
    /// - Parameter document: Document to render
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    public func render(_ document: PDF.Document) async throws -> URL {
        let stream = try await self.render([document])
        for try await result in stream {
            return result.url
        }
        throw PrintingError.pdfGenerationFailed(
            underlyingError: NSError(
                domain: "HtmlToPdf",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No results returned from render operation"]
            )
        )
    }

    /// Render HTML string to PDF file
    ///
    /// - Parameters:
    ///   - html: HTML content to render
    ///   - destination: File URL for the PDF
    /// - Returns: URL of the generated PDF (same as destination)
    /// - Throws: Rendering errors
    public func render(_ html: String, to destination: URL) async throws -> URL {
        let document = PDF.Document(htmlString: html, destination: destination)
        let stream = try await self.render([document])
        for try await result in stream {
            return result.url
        }
        throw PrintingError.pdfGenerationFailed(
            underlyingError: NSError(
                domain: "HtmlToPdf",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No results returned from render operation"]
            )
        )
    }

    /// Render HTML string to PDF file (unlabeled destination)
    ///
    /// - Parameters:
    ///   - html: HTML content to render
    ///   - destination: File URL for the PDF
    /// - Returns: URL of the generated PDF (same as destination)
    /// - Throws: Rendering errors
    public func render(_ html: String, _ destination: URL) async throws -> URL {
        try await render(html, to: destination)
    }

    /// Render HTML string to PDF with a title in a directory
    ///
    /// - Parameters:
    ///   - html: HTML content to render
    ///   - title: Filename (without .pdf extension)
    ///   - directory: Directory to save the PDF in
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    public func render(_ html: String, title: String, in directory: URL) async throws -> URL {
        let document = PDF.Document(htmlString: html, title: title, in: directory)
        let stream = try await self.render([document])
        for try await result in stream {
            return result.url
        }
        throw PrintingError.pdfGenerationFailed(
            underlyingError: NSError(
                domain: "HtmlToPdf",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No results returned from render operation"]
            )
        )
    }

    /// Render HTML to PDF data (in-memory, no file I/O)
    ///
    /// - Parameter html: HTML content to render
    /// - Returns: PDF data
    /// - Throws: Rendering errors
    ///
    /// - Note: This creates a temporary file and deletes it after reading.
    ///   For batch in-memory operations, consider using file-based rendering
    ///   and managing cleanup yourself for better performance.
    public func renderToData(_ html: String) async throws -> Data {
        let tempURL = URL.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        _ = try await render(html, to: tempURL)
        return try Data(contentsOf: tempURL)
    }
}

// MARK: - Batch Convenience

extension PDF.Client {

    /// Render multiple documents, collecting all URLs
    ///
    /// Waits for all documents to complete before returning.
    ///
    /// - Parameter documents: Documents to render
    /// - Returns: Array of URLs in the same order as input documents
    /// - Throws: Rendering errors
    public func renderSync(_ documents: [PDF.Document]) async throws -> [URL] {
        var results: [Int: URL] = [:]
        results.reserveCapacity(documents.count)

        let stream = try await render(documents)
        for try await result in stream {
            results[result.index] = result.url
        }

        // Return in original order
        return (0..<documents.count).compactMap { results[$0] }
    }

    /// Render multiple HTML strings to a directory
    ///
    /// Returns results as a stream for progressive processing.
    ///
    /// - Parameters:
    ///   - htmls: Array of HTML strings to render
    ///   - directory: Directory to save PDFs in
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    ///
    /// Files are named using the configured `namingStrategy`.
    public func renderBatch(
        _ htmls: [String],
        to directory: URL
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        @Dependency(\.pdfConfiguration) var config

        let documents = htmls.enumerated().map { index, html in
            let filename = config.namingStrategy.filename(for: index)
            return PDF.Document(htmlString: html, title: filename, in: directory)
        }

        return try await render(documents)
    }

    /// Render multiple HTML strings to a directory (unlabeled directory)
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
        try await renderBatch(htmls, to: directory)
    }

    /// Render multiple HTML strings to a directory, collecting all URLs
    ///
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
        @Dependency(\.pdfConfiguration) var config

        let documents = htmls.enumerated().map { index, html in
            let filename = config.namingStrategy.filename(for: index)
            return PDF.Document(htmlString: html, title: filename, in: directory)
        }

        return try await renderSync(documents)
    }

    /// Render multiple HTML strings to a directory, collecting all URLs (unlabeled directory)
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
        try await renderBatchSync(htmls, to: directory)
    }
}

// MARK: - Legacy Compatibility

extension PDF.Client {

    /// Render HTML string to PDF with title (legacy name)
    ///
    /// - Parameters:
    ///   - html: HTML content to render
    ///   - title: Filename (without .pdf extension)
    ///   - directory: Directory to save the PDF in
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    @available(*, deprecated, renamed: "render(_:title:in:)")
    public func renderWithTitle(
        _ html: String,
        _ title: String,
        _ directory: URL
    ) async throws -> URL {
        try await render(html, title: title, in: directory)
    }

    /// Render a single document (legacy name)
    ///
    /// - Parameter document: Document to render
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    @available(*, deprecated, message: "Use render(_:) instead")
    public func renderDocument(_ document: PDF.Document) async throws -> URL {
        try await render(document)
    }

    /// Render multiple documents (legacy name)
    ///
    /// - Parameter documents: Documents to render
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    @available(*, deprecated, message: "Use render(_:) instead")
    public func renderDocuments(
        _ documents: [PDF.Document]
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await render(documents)
    }
}
