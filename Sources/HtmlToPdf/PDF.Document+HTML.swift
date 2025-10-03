//
//  PDF.Document+HTML.swift
//  swift-html-to-pdf
//
//  swift-html / PointFreeHTML integration
//

import HtmlToPdfLive
import PointFreeHTML

extension PDF.Document {
    /// Create a document from any HTML-conforming type (swift-html integration)
    ///
    /// This initializer provides seamless integration with swift-html and PointFreeHTML.
    /// Any type conforming to the `HTML` protocol can be passed directly.
    ///
    /// Example:
    /// ```swift
    /// import HtmlToPdf
    /// import HTML
    ///
    /// let page = html {
    ///     body {
    ///         h1 { "Type-safe PDF" }
    ///         p { "Generated from swift-html" }
    ///     }
    /// }
    ///
    /// let doc = PDF.Document(html: page, destination: outputURL)
    /// try await PDF.render.client.render(doc)
    /// ```
    public init(html: some HTML, destination: URL) {
        self.init(htmlBytes: html.render(), destination: destination)
    }

    /// Create a document from HTML with a title-based filename
    ///
    /// The PDF will be saved in the specified directory with the title as filename.
    /// Special characters in the title are automatically sanitized.
    ///
    /// Example:
    /// ```swift
    /// let page = html { body { h1 { "My Report" } } }
    /// let doc = PDF.Document(html: page, title: "Q4 Report", in: outputDir)
    /// // Saves to: outputDir/Q4 Report.pdf
    /// ```
    public init(html: some HTML, title: String, in directory: URL) {
        self.init(htmlBytes: html.render(), title: title, in: directory)
    }
}
