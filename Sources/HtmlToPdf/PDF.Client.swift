//
//  PDF.Client.swift
//  swift-html-to-pdf
//
//  Client interface for PDF rendering operations
//

import Dependencies
import DependenciesMacros
import Foundation

extension PDF {
    /// Client for rendering HTML to PDF
    ///
    /// This client exposes a single primitive operation: rendering documents to a stream.
    /// All convenience methods are provided as extensions that compose this primitive.
    ///
    /// ## Core Primitive
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let documents = [
    ///     PDF.Document(htmlString: html1, destination: url1),
    ///     PDF.Document(htmlString: html2, destination: url2)
    /// ]
    ///
    /// for try await result in try await pdf.render(documents) {
    ///     print("Generated \(result.url) in \(result.duration)")
    /// }
    /// ```
    ///
    /// ## Convenience Methods
    ///
    /// For common use cases, use the convenience extensions:
    ///
    /// ```swift
    /// // Single document
    /// let url = try await pdf.render(html, to: fileURL)
    ///
    /// // Batch with collected results
    /// let urls = try await pdf.renderSync(documents)
    /// ```
    public struct Client: Sendable {

        // MARK: - Core Primitive

        /// Render documents to PDF files, yielding results as they complete
        ///
        /// This is the single primitive operation. All other methods are built on top of this.
        ///
        /// - Parameter documents: Documents to render
        /// - Returns: Stream of results as PDFs are generated
        /// - Throws: Rendering errors
        @DependencyEndpoint
        public var render: @Sendable (
            _ documents: [Document]
        ) async throws -> AsyncThrowingStream<Result, Error>

        // MARK: - Platform Capabilities

        /// Get capabilities of current implementation
        @DependencyEndpoint
        public var capabilities: @Sendable () -> Capabilities = { .mock }

        public init(
            render: @escaping @Sendable ([Document]) async throws -> AsyncThrowingStream<Result, Error>,
            capabilities: @escaping @Sendable () -> Capabilities
        ) {
            self.render = render
            self.capabilities = capabilities
        }
    }
}

// MARK: - Dependency Registration

extension PDF.Client: TestDependencyKey {
    public static let testValue = PDF.Client(
        render: unimplemented("PDF.Client.render"),
        capabilities: unimplemented("PDF.Client.capabilities")
    )
}

// Note: PDF.Client is now accessed via \.pdf.client
// The PDF struct (in PDF.swift) handles the main dependency registration
