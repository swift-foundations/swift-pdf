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
        to destination: URL
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
    ///   - html: HTML strings to render (any sequence)
    ///   - directory: Directory to save PDFs in
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func html(
        _ html: some Sequence<String>,
        to directory: URL
    ) async throws -> AsyncThrowingStream<PDF.Render.Result, Error> {
        @Dependency(\.pdf.render.configuration) var config

        let documents = html.enumerated().map { index, html in
            let filename = config.namingStrategy.filename(for: index)
            return PDF.Document(htmlString: html, title: filename, in: directory)
        }

        return try await self.documents(documents)
    }

    // MARK: - Data Conveniences

    /// Render multiple HTML strings to PDF data, yielding results as they complete
    ///
    /// Convenience wrapper that renders to temporary files and streams back Data.
    /// The temporary directory is cleaned up after all PDFs are generated.
    ///
    /// - Parameter htmlStrings: HTML strings to render (any sequence)
    /// - Returns: Stream of PDF data as each completes
    /// - Throws: Rendering errors
    public func data(
        _ htmlStrings: some Sequence<String>
    ) async throws -> AsyncThrowingStream<Data, Error> {
        let tempDir = URL.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        // Materialize sequence and create documents before Task to avoid Sendable issues
        let documents = htmlStrings.enumerated().map { index, html in
            PDF.Document(
                htmlString: html,
                destination: tempDir.appendingPathComponent("\(index).pdf")
            )
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Ensure cleanup happens on both success and error paths
                    defer {
                        try? FileManager.default.removeItem(at: tempDir)
                    }

                    // Create temp directory
                    try FileManager.default.createDirectory(
                        at: tempDir,
                        withIntermediateDirectories: true
                    )

                    // Render and stream back Data
                    for try await result in try await self.documents(documents) {
                        let data = try Data(contentsOf: result.url)
                        continuation.yield(data)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Render a single HTML string to PDF data
    ///
    /// Convenience wrapper around the batch `data()` method.
    ///
    /// - Parameter htmlString: HTML content to render
    /// - Returns: PDF data
    /// - Throws: Rendering errors
    public func data(_ htmlString: String) async throws -> Data {
        for try await data in try await self.data([htmlString]) {
            return data
        }
        throw PrintingError.noResultProduced
    }
}
