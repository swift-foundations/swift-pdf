//
//  PDF.Render.swift
//  swift-html-to-pdf
//
//  Rendering capability within the PDF domain
//

import Dependencies
import Foundation

extension PDF {
    /// Rendering capability containing client and configuration.
    ///
    /// This follows the domain-first pattern where the business capability (Render)
    /// is primary, with technical implementations (Client, Configuration) as nested types.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// // Render documents
    /// try await pdf.render.client.documents(documents)
    ///
    /// // Configure rendering
    /// try await withDependencies {
    ///     $0.pdf.render.configuration.paperSize = .letter
    /// } operation: {
    ///     try await pdf.render.client.documents(documents)
    /// }
    /// ```
    public struct Render: Sendable {
        /// Client for rendering operations
        public var client: PDF.Render.Client

        /// Configuration for PDF rendering
        public var configuration: PDF.Configuration

        public init(
            client: PDF.Render.Client,
            configuration: PDF.Configuration
        ) {
            self.client = client
            self.configuration = configuration
        }
    }
}
