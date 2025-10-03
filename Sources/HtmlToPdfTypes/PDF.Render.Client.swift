//
//  PDF.Render.Client.swift
//  swift-html-to-pdf
//
//  Client interface for PDF rendering operations
//

import Dependencies
import DependenciesMacros
import Foundation

extension PDF.Render {
    /// Client for rendering HTML to PDF
    ///
    /// This client exposes core rendering operations following the domain-first pattern.
    /// All operations are defined as dependency endpoints for testability.
    ///
    /// ## Basic Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf.render.client) var renderClient
    ///
    /// let documents = [
    ///     PDF.Document(htmlString: html1, destination: url1),
    ///     PDF.Document(htmlString: html2, destination: url2)
    /// ]
    ///
    /// for try await result in try await renderClient.documents(documents) {
    ///     print("Generated \(result.url) in \(result.duration)")
    /// }
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// This type is `@unchecked Sendable` because:
    /// - All stored properties are `@Sendable` closures injected via `@DependencyClient` macro
    /// - No mutable state is stored in the struct itself
    /// - All operations route through the dependency system which handles actor isolation
    /// - The underlying platform implementations (macOS/iOS) properly isolate WebKit operations on MainActor
    @DependencyClient
    public struct Client: @unchecked Sendable {

        // MARK: - Primitive Operations

        /// Render documents to PDF files, yielding results as they complete
        ///
        /// This is the sole primitive rendering operation. Documents are rendered concurrently
        /// based on configuration settings, with results streamed as each completes.
        ///
        /// **Fail-Fast Behavior**: Throws on first error, stopping batch processing.
        ///
        /// All other rendering methods are composed from this primitive.
        ///
        /// - Parameter documents: Documents to render (any sequence)
        /// - Returns: Stream of results as PDFs are generated
        /// - Throws: Rendering errors (stops entire batch)
        @DependencyEndpoint
        public var documents: @Sendable (
            _ documents: any Sequence<PDF.Document>
        ) async throws -> AsyncThrowingStream<PDF.Result, Error>

        // MARK: - Platform Capabilities

        /// Get capabilities of current implementation
        @DependencyEndpoint
        public var capabilities: @Sendable () -> PDF.Capabilities = { .mock }
    }
}
