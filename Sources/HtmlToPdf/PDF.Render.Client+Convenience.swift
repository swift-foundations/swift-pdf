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
    public func htmls(
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
}
