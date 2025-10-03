//
//  PDF+Convenience.swift
//  swift-html-to-pdf
//
//  Top-level convenience methods for HTML protocol integration
//

import Dependencies
import Foundation
import PointFreeHTML

extension PDF {

    // MARK: - HTML Protocol Integration

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
    public func render(
        html: some HTML,
        to destination: URL
    ) async throws -> URL {
        let document = PDF.Document(html: html, destination: destination)
        return try await render.document(document)
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
    public func render(
        html: some HTML
    ) async throws -> Data {
        let htmlString = String(decoding: html.render(), as: UTF8.self)
        return try await render.data(htmlString)
    }

}
