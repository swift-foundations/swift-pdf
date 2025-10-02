//
//  PDF.Render.Client+Convenience.swift
//  swift-html-to-pdf
//
//  Convenience methods built on the core primitives
//

import Foundation
import Dependencies

// MARK: - Batch Convenience

extension PDF.Render.Client {

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

        let stream = try await self.documents(documents)
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
        @Dependency(\.pdf.render.configuration) var config

        let documents = htmls.enumerated().map { index, html in
            let filename = config.namingStrategy.filename(for: index)
            return PDF.Document(htmlString: html, title: filename, in: directory)
        }

        return try await self.documents(documents)
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
        @Dependency(\.pdf.render.configuration) var config

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
