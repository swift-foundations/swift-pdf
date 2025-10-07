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
    /// ## Error Handling
    ///
    /// **Important**: The `documents()` method uses **fail-fast semantics** - the first error
    /// stops the entire batch and throws immediately. Any PDFs generated before the error
    /// remain on disk.
    ///
    /// ```swift
    /// do {
    ///     for try await result in try await renderClient.documents(documents) {
    ///         print("✓ \(result.url)")
    ///     }
    /// } catch let error as PrintingError {
    ///     switch error {
    ///     case .webViewAcquisitionTimeout(let timeout):
    ///         // Pool exhausted - reduce concurrency or increase timeout
    ///         print("Increase webViewAcquisitionTimeout beyond \(timeout)s")
    ///
    ///     case .pdfGenerationFailed(let underlying):
    ///         // PDF generation error - check HTML validity
    ///         print("HTML rendering failed: \(underlying)")
    ///
    ///     case .invalidFilePath(let url, _):
    ///         // File system error - check permissions
    ///         print("Cannot write to \(url)")
    ///
    ///     default:
    ///         print("Error: \(error.localizedDescription)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Streaming vs Collection
    ///
    /// Stream results for real-time progress tracking (recommended):
    /// ```swift
    /// var completed = 0
    /// for try await result in try await renderClient.documents(docs) {
    ///     completed += 1
    ///     updateProgress(completed, total: docs.count)
    /// }
    /// ```
    ///
    /// Collect all results for post-processing:
    /// ```swift
    /// let results = try await Array(renderClient.documents(docs))
    /// let totalDuration = results.map(\.duration).reduce(.zero, +)
    /// let averagePerPDF = totalDuration / results.count
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// All rendering operations are thread-safe and can be called from any context:
    /// - Methods can be called from any actor or thread
    /// - Execution automatically hops to MainActor for WebView operations (platform requirement)
    /// - Safe for concurrent calls from multiple tasks
    /// - Results are yielded in completion order, not input order
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
        ) async throws -> AsyncThrowingStream<PDF.Render.Result, Error>
    }
}
