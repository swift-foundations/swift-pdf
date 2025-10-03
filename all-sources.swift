// ========================================
// File: Sources/HtmlToPdf/PDF+Convenience.swift
// ========================================

//
//  PDF+Convenience.swift
//  swift-html-to-pdf
//
//  Top-level convenience methods for HTML protocol integration
//

import Dependencies
import Foundation

#if HTML
import HTML

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
#endif


// ========================================
// File: Sources/HtmlToPdf/PDF.Document+HTML.swift
// ========================================

//
//  PDF.Document+HTML.swift
//  swift-html-to-pdf
//
//  swift-html integration
//

import HtmlToPdfLive

#if HTML
import HTML

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
#endif


// ========================================
// File: Sources/HtmlToPdf/exports.swift
// ========================================

@_exported import HtmlToPdfLive

#if HTML
@_exported import HTML
#endif


// ========================================
// File: Sources/HtmlToPdfLive/DirectoryCache.swift
// ========================================

//
//  DirectoryCache.swift
//  swift-html-to-pdf
//
//  Thread-safe directory validation cache
//

import Dependencies
import Foundation
import IssueReporting

/// Thread-safe cache for directory validation
///
/// Reduces redundant file system checks by caching validated directory paths.
/// Uses lock-based synchronization to protect the validated set.
///
/// Thread Safety: Uses `LockIsolated` to protect the validated set with an NSRecursiveLock.
/// All mutations to the set are performed within `withLock` closures, ensuring exclusive access.
final class DirectoryCache: Sendable {
    private let validated = LockIsolated(Set<String>())

    func ensureDirectory(
        at url: URL,
        createIfNeeded: Bool
    ) throws {
        let path = url.path

        // Fast path: check cache with lock
        let isValidated = validated.withValue { $0.contains(path) }

        if isValidated {
            return
        }

        // Slow path: check and possibly create (file I/O)
        if createIfNeeded {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
            _ = validated.withValue { $0.insert(path) }
        } else {
            // Validate directory exists when createDirectories is false
            var isDirectory: ObjCBool = false
            if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) || !isDirectory.boolValue {
                throw PrintingError.invalidFilePath(
                    url,
                    underlyingError: NSError(
                        domain: NSCocoaErrorDomain,
                        code: NSFileNoSuchFileError,
                        userInfo: [NSLocalizedDescriptionKey: "Directory does not exist: \(path)"]
                    )
                )
            }
            _ = validated.withValue { $0.insert(path) }
        }
    }

    func clear() {
        validated.withValue { $0.removeAll() }
    }
}

/// Shared directory cache for the rendering session
let directoryCache = DirectoryCache()


// ========================================
// File: Sources/HtmlToPdfLive/PDF+Convenience.swift
// ========================================

//
//  PDF+Convenience.swift
//  swift-html-to-pdf
//
//  Top-level convenience methods for common operations (string-based)
//

import Dependencies
import Foundation

extension PDF {

    // MARK: - Render Operations (String-based)

    /// Render HTML string to PDF file
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let html = "<html><body><h1>Hello</h1></body></html>"
    /// try await pdf.render(html: html, to: fileURL)
    /// ```
    ///
    /// - Parameters:
    ///   - html: HTML content to render
    ///   - destination: File URL for the PDF
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    public func render(
        html: String,
        to destination: URL
    ) async throws -> URL {
        try await render.html(html, to: destination)
    }

    /// Render a document to PDF
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let document = PDF.Document(htmlString: html, destination: fileURL)
    /// try await pdf.render(document: document)
    /// ```
    ///
    /// - Parameter document: Document to render
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    public func render(
        document: PDF.Document
    ) async throws -> URL {
        try await render.document(document)
    }

    /// Render HTML string to PDF data (in-memory)
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let html = "<html><body><h1>Hello</h1></body></html>"
    /// let pdfData = try await pdf.render(html: html)
    /// ```
    ///
    /// - Parameter html: HTML content to render
    /// - Returns: PDF data
    /// - Throws: Rendering errors
    public func render(
        html: String
    ) async throws -> Data {
        try await render.data(html)
    }

    // MARK: - Batch Operations

    /// Render multiple HTML strings to a directory
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let htmls = [
    ///     "<html><body><h1>Doc 1</h1></body></html>",
    ///     "<html><body><h1>Doc 2</h1></body></html>"
    /// ]
    ///
    /// for try await result in try await pdf.render(htmls: htmls, to: directory) {
    ///     print("Generated \(result.url.lastPathComponent)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - htmls: HTML strings to render
    ///   - directory: Directory to save PDFs in
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func render(
        htmls: some Sequence<String>,
        to directory: URL
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await render.html(htmls, to: directory)
    }

    /// Render multiple documents to PDFs
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let documents = [
    ///     PDF.Document(htmlString: html1, destination: url1),
    ///     PDF.Document(htmlString: html2, destination: url2)
    /// ]
    ///
    /// for try await result in try await pdf.render(documents: documents) {
    ///     print("Generated \(result.url.lastPathComponent)")
    /// }
    /// ```
    ///
    /// - Parameter documents: Documents to render
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func render(
        documents: some Sequence<PDF.Document>
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await render.documents(documents)
    }

    // MARK: - Base URL Configuration

    /// Configure a base URL for resolving relative resources in HTML
    ///
    /// Returns a PDF instance that will use the specified base URL when rendering.
    /// This allows chaining: `pdf.withBaseURL(...).render(...)`
    ///
    /// - Parameter baseURL: The base URL to use for resolving relative URLs
    /// - Returns: A PDF instance configured with the base URL
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Dependency(\.pdf) var pdf
    ///
    /// let html = #"<img src="logo.png">"#
    /// let assetsURL = URL(fileURLWithPath: "/path/to/assets")
    ///
    /// try await pdf
    ///     .withBaseURL(assetsURL)
    ///     .render(html: html, to: output)
    /// // Image will load from /path/to/assets/logo.png
    /// ```
    public func withBaseURL(_ baseURL: URL?) -> PDF {
        @Dependency(\.pdf) var currentPDF

        var modified = currentPDF
        modified.render.configuration.baseURL = baseURL
        return modified
    }

}


// ========================================
// File: Sources/HtmlToPdfLive/PDF+DependencyKey.swift
// ========================================

//
//  PDF+DependencyKey.swift
//  swift-html-to-pdf
//
//  DependencyKey conformances for live implementations
//

import Dependencies
import HtmlToPdfTypes

extension PDF: DependencyKey {
    public static let liveValue = PDF(
        render: .liveValue
    )
}

extension PDF: TestDependencyKey {
    public static let testValue = PDF(
        render: .testValue
    )
}

extension DependencyValues {
    public var pdf: PDF {
        get { self[PDF.self] }
        set { self[PDF.self] = newValue }
    }
}


// ========================================
// File: Sources/HtmlToPdfLive/PDF.Render+Convenience.swift
// ========================================

//
//  PDF.Render+Convenience.swift
//  swift-html-to-pdf
//
//  Convenience methods that forward to client
//

import Foundation

extension PDF.Render {

    // MARK: - Core Operations

    /// Render documents to PDF files, yielding results as they complete
    ///
    /// Convenience method that forwards to `client.documents()`.
    ///
    /// - Parameter documents: Documents to render (any sequence)
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func documents(
        _ documents: some Sequence<PDF.Document>
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await client.documents(documents)
    }

    /// Render a single document to PDF
    ///
    /// Convenience method that forwards to `client.document()`.
    ///
    /// - Parameter document: Document to render
    /// - Returns: URL of the generated PDF
    /// - Throws: Rendering errors
    public func document(
        _ document: PDF.Document
    ) async throws -> URL {
        try await client.document(document)
    }

    /// Render HTML string to PDF file
    ///
    /// Convenience method that forwards to `client.html()`.
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
        try await client.html(html, to: destination)
    }

    // MARK: - Batch Operations

    /// Render multiple HTML strings to a directory
    ///
    /// Convenience method that forwards to `client.html()`.
    /// Returns results as a stream for progressive processing.
    ///
    /// - Parameters:
    ///   - htmls: HTML strings to render (any sequence)
    ///   - directory: Directory to save PDFs in
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func html(
        _ htmls: some Sequence<String>,
        to directory: URL
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        try await client.html(htmls, to: directory)
    }

    // MARK: - Data Operations

    /// Render a single HTML string to PDF data
    ///
    /// Convenience method that forwards to `client.data()`.
    ///
    /// - Parameter htmlString: HTML content to render
    /// - Returns: PDF data
    /// - Throws: Rendering errors
    public func data(_ htmlString: String) async throws -> Data {
        try await client.data(htmlString)
    }

    /// Render multiple HTML strings to PDF data, yielding results as they complete
    ///
    /// Convenience method that forwards to `client.data()`.
    ///
    /// - Parameter htmlStrings: HTML strings to render (any sequence)
    /// - Returns: Stream of PDF data as each completes
    /// - Throws: Rendering errors
    public func data(
        _ htmlStrings: some Sequence<String>
    ) async throws -> AsyncThrowingStream<Data, Error> {
        try await client.data(htmlStrings)
    }
}


// ========================================
// File: Sources/HtmlToPdfLive/PDF.Render+TestDependencyKey.swift
// ========================================

//
//  PDF.Render+TestDependencyKey.swift
//  swift-html-to-pdf
//
//  Test dependency configuration for PDF.Render
//

import Dependencies

extension PDF.Render: TestDependencyKey {
    /// Test value that uses live client and configuration with isolated metrics
    ///
    /// Each test gets:
    /// - Real rendering client (.macOS/.iOS depending on platform) for integration testing
    /// - Real configuration (.default) for accurate behavior
    /// - Isolated metrics (.testValue) that bootstrap fresh backend per test
    ///
    /// This provides realistic testing while ensuring perfect metrics isolation.
    public static var testValue: Self {
        PDF.Render(
            client: liveClient,
            configuration: .default,
            metrics: .testValue
        )
    }

    private static var liveClient: PDF.Render.Client {
        #if os(macOS)
        return .macOS
        #elseif os(iOS)
        return .iOS
        #else
        return .testValue
        #endif
    }
}

extension PDF.Render.Client: TestDependencyKey {
    public static let testValue = PDF.Render.Client()
}


// ========================================
// File: Sources/HtmlToPdfLive/PDF.Render.Client+Convenience.swift
// ========================================

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
    ///   - htmls: HTML strings to render (any sequence)
    ///   - directory: Directory to save PDFs in
    /// - Returns: Stream of results as PDFs are generated
    /// - Throws: Rendering errors
    public func html(
        _ htmls: some Sequence<String>,
        to directory: URL
    ) async throws -> AsyncThrowingStream<PDF.Result, Error> {
        @Dependency(\.pdf.render.configuration) var config

        let documents = htmls.enumerated().map { index, html in
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


// ========================================
// File: Sources/HtmlToPdfLive/PDF.Render.Client+iOS.swift
// ========================================

//
//  PDF.Render.Client+iOS.swift
//  swift-html-to-pdf
//
//  iOS-specific implementation using UIPrintPageRenderer
//

#if canImport(UIKit)
import Dependencies
import DependenciesMacros
import Foundation
import LoggingExtras
import PDFKit
import UIKit
import WebKit

extension PDF.Render: DependencyKey {
    public static let liveValue = PDF.Render(
        client: .iOS,
        configuration: .default,
        metrics: .liveValue
    )
}

extension PDF.Render.Client: DependencyKey {
    public static let liveValue: Self = .iOS
}

extension PDF.Render.Client {
    /// iOS-specific implementation using UIPrintPageRenderer
    public static let iOS = PDF.Render.Client(
        documents: { documents in
            @Dependency(\.pdf.render.configuration) var config

            // Validate configuration against platform limits
            try validateConfiguration(config)

            return try await renderDocumentsInternal(documents, config: config)
        }
    )
}

// MARK: - Configuration Validation

/// Validate configuration against platform limits
private func validateConfiguration(_ config: PDF.Configuration) throws {
    let requestedConcurrency = config.concurrency.resolved

    // Check if requested concurrency exceeds platform maximum
    if requestedConcurrency > PDF.PlatformConcurrencyLimit.iOS {
        throw PrintingError.capabilityUnavailable(
            capability: "concurrency=\(requestedConcurrency)",
            platform: "iOS",
            reason: "Platform maximum is \(PDF.PlatformConcurrencyLimit.iOS). Requested \(requestedConcurrency) concurrent operations."
        )
    }
}

// MARK: - Internal Implementation

@MainActor
private func renderToDataWithFormatter(
    _ printFormatter: UIPrintFormatter,
    config: PDF.Configuration
) async throws -> Data {
    let renderer = UIPrintPageRenderer()
    renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)

    let paperRect = CGRect(origin: .zero, size: config.paperSize)
    let printableRect = CGRect(
        x: config.margins.left,
        y: config.margins.top,
        width: config.paperSize.width - config.margins.left - config.margins.right,
        height: config.paperSize.height - config.margins.top - config.margins.bottom
    )

    renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
    renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

    let pdfData = NSMutableData()
    UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
    renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))

    let bounds = UIGraphicsGetPDFContextBounds()

    (0..<renderer.numberOfPages).forEach { index in
        UIGraphicsBeginPDFPage()
        renderer.drawPage(at: index, in: bounds)
    }

    UIGraphicsEndPDFContext()

    return pdfData as Data
}

@MainActor
extension PDF.Document {
    func renderInternal(config: PDF.Configuration) async throws -> URL {
        let parentDirectory = self.destination.deletingLastPathComponent()

        // Directory validation with thread-safe cache (shared across platforms)
        try directoryCache.ensureDirectory(
            at: parentDirectory,
            createIfNeeded: config.createDirectories
        )

        // Check if HTML contains images by searching for <img tag in bytes
        // Use WebView for images (proper rendering), PrintFormatter for text-only (faster)
        if self.html.containsImageTag() {
            return try await renderWithWebView(config: config)
        } else {
            return try await renderWithPrintFormatter(config: config)
        }
    }

    @MainActor
    private func renderWithPrintFormatter(config: PDF.Configuration) async throws -> URL {
        // Convert bytes to String for UIMarkupTextPrintFormatter (only accepts String)
        let htmlString = String(decoding: self.html, as: UTF8.self)
        let printFormatter = UIMarkupTextPrintFormatter(markupText: htmlString)
        let data = try await renderToDataWithFormatter(printFormatter, config: config)
        try data.write(to: self.destination)
        return self.destination
    }

    @MainActor
    private func renderWithWebView(config: PDF.Configuration) async throws -> URL {
        @Dependency(\.webViewPool) var webViewPool

        let pool = try await webViewPool.pool

        // Track pool utilization
        await ActiveOperationsTracker.shared.increment()
        defer { Task { await ActiveOperationsTracker.shared.decrement() } }

        return try await pool.withResource(
            timeout: .seconds(config.webViewAcquisitionTimeout.components.seconds)
        ) { @Sendable @MainActor resource in
            let webView = resource.webView
            let renderer = DocumentWKRenderer(
                document: self,
                configuration: config
            )

            try await renderer.render(using: webView, documentTimeout: config.documentTimeout)
            return self.destination
        }
    }
}

private func renderDocumentsInternal(
    _ documents: some Sequence<PDF.Document>,
    config: PDF.Configuration
) async throws -> AsyncThrowingStream<PDF.Result, Error> {
    // Materialize sequence for indexing and count operations (before Task to avoid Sendable issues)
    let documentsArray = Array(documents)

    return AsyncThrowingStream<PDF.Result, Error> { continuation in
        Task { @MainActor in
            var completedCount = 0
            do {
                @Dependency(\.pdf.render.metrics) var metrics

                let maxConcurrent = config.concurrency.resolved

                try await withThrowingTaskGroup(of: (Int, URL, Int, [CGSize], PDF.PaginationMode, Duration).self) { taskGroup in
                    for (index, document) in documentsArray.prefix(maxConcurrent).enumerated() {
                        taskGroup.addTask {
                            let start = ContinuousClock.now
                            let url = try await document.renderInternal(config: config)
                            let duration = ContinuousClock.now - start

                            // Extract actual page count and dimensions from generated PDF
                            let (pageCount, dimensions) = extractPageInfo(from: url, fallbackSize: config.paperSize)
                            let mode = config.paginationMode
                            return (index, url, pageCount, dimensions, mode, duration)
                        }
                    }

                    var nextIndex = maxConcurrent

                    for try await (index, url, pageCount, dimensions, mode, duration) in taskGroup {
                        completedCount += 1

                        let result = PDF.Result(
                            url: url,
                            index: index,
                            duration: duration,
                            paginationMode: mode,
                            pageCount: pageCount,
                            pageDimensions: dimensions
                        )

                        // Record metrics for successful PDF generation
                        metrics.recordSuccess(duration: duration, mode: mode)

                        continuation.yield(result)

                        if nextIndex < documentsArray.count {
                            let document = documentsArray[nextIndex]
                            let capturedIndex = nextIndex
                            nextIndex += 1

                            taskGroup.addTask {
                                let start = ContinuousClock.now
                                let url = try await document.renderInternal(config: config)
                                let duration = ContinuousClock.now - start

                                // Extract actual page count and dimensions from generated PDF
                                let (pageCount, dimensions) = extractPageInfo(from: url, fallbackSize: config.paperSize)
                                let mode = config.paginationMode
                                return (capturedIndex, url, pageCount, dimensions, mode, duration)
                            }
                        }
                    }
                }
                continuation.finish()

                // Clear directory cache after batch completes
                directoryCache.clear()
            } catch {
                @Dependency(\.logger) var logger
                @Dependency(\.pdf.render.metrics) var metrics

                // Record metrics for failed PDF generation
                let printingError = error as? PrintingError
                metrics.recordFailure(error: printingError)

                logger.error("Batch rendering failed", metadata: [
                    "completed_count": "\(completedCount)",
                    "total_count": "\(documentsArray.count)",
                    "error": "\(error)",
                    "error_type": "\(type(of: error))"
                ])
                continuation.finish(throwing: error)

                // Clear directory cache on error as well
                directoryCache.clear()
            }
        }
    }
}

/// Extract page count and dimensions from PDF file (thread-safe, can run off main actor)
private func extractPageInfo(from url: URL, fallbackSize: CGSize) -> (pageCount: Int, dimensions: [CGSize]) {
    guard let pdfDoc = PDFDocument(url: url) else {
        return (1, [fallbackSize])
    }

    let pageCount = pdfDoc.pageCount
    let dimensions = (0..<pageCount).compactMap { index -> CGSize? in
        pdfDoc.page(at: index)?.bounds(for: .mediaBox).size
    }

    // Fallback if no pages found
    if dimensions.isEmpty {
        return (1, [fallbackSize])
    }

    return (pageCount, dimensions)
}

// MARK: - WebView Renderer for Images

@MainActor
private class DocumentWKRenderer: NSObject, WKNavigationDelegate {
    private var document: PDF.Document
    private var configuration: PDF.Configuration

    private var continuation: CheckedContinuation<Void, Error>?
    private weak var webView: WKWebView?
    private var timeoutTask: Task<Void, Error>?

    init(document: PDF.Document, configuration: PDF.Configuration) {
        self.document = document
        self.configuration = configuration
        super.init()
    }

    deinit {
        timeoutTask?.cancel()

        if let continuation = continuation {
            self.continuation = nil
            continuation.resume(throwing: CancellationError())
        }
    }

    func render(using webView: WKWebView, documentTimeout: Duration?) async throws {
        webView.navigationDelegate = self

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.webView = webView

            // Perform CSS injection asynchronously (may use cache, matching macOS)
            Task {
                let marginCSS = generateMarginCSS(self.configuration)
                let htmlToLoad = await self.document.html.injectingCSS(marginCSS)
                let htmlData = htmlToLoad.toData()

                webView.load(
                    htmlData,
                    mimeType: "text/html",
                    characterEncodingName: "UTF-8",
                    baseURL: self.configuration.baseURL ?? URL(string: "about:blank")!
                )
            }

            if let timeout = documentTimeout {
                timeoutTask = Task { [weak self] in
                    do {
                        try await Task.sleep(for: timeout)

                        guard let self = self,
                              let continuation = self.continuation else { return }

                        self.continuation = nil
                        let timeoutError = PrintingError.webViewRenderingTimeout(
                            timeoutSeconds: Double(timeout.components.seconds)
                        )
                        continuation.resume(throwing: timeoutError)
                    } catch {
                        if !(error is CancellationError) {
                            @Dependency(\.logger) var logger
                            logger.error("Unexpected error in timeout task", metadata: [
                                "error": "\(error)",
                                "error_type": "\(type(of: error))"
                            ])
                        }
                    }
                }
            } else {
                timeoutTask = nil
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task {
            guard let continuation = self.continuation else { return }
            self.continuation = nil
            self.timeoutTask?.cancel()

            do {
                let printFormatter = webView.viewPrintFormatter()
                let data = try await renderToDataWithFormatter(printFormatter, config: configuration)
                try data.write(to: document.destination)
                continuation.resume(returning: ())
            } catch {
                continuation.resume(throwing: error)
            }

            webView.navigationDelegate = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        Task {
            guard let continuation = self.continuation else { return }
            self.continuation = nil
            self.timeoutTask?.cancel()

            continuation.resume(throwing: PrintingError.webViewNavigationFailed(underlyingError: error))
            webView.navigationDelegate = nil
        }
    }
}

// MARK: - CSS Generation

private func generateMarginCSS(_ config: PDF.Configuration) -> ContiguousArray<UInt8> {
    // Use pre-computed CSS from configuration to avoid repeated string interpolation
    return config.marginCSSBytes
}

// MARK: - Byte-level Content Detection

extension ContiguousArray where Element == UInt8 {
    /// Check if HTML bytes contain an <img tag (case-insensitive)
    func containsImageTag() -> Bool {
        // Search for "<img" in bytes (case-insensitive)
        let pattern = ContiguousArray("<img".utf8)
        return self.firstRange(of: pattern, options: .caseInsensitive) != nil
    }
}

#endif


// ========================================
// File: Sources/HtmlToPdfLive/PDF.Render.Client+macOS.swift
// ========================================

//
//  PDF.Render.Client+macOS.swift
//  swift-html-to-pdf
//
//  macOS-specific implementation using WKWebView
//

#if os(macOS)
import Dependencies
import DependenciesMacros
import Foundation
import WebKit
import ResourcePool
@preconcurrency import AppKit
import PDFKit
import LoggingExtras

extension PDF.Render: DependencyKey {
    public static let liveValue = PDF.Render(
        client: .macOS,
        configuration: .default,
        metrics: .liveValue
    )
}

// MARK: - Directory Cache
// DirectoryCache is now in DirectoryCache.swift (shared across platforms)

// MARK: - NSPrintInfo Cache

/// Pre-configured NSPrintInfo cache to avoid repeated setup overhead
///
/// Thread Safety: This type is `@unchecked Sendable` because:
/// - It is isolated to the MainActor, preventing concurrent access
/// - The cache dictionary is only accessed from the main actor
/// - NSPrintInfo copies are returned to prevent shared mutable state
@MainActor
private final class PrintInfoCache: @unchecked Sendable {
    private var cache: [String: NSPrintInfo] = [:]

    func get(for config: PDF.Configuration) -> NSPrintInfo {
        let key = cacheKey(for: config)

        if let cached = cache[key] {
            // Return a copy to avoid shared mutable state
            return cached.copy() as! NSPrintInfo
        }

        // Create and cache new print info
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.paperSize = config.paperSize
        printInfo.topMargin = config.margins.top
        printInfo.leftMargin = config.margins.left
        printInfo.bottomMargin = config.margins.bottom
        printInfo.rightMargin = config.margins.right
        printInfo.jobDisposition = .save

        cache[key] = printInfo
        return printInfo.copy() as! NSPrintInfo
    }

    private func cacheKey(for config: PDF.Configuration) -> String {
        // Create cache key from relevant print properties
        "\(config.paperSize.width)x\(config.paperSize.height)_\(config.margins.top)_\(config.margins.left)_\(config.margins.bottom)_\(config.margins.right)"
    }
}

/// Shared print info cache accessor
@MainActor
private func getPrintInfoCache() -> PrintInfoCache {
    struct Static {
        @MainActor
        static let cache: PrintInfoCache = {
            PrintInfoCache()
        }()
    }
    return Static.cache
}

// MARK: - Client Implementation

extension PDF.Render.Client {
    /// macOS-specific implementation using WKWebView and NSPrintOperation
    public static let macOS = PDF.Render.Client(
        documents: { documents in
            @Dependency(\.pdf.render.configuration) var config

            // Validate configuration against platform limits
            try validateConfiguration(config)

            return try await renderDocumentsInternal(documents, config: config)
        }
    )
}

// MARK: - Configuration Validation

/// Validate configuration against platform limits
private func validateConfiguration(_ config: PDF.Configuration) throws {
    let requestedConcurrency = config.concurrency.resolved

    // Check if requested concurrency exceeds platform maximum
    if requestedConcurrency > PDF.PlatformConcurrencyLimit.macOS {
        throw PrintingError.capabilityUnavailable(
            capability: "concurrency=\(requestedConcurrency)",
            platform: "macOS",
            reason: "Platform maximum is \(PDF.PlatformConcurrencyLimit.macOS). Requested \(requestedConcurrency) concurrent operations."
        )
    }
}

// MARK: - Internal Implementation

extension PDF.Document {
    @MainActor
    func renderInternal(config: PDF.Configuration) async throws -> (url: URL, pageCount: Int, dimensions: [CGSize], mode: PDF.PaginationMode) {
        @Dependency(\.webViewPool) var webViewPool
        let pool = try await webViewPool.pool
        return try await renderWithPool(pool, config: config)
    }

    func renderWithPool(
        _ pool: ResourcePool<WKWebViewResource>,
        config: PDF.Configuration
    ) async throws -> (url: URL, pageCount: Int, dimensions: [CGSize], mode: PDF.PaginationMode) {
        let parentDirectory = self.destination.deletingLastPathComponent()

        // Directory validation with synchronous lock-based cache (low overhead)
        try directoryCache.ensureDirectory(
            at: parentDirectory,
            createIfNeeded: config.createDirectories
        )

        let destination = self.destination
        let html = self.html

        // Track pool utilization
        await ActiveOperationsTracker.shared.increment()
        defer { Task { await ActiveOperationsTracker.shared.decrement() } }

        return try await pool.withResource(
            timeout: .seconds(config.webViewAcquisitionTimeout.components.seconds)
        ) { @Sendable resource in
            let document = PDF.Document(htmlBytes: html, destination: destination)
            let (pageCount, dimensions, mode) = try await document.renderWithWebView(
                resource.webView,
                config: config
            )
            return (destination, pageCount, dimensions, mode)
        }
    }

    @MainActor
    private func renderWithWebView(
        _ webView: WKWebView,
        config: PDF.Configuration
    ) async throws -> (pageCount: Int, dimensions: [CGSize], mode: PDF.PaginationMode) {
        let delegate = WebViewNavigationDelegate(
            outputURL: self.destination,
            configuration: config
        )

        webView.navigationDelegate = delegate

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Int, [CGSize], PDF.PaginationMode), Error>) in
            let handler = PageInfoContinuationHandler()

            let timeoutTask: Task<Void, Never>?
            if let timeout = config.documentTimeout {
                timeoutTask = Task {
                    try? await Task.sleep(for: timeout)
                    await handler.resumeIfNeeded(continuation, with: .failure(
                        PrintingError.documentTimeout(
                            documentURL: self.destination,
                            timeoutSeconds: Double(timeout.components.seconds)
                        )
                    ))
                }
            } else {
                timeoutTask = nil
            }

            let printDelegate = PrintDelegate(
                onFinished: { pageCount, dimensions, mode in
                    timeoutTask?.cancel()
                    Task {
                        await handler.resumeIfNeeded(continuation, with: .success((pageCount, dimensions, mode)))
                    }
                },
                onError: { error in
                    timeoutTask?.cancel()
                    Task {
                        await handler.resumeIfNeeded(continuation, with: .failure(error))
                    }
                }
            )
            delegate.printDelegate = printDelegate

            // Perform CSS injection asynchronously (may use cache)
            Task {
                let marginCSS = generateMarginCSS(config)
                let htmlToLoad = await self.html.injectingCSS(marginCSS)
                let htmlData = htmlToLoad.toData()

                webView.load(
                    htmlData,
                    mimeType: "text/html",
                    characterEncodingName: "UTF-8",
                    baseURL: config.baseURL ?? URL(string: "about:blank")!
                )
            }
        }
    }
}

private func renderDocumentsInternal(
    _ documents: some Sequence<PDF.Document>,
    config: PDF.Configuration
) async throws -> AsyncThrowingStream<PDF.Result, Error> {
    // Materialize sequence for indexing and count operations (before Task to avoid Sendable issues)
    let documentsArray = Array(documents)

    return AsyncThrowingStream<PDF.Result, Error> { continuation in
        Task {
            var completedCount = 0
            do {

                // Get the pool ONCE at the beginning, not for every document
                // Pool access doesn't require main actor
                @Dependency(\.webViewPool) var webViewPool
                @Dependency(\.pdf.render.metrics) var metrics
                let pool = try await webViewPool.pool

                let maxConcurrent = config.concurrency.resolved

                try await withThrowingTaskGroup(of: (Int, URL, Int, [CGSize], PDF.PaginationMode, Duration).self) { taskGroup in
                    for (index, document) in documentsArray.prefix(maxConcurrent).enumerated() {
                        taskGroup.addTask {
                            let start = ContinuousClock.now
                            // renderWithPool handles main actor isolation internally for WebView operations
                            let (url, pageCount, dimensions, mode) = try await document.renderWithPool(pool, config: config)
                            let duration = ContinuousClock.now - start
                            return (index, url, pageCount, dimensions, mode, duration)
                        }
                    }

                    var nextIndex = maxConcurrent

                    for try await (index, url, pageCount, dimensions, mode, duration) in taskGroup {
                        completedCount += 1

                        let result = PDF.Result(
                            url: url,
                            index: index,
                            duration: duration,
                            paginationMode: mode,
                            pageCount: pageCount,
                            pageDimensions: dimensions
                        )

                        // Record metrics for successful PDF generation
                        metrics.recordSuccess(duration: duration, mode: mode)

                        continuation.yield(result)

                        // Record PDF generation for batch replacement tracking
                        // This triggers pool refresh every 50K PDFs to prevent memory bloat
                        try? await webViewPool.recordPDFGenerated()

                        if nextIndex < documentsArray.count {
                            let document = documentsArray[nextIndex]
                            let capturedIndex = nextIndex
                            nextIndex += 1

                            taskGroup.addTask {
                                let start = ContinuousClock.now
                                let (url, pageCount, dimensions, mode) = try await document.renderWithPool(pool, config: config)
                                let duration = ContinuousClock.now - start
                                return (capturedIndex, url, pageCount, dimensions, mode, duration)
                            }
                        }
                    }
                }
                continuation.finish()

                // Clear directory cache after batch completes
                directoryCache.clear()
            } catch {
                @Dependency(\.logger) var logger
                @Dependency(\.pdf.render.metrics) var metrics

                // Record metrics for failed PDF generation
                let printingError = error as? PrintingError
                metrics.recordFailure(error: printingError)

                logger.error("Batch rendering failed", metadata: [
                    "completed_count": "\(completedCount)",
                    "total_count": "\(documentsArray.count)",
                    "error": "\(error)",
                    "error_type": "\(type(of: error))"
                ])
                continuation.finish(throwing: error)

                // Clear directory cache on error as well
                directoryCache.clear()
            }
        }
    }
}

private func generateMarginCSS(_ config: PDF.Configuration) -> ContiguousArray<UInt8> {
    // Margin handling differs based on pagination mode:
    // - Paginated mode: Margins handled by NSPrintInfo
    // - Continuous mode: Margins applied via CSS padding
    //
    // Since we don't know the mode yet (determined after loading),
    // we apply CSS padding and NSPrintInfo will override when used
    //
    // Use pre-computed CSS from configuration to avoid repeated string interpolation
    return config.marginCSSBytes
}

// MARK: - Supporting Classes (from existing implementation)

private actor ContinuationHandler {
    private var hasResumed = false

    func resumeIfNeeded(_ continuation: CheckedContinuation<Void, Error>, with result: Result<Void, Error>) {
        guard !hasResumed else { return }
        hasResumed = true

        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

private actor PageInfoContinuationHandler {
    private var hasResumed = false

    func resumeIfNeeded(
        _ continuation: CheckedContinuation<(Int, [CGSize], PDF.PaginationMode), Error>,
        with result: Result<(Int, [CGSize], PDF.PaginationMode), Error>
    ) {
        guard !hasResumed else { return }
        hasResumed = true

        switch result {
        case .success(let value):
            continuation.resume(returning: value)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

/// Extract page info from PDF data (thread-safe, can run off main actor)
private func extractPageInfoFromData(_ pdfData: Data) -> (pageCount: Int, dimensions: [CGSize]) {
    guard let pdfDoc = PDFDocument(data: pdfData) else {
        return (0, [])
    }

    let pageCount = pdfDoc.pageCount
    let dimensions = (0..<pageCount).compactMap { index -> CGSize? in
        pdfDoc.page(at: index)?.bounds(for: .mediaBox).size
    }

    return (pageCount, dimensions)
}

private class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private let outputURL: URL
    var printDelegate: PrintDelegate?
    private let configuration: PDF.Configuration

    init(
        outputURL: URL,
        configuration: PDF.Configuration
    ) {
        self.outputURL = outputURL
        self.configuration = configuration
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            do {
                let strategy = try await chooseRenderingStrategy(
                    webView: webView,
                    config: configuration
                )

                switch strategy {
                case .webView:
                    renderWithWebViewCreatePDF(webView, strategy: strategy)
                case .printOperation:
                    renderWithNSPrintOperation(webView, strategy: strategy)
                }
            } catch {
                printDelegate?.onError?(PrintingError.pdfGenerationFailed(underlyingError: error))
            }
        }
    }

    @MainActor
    private func chooseRenderingStrategy(
        webView: WKWebView,
        config: PDF.Configuration
    ) async throws -> PDF.InternalRenderingMethod {

        switch config.paginationMode {
        case .paginated:
            return .printOperation

        case .continuous:
            return .webView

        case .automatic(let heuristic):
            switch heuristic {
            case .contentLength(let threshold):
                // Measure content height
                let height = try await webView.evaluateJavaScript(
                    "document.documentElement.scrollHeight"
                ) as? CGFloat ?? 0

                let pageHeight = config.paperSize.height - (config.margins.top + config.margins.bottom)
                let estimatedPages = height / pageHeight

                return estimatedPages > threshold ? .printOperation : .webView

            case .htmlStructure:
                // Check for print CSS indicators
                let hasPrintCSS = try await webView.evaluateJavaScript(
                    "!!document.querySelector('style[media*=\"print\"]')"
                ) as? Bool ?? false

                let hasPageBreaks = try await webView.evaluateJavaScript(
                    "!!document.querySelector('[style*=\"page-break\"]')"
                ) as? Bool ?? false

                return (hasPrintCSS || hasPageBreaks) ? .printOperation : .webView

            case .preferSpeed:
                return .webView

            case .preferPrintReady:
                return .printOperation
            }
        }
    }

    private func renderWithWebViewCreatePDF(_ webView: WKWebView, strategy: PDF.InternalRenderingMethod) {
        // Fast approach using WKWebView.createPDF
        // Creates continuous single-page PDFs

        // Set frame to paper size for proper layout
        webView.frame = CGRect(origin: .zero, size: configuration.paperSize)

        let pdfConfig = WKPDFConfiguration()
        pdfConfig.rect = nil // Allow content to flow naturally

        webView.createPDF(configuration: pdfConfig) { [weak self] result in
            guard let self = self else { return }

            webView.navigationDelegate = nil

            switch result {
            case .success(let data):
                // Move file I/O and page extraction off main actor to reduce contention
                Task.detached(priority: .userInitiated) { [outputURL = self.outputURL, paginationMode = self.configuration.paginationMode] in
                    do {
                        // Atomic file write: write to temp file in same directory, then move
                        // This prevents partial PDFs if the task is cancelled mid-write
                        let parentDir = outputURL.deletingLastPathComponent()
                        let tempURL = parentDir
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension("pdf.tmp")

                        try data.write(to: tempURL)

                        // Atomic move (replaces existing file if present)
                        try FileManager.default.moveItem(at: tempURL, to: outputURL)

                        // Extract page info (PDFDocument is thread-safe)
                        let (pageCount, dimensions) = extractPageInfoFromData(data)

                        // Resume on main actor only for callback
                        await MainActor.run {
                            self.printDelegate?.onFinished(pageCount, dimensions, paginationMode)
                        }
                    } catch {
                        await MainActor.run {
                            self.printDelegate?.onError?(PrintingError.pdfGenerationFailed(underlyingError: error))
                                ?? self.printDelegate?.onFinished(0, [], paginationMode)
                        }
                    }
                }
            case .failure(let error):
                self.printDelegate?.onError?(PrintingError.pdfGenerationFailed(underlyingError: error))
                    ?? self.printDelegate?.onFinished(0, [], self.configuration.paginationMode)
            }
        }
    }

    private func renderWithNSPrintOperation(_ webView: WKWebView, strategy: PDF.InternalRenderingMethod) {
        // Slower but accurate approach using NSPrintOperation
        // Guarantees correct page dimensions for multi-page PDFs

        // Use cached print info to avoid repeated setup overhead
        let printInfo = getPrintInfoCache().get(for: configuration)

        // Set output URL (not cached since it's unique per document)
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = self.outputURL

        // Create print operation from WebView
        let printOperation = webView.printOperation(with: printInfo)

        // CRITICAL: Set frame to paper size - WebKit layouts based on this
        printOperation.view?.frame = NSRect(origin: .zero, size: configuration.paperSize)

        // Run WITHOUT showing UI
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false

        // Run asynchronously on a background thread to avoid blocking main thread
        // Note: NSPrintOperation.run() has @MainActor annotation but works on background queues
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak webView, paperSize = configuration.paperSize, mode = configuration.paginationMode] in
            guard let self = self else { return }

            // Run the print operation
            let success = printOperation.run()

            DispatchQueue.main.async {
                webView?.navigationDelegate = nil

                if success && FileManager.default.fileExists(atPath: self.outputURL.path) {
                    // Use paper size from configuration - all pages have same dimensions
                    // No need to read the PDF file!
                    let pageCount = printOperation.currentPage  // Total pages printed
                    let dimensions = Array(repeating: paperSize, count: max(1, pageCount))

                    self.printDelegate?.onFinished(pageCount, dimensions, mode)
                } else {
                    let error = NSError(domain: "PDFGeneration", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "PDF file was not created"])
                    self.printDelegate?.onError?(PrintingError.pdfGenerationFailed(underlyingError: error))
                        ?? self.printDelegate?.onFinished(0, [], mode)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        printDelegate?.onError?(PrintingError.webViewNavigationFailed(underlyingError: error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        printDelegate?.onError?(PrintingError.webViewLoadingFailed(underlyingError: error))
    }
}

/// Delegate for handling print operation completion and errors
///
/// Thread Safety: This type is `@unchecked Sendable` because:
/// - All stored properties are `@Sendable` closures
/// - The closures are immutable after initialization
/// - Callbacks are invoked from WebKit's navigation delegate which properly handles thread safety
private class PrintDelegate: @unchecked Sendable {
    var onFinished: @Sendable (Int, [CGSize], PDF.PaginationMode) -> Void
    var onError: (@Sendable (Error) -> Void)?

    init(
        onFinished: @Sendable @escaping (Int, [CGSize], PDF.PaginationMode) -> Void,
        onError: (@Sendable (Error) -> Void)? = nil
    ) {
        self.onFinished = onFinished
        self.onError = onError
    }
}

#endif


// ========================================
// File: Sources/HtmlToPdfLive/WKWebViewResource.swift
// ========================================

//
//  WKWebViewResource.swift
//  swift-html-to-pdf
//
//  Adapter for WKWebView to work with ResourcePool
//

#if canImport(WebKit)
import Foundation
import WebKit
import ResourcePool
import Dependencies
import LoggingExtras

/// WKWebView wrapper that conforms to PoolableResource
@MainActor
public final class WKWebViewResource: PoolableResource {
    public typealias Config = Void

    /// The underlying WKWebView
    public let webView: WKWebView

    private init(webView: WKWebView) {
        self.webView = webView
    }

    /// Create a new WKWebView resource
    @MainActor
    public static func create(config: Config) async throws -> WKWebViewResource {
        let webViewConfig = WKWebViewConfiguration()

        // Note: processPool defaults to a shared instance, no need to set it explicitly
        // (avoiding deprecated WKProcessPool APIs)

        // Disable GPU acceleration features we don't need for PDF
        webViewConfig.suppressesIncrementalRendering = true
        webViewConfig.preferences.setValue(false, forKey: "acceleratedDrawingEnabled")
        webViewConfig.preferences.setValue(false, forKey: "displayListDrawingEnabled")

        // Use non-persistent data store (correct for stateless PDF generation)
        webViewConfig.websiteDataStore = .nonPersistent()

        // Disable JavaScript for PDF rendering
        if #available(macOS 11.0, iOS 14.0, *) {
            webViewConfig.defaultWebpagePreferences.allowsContentJavaScript = false
        } else {
            webViewConfig.preferences.setValue(false, forKey: "javaScriptEnabled")
        }
        webViewConfig.preferences.javaScriptCanOpenWindowsAutomatically = false
        webViewConfig.preferences.minimumFontSize = 0

        // Disable fraud warning
        if #available(macOS 11.0, iOS 14.0, *) {
            webViewConfig.preferences.isFraudulentWebsiteWarningEnabled = false
        }

        // Suppress WebKit logging warnings
        webViewConfig.preferences.setValue(true, forKey: "logsPageMessagesToSystemConsoleEnabled")
        webViewConfig.preferences.setValue(false, forKey: "developerExtrasEnabled")

        #if os(iOS)
        webViewConfig.allowsInlineMediaPlayback = true
        webViewConfig.suppressesIncrementalRendering = true
        #endif

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)

        // Disable background drawing on macOS
        #if os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
        #endif

        return WKWebViewResource(webView: webView)
    }

    /// Validate that the resource is still usable
    @MainActor
    public func validate() async -> Bool {
        // Check if WebView is still responsive
        do {
            // Try a simple JavaScript evaluation to check responsiveness
            _ = try await webView.evaluateJavaScript("1 + 1")
            return true
        } catch {
            // WebView is unresponsive or in error state
            @Dependency(\.logger) var logger
            logger.warning("WebView validation failed, will be replaced", metadata: [
                "error": "\(error)",
                "error_type": "\(type(of: error))"
            ])
            return false
        }
    }

    /// Reset the resource for reuse
    @MainActor
    public func reset() async throws {
        // Stop any ongoing loads
        webView.stopLoading()

        // Clear navigation delegate
        webView.navigationDelegate = nil

        // Note: Expensive operations like loading blank HTML, clearing data stores,
        // or JavaScript validation caused 10x performance degradation.
        // Instead, rely on resource cycling (maxUsesBeforeCycling in ResourcePool)
        // and validate() to periodically replace unhealthy WebViews.
        // The stopLoading() and delegate clearing above is sufficient for cleanup.
    }
}

#endif

// ========================================
// File: Sources/HtmlToPdfLive/WebViewPoolClient-ResourcePool.swift
// ========================================

//
//  WebViewPoolClient-ResourcePool.swift
//  swift-html-to-pdf
//
//  WebViewPoolClient implementation using ResourcePool
//

#if canImport(WebKit)
import Foundation
import WebKit
import Dependencies
import LoggingExtras
import ResourcePool
import IssueReporting

/// Adaptive throughput optimizer that monitors performance and triggers optimizations
private actor AdaptiveThroughputOptimizer {
    struct MetricsWindow: Sendable {
        let timestamp: Date
        let pdfsCompleted: Int
        let throughput: Double // PDFs/sec
    }

    enum OptimizationAction {
        case triggerPoolReplacement
        case none
    }

    private var windows: [MetricsWindow] = []
    private let windowDuration: TimeInterval = 5.0
    private let maxWindows = 10 // Keep last 50 seconds of history
    private var windowStartTime: Date = Date()
    private var windowPDFCount: Int = 0
    private var absolutePeakThroughput: Double = 0.0 // Track peak across entire run

    /// Record a completed PDF and update metrics
    func recordPDF() -> OptimizationAction? {
        windowPDFCount += 1

        let now = Date()
        let elapsed = now.timeIntervalSince(windowStartTime)

        // Complete window if duration exceeded
        if elapsed >= windowDuration {
            let throughput = Double(windowPDFCount) / elapsed
            let window = MetricsWindow(
                timestamp: now,
                pdfsCompleted: windowPDFCount,
                throughput: throughput
            )

            windows.append(window)

            // Update absolute peak
            if throughput > absolutePeakThroughput {
                absolutePeakThroughput = throughput
            }

            // Update metrics gauge with current throughput
            @Dependency(\.pdf.render.metrics) var metrics
            metrics.updateThroughput(throughput)

            // Keep only recent windows
            if windows.count > maxWindows {
                windows.removeFirst()
            }

            // Reset window
            windowStartTime = now
            windowPDFCount = 0

            // Check if optimization needed
            return shouldOptimize()
        }

        return nil
    }

    /// Detect if throughput is degrading and optimization is needed
    private func shouldOptimize() -> OptimizationAction? {
        // Need at least 5 windows to establish reliable baseline (25 seconds of data)
        guard windows.count >= 5 else { return nil }

        // Get recent average (last 3 windows = 15 seconds)
        let recentWindows = Array(windows.suffix(3))
        let recentAverage = recentWindows.map(\.throughput).reduce(0, +) / Double(recentWindows.count)

        // Get peak from the last 5 windows (local peak within recent history)
        let localPeak = windows.suffix(5).map(\.throughput).max()!

        // Trigger if recent average drops >5% from local peak
        // This balances early detection with avoiding false positives
        // 5% degradation is significant enough to warrant pool replacement
        if localPeak > 1500 && recentAverage < localPeak * 0.95 {
            @Dependency(\.logger) var logger
            let degradationPercent = (1.0 - recentAverage/localPeak) * 100
            logger.warning("Adaptive pool replacement triggered due to performance degradation", metadata: [
                "recent_average_pdfs_sec": "\(Int(recentAverage))",
                "local_peak_pdfs_sec": "\(Int(localPeak))",
                "degradation_percent": "\(String(format: "%.1f", degradationPercent))"
            ])
            return .triggerPoolReplacement
        }

        return nil
    }

    /// Reset peak after pool replacement to allow new baseline
    func resetPeak() {
        absolutePeakThroughput = 0.0
        windows.removeAll()
        windowStartTime = Date()
        windowPDFCount = 0
    }

    /// Get current throughput statistics
    func getStats() -> (current: Double?, peak: Double?, windows: Int) {
        let currentThroughput = windows.last?.throughput
        let peakThroughput = windows.map(\.throughput).max()
        return (currentThroughput, peakThroughput, windows.count)
    }
}

/// Global shared pool actor to ensure only one pool exists across all consumers
/// Adds batch replacement capability to mitigate WebKit process-level memory leaks
/// Now includes adaptive throughput optimization
@globalActor
private actor WebViewPoolActor {
    static let shared = WebViewPoolActor()

    private var sharedPool: ResourcePool<WKWebViewResource>?
    private var totalPDFsGenerated: Int = 0
    private var poolProvider: (@Sendable () async throws -> ResourcePool<WKWebViewResource>)?
    private var isReplacing: Bool = false  // Prevent concurrent replacements
    private var adaptiveOptimizer: AdaptiveThroughputOptimizer?
    private var adaptiveOptimizationEnabled: Bool = false

    func getOrCreatePool(
        provider: @escaping @Sendable () async throws -> ResourcePool<WKWebViewResource>,
        adaptiveOptimization: Bool = false
    ) async throws -> ResourcePool<WKWebViewResource> {
        // Store provider for pool replacement
        if poolProvider == nil {
            poolProvider = provider
        }

        // Enable adaptive optimization if requested
        if adaptiveOptimization && adaptiveOptimizer == nil {
            adaptiveOptimizer = AdaptiveThroughputOptimizer()
            adaptiveOptimizationEnabled = true
            @Dependency(\.logger) var logger
            logger.debug("Adaptive throughput optimization enabled")
        }

        if let existing = sharedPool {
            return existing
        }

        let newPool = try await provider()
        sharedPool = newPool
        @Dependency(\.logger) var logger
        logger.info("WebView pool initialized")
        return newPool
    }

    /// Record PDF generation and trigger batch replacement if threshold reached
    func recordPDFGenerated() async throws {
        totalPDFsGenerated += 1

        // Adaptive optimization: monitor throughput and trigger early optimization
        if adaptiveOptimizationEnabled, let optimizer = adaptiveOptimizer {
            if let action = await optimizer.recordPDF() {
                switch action {
                case .triggerPoolReplacement:
                    // Adaptive optimizer detected degradation - trigger early replacement
                    if !isReplacing, let provider = poolProvider {
                        try await triggerPoolReplacement(provider: provider, reason: "adaptive optimization")
                    }
                case .none:
                    break
                }
            }
        }

        // Check if we've hit the batch replacement threshold (fallback/safety mechanism)
        // Use isReplacing flag to prevent race condition where multiple PDFs trigger replacement
        @Dependency(\.pdf.render.configuration) var configuration
        if let threshold = configuration.poolReplacementThreshold,
           totalPDFsGenerated >= threshold,
           !isReplacing,
           let provider = poolProvider {
            try await triggerPoolReplacement(provider: provider, reason: "threshold reached")
        }
    }

    /// Trigger pool replacement
    private func triggerPoolReplacement(
        provider: @Sendable () async throws -> ResourcePool<WKWebViewResource>,
        reason: String
    ) async throws {
        isReplacing = true
        let oldCount = totalPDFsGenerated
        let startTime = Date()
        @Dependency(\.logger) var logger
        @Dependency(\.pdf.render.metrics) var metrics

        logger.info("Pool replacement started", metadata: [
            "pdf_count": "\(oldCount)",
            "reason": "\(reason)"
        ])

        // Create new pool (warmup will happen in background)
        let newPool = try await provider()

        // Swap to new pool immediately
        // The old pool will be released when all current operations complete
        // Swift's ARC will handle cleanup automatically
        sharedPool = newPool
        totalPDFsGenerated = 0

        // Record pool replacement metric
        metrics.recordPoolReplacement()

        // Reset adaptive optimizer to establish new baseline
        if let optimizer = adaptiveOptimizer {
            await optimizer.resetPeak()
        }

        isReplacing = false

        let duration = Date().timeIntervalSince(startTime)
        logger.info("Pool replacement complete", metadata: [
            "duration_seconds": "\(String(format: "%.2f", duration))",
            "previous_pdf_count": "\(oldCount)"
        ])
    }
}

// MARK: - Active Operations Tracker

/// Tracks the number of currently active WebView operations for pool utilization metrics
actor ActiveOperationsTracker {
    private var activeCount: Int = 0
    static let shared = ActiveOperationsTracker()

    func increment() {
        activeCount += 1
        updateMetrics()
    }

    func decrement() {
        activeCount -= 1
        updateMetrics()
    }

    private func updateMetrics() {
        @Dependency(\.pdf.render.metrics) var metrics
        metrics.updatePoolUtilization(activeCount)
    }
}

/// Client for managing WebView pool using ResourcePool
public struct WebViewPoolClient: Sendable {
    /// Lazy-initialized resource pool provider
    private let poolProvider: @Sendable () async throws -> ResourcePool<WKWebViewResource>

    init(
        poolProvider: @escaping @Sendable () async throws -> ResourcePool<WKWebViewResource>
    ) {
        self.poolProvider = poolProvider
    }

    /// Get the pool, creating it if necessary (globally shared)
    private func getPool() async throws -> ResourcePool<WKWebViewResource> {
        // Read configuration dynamically at pool creation time (not client creation time)
        // This ensures withDependencies overrides are properly captured
        @Dependency(\.pdf.render.configuration) var configuration

        return try await WebViewPoolActor.shared.getOrCreatePool(
            provider: poolProvider,
            adaptiveOptimization: configuration.adaptiveThroughputOptimization
        )
    }

    /// The underlying resource pool (for direct access)
    public var pool: ResourcePool<WKWebViewResource> {
        get async throws {
            try await getPool()
        }
    }

    /// Record that a PDF was generated (triggers batch replacement if threshold reached)
    public func recordPDFGenerated() async throws {
        try await WebViewPoolActor.shared.recordPDFGenerated()
    }
}

extension WebViewPoolClient: DependencyKey {
    public static var liveValue: WebViewPoolClient {
        return WebViewPoolClient(
            poolProvider: { @MainActor in
                // Pool size comes from configuration via dependencies
                @Dependency(\.pdf.render.configuration) var configuration
                let poolSize = configuration.concurrency.resolved

                // Create pool with warmup
                // Batch replacement (every 30K PDFs) handles memory leaks at pool level
                return try await ResourcePool<WKWebViewResource>(
                    capacity: poolSize,
                    resourceConfig: (),
                    warmup: true,
                    maxUsesBeforeCycling: nil  // No per-resource cycling - using batch replacement
                )
            }
        )
    }

    public static var testValue: WebViewPoolClient {
        WebViewPoolClient(poolProvider: { @MainActor in
            return try await ResourcePool<WKWebViewResource>(
                capacity: 2,
                resourceConfig: (),
                warmup: false
            )
        })
    }
}

extension DependencyValues {
    public var webViewPool: WebViewPoolClient {
        get { self[WebViewPoolClient.self] }
        set { self[WebViewPoolClient.self] = newValue }
    }
}

#endif


// ========================================
// File: Sources/HtmlToPdfLive/exports.swift
// ========================================

@_exported import HtmlToPdfTypes
@_exported import Dependencies
@_exported import LoggingExtras
@_exported import ResourcePool


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.Capabilities.swift
// ========================================

//
//  PDF.Capabilities.swift
//  swift-html-to-pdf
//
//  Platform concurrency limits
//

import Foundation

extension PDF {
    /// Platform-specific maximum concurrent operations
    ///
    /// These constants define safe concurrency limits for each platform based on:
    /// - Memory constraints (especially iOS)
    /// - WebView process limits
    /// - Thermal management (mobile devices)
    ///
    /// Used for:
    /// - Validating requested concurrency doesn't exceed platform max
    /// - Capping automatic concurrency calculation
    public enum PlatformConcurrencyLimit {
        /// macOS maximum: 16 concurrent WebViews
        ///
        /// Based on:
        /// - Desktop-class memory
        /// - Active cooling
        /// - Background process support
        public static let macOS = 16

        /// iOS maximum: 8 concurrent WebViews
        ///
        /// Based on:
        /// - Mobile memory constraints
        /// - Thermal management
        /// - App suspension policies
        public static let iOS = 8

        /// Linux maximum: 32 concurrent operations
        ///
        /// Future support via wkhtmltopdf or headless Chrome
        public static let linux = 32

        /// Mock/test limit: 1 for deterministic testing
        public static let mock = 1
    }
}


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.ConcurrencyStrategy.swift
// ========================================

//
//  PDF.ConcurrencyStrategy.swift
//  swift-html-to-pdf
//
//  Strategy for determining concurrency during PDF rendering
//

import Foundation

// MARK: - Concurrency Strategy

extension PDF {
    /// Strategy for determining concurrency during PDF rendering
    ///
    /// Supports both explicit integer values and automatic calculation:
    /// ```swift
    /// // Integer literal
    /// configuration.concurrency = 4
    ///
    /// // Explicit fixed
    /// configuration.concurrency = .fixed(8)
    ///
    /// // Automatic (intelligent defaults based on hardware)
    /// configuration.concurrency = .automatic
    /// ```
    public struct ConcurrencyStrategy: Sendable, Equatable, ExpressibleByIntegerLiteral {
        internal let mode: Mode

        internal enum Mode: Sendable, Equatable {
            case fixed(Int)
            case automatic
        }

        // MARK: - Initialization

        private init(mode: Mode) {
            self.mode = mode
        }

        // MARK: - ExpressibleByIntegerLiteral

        public init(integerLiteral value: Int) {
            self.mode = .fixed(value)
        }

        // MARK: - Static Constructors

        /// Fixed concurrency - use exact number of concurrent operations
        public static func fixed(_ value: Int) -> Self {
            Self(mode: .fixed(value))
        }

        /// Automatic concurrency - calculate optimal value based on CPU count and available memory
        public static let automatic = Self(mode: .automatic)

        // MARK: - Internal

        /// Calculate optimal concurrency based on system hardware
        ///
        /// Empirical testing shows WebView memory usage does NOT scale linearly:
        /// - 1 WebView: ~100 MB total (includes pool overhead)
        /// - 4 WebViews: ~37 MB total (GC cleanup)
        /// - 8 WebViews: ~38 MB total
        /// - 16 WebViews: ~32 MB total
        ///
        /// Memory actually DECREASES with higher concurrency due to efficient resource management.
        ///
        /// Adaptive throughput optimization testing (5000 PDFs sample) on 8-core M-series Mac:
        /// - 4 WebViews: 860 PDFs/sec
        /// - 8 WebViews: 928 PDFs/sec (1x CPU count)
        /// - 12 WebViews: 686 PDFs/sec
        /// - 16 WebViews: 771 PDFs/sec (2x CPU count)
        /// - 20 WebViews: 946 PDFs/sec
        /// - 24 WebViews: 1113 PDFs/sec (3x CPU count) ← OPTIMAL
        /// - 28 WebViews: 1086 PDFs/sec
        /// - 32 WebViews: 1057 PDFs/sec (4x CPU count)
        ///
        /// Peak throughput occurs at 3x CPU count due to WebView I/O waiting.
        internal static func calculateDefaultConcurrency() -> Int {
            let cpuCount = ProcessInfo.processInfo.activeProcessorCount

            #if canImport(UIKit)
            // iOS: Still cap at 4 due to mobile constraints (battery, thermal, app suspension)
            let calculated = max(2, min(cpuCount, 4))
            // Cap at platform maximum
            return min(calculated, PDF.PlatformConcurrencyLimit.iOS)
            #else
            // macOS/Linux: Use 3x CPU count for optimal throughput
            // WebViews spend significant time in I/O, so oversubscription helps
            let calculated = max(2, cpuCount * 3)
            // Cap at platform maximum
            #if os(macOS)
            return min(calculated, PDF.PlatformConcurrencyLimit.macOS)
            #else
            return calculated
            #endif
            #endif
        }

        /// Resolve to concrete concurrency value
        public var resolved: Int {
            switch mode {
            case .fixed(let value):
                return max(1, value)
            case .automatic:
                return Self.calculateDefaultConcurrency()
            }
        }
    }
}


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.Configuration.swift
// ========================================

//
//  PDF.Configuration.swift
//  swift-html-to-pdf
//
//  Configuration for PDF rendering
//

import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Configuration

extension PDF {
    /// Configuration for PDF rendering
    ///
    /// Set configuration once via `withDependencies`:
    /// ```swift
    /// try await withDependencies {
    ///     $0.pdfConfiguration.paperSize = .letter
    ///     $0.pdfConfiguration.margins = .wide
    ///     $0.pdfConfiguration.concurrency = 16
    /// } operation: {
    ///     @Dependency(\.pdf) var pdf
    ///     try await pdf.render(html, to: url)
    /// }
    /// ```
    public struct Configuration: Sendable {

        // MARK: - Document Configuration

        /// Paper size for PDF documents
        public var paperSize: CGSize

        /// Margins applied to each page
        public var margins: EdgeInsets

        /// Base URL for resolving relative URLs in HTML
        public var baseURL: URL?

        /// How content should be paginated in the PDF
        public var paginationMode: PaginationMode

        // MARK: - Batch Configuration

        /// Concurrency strategy for PDF rendering
        ///
        /// Supports multiple forms:
        /// - Integer literal: `concurrency = 4`
        /// - Explicit: `concurrency = .fixed(8)`
        /// - Automatic: `concurrency = .automatic`
        ///
        /// Default is `.automatic`, which calculates optimal concurrency based on CPU count and available memory.
        public var concurrency: ConcurrencyStrategy = .automatic

        /// Enable adaptive throughput optimization
        ///
        /// When enabled, the system monitors throughput in real-time and automatically:
        /// - Detects performance degradation (>15% drop from peak)
        /// - Triggers early pool replacement to restore performance
        /// - Adapts to workload characteristics dynamically
        ///
        /// This is particularly beneficial for long-running batch operations (>10K PDFs).
        /// Default is `false` for backward compatibility.
        public var adaptiveThroughputOptimization: Bool = false

        /// Pool replacement threshold (number of PDFs before triggering pool replacement)
        ///
        /// The WebView pool is automatically replaced after processing this many PDFs to mitigate
        /// WebKit process-level memory leaks that accumulate over long batch operations.
        ///
        /// **Rationale:**
        /// - WebKit processes accumulate memory over time even with proper cleanup
        /// - Periodic pool replacement ensures sustained performance for long-running services
        /// - Default (30,000) balances performance with resource management
        ///
        /// **Tuning Guidelines:**
        /// - **Long-running services**: Use default (30,000) or higher
        /// - **Short-lived CLIs**: Set to `nil` to disable automatic replacement
        /// - **Memory-constrained environments**: Lower to 10,000-15,000
        /// - **High-throughput systems**: Rely on `adaptiveThroughputOptimization` instead
        ///
        /// Set to `nil` to disable automatic pool replacement entirely.
        /// Default is `30_000` for long-running services.
        public var poolReplacementThreshold: Int? = 30_000

        /// Timeout per document (nil = no timeout)
        public var documentTimeout: Duration?

        /// Timeout for entire batch (nil = no timeout)
        public var batchTimeout: Duration?

        /// Timeout for acquiring WebView from pool
        ///
        /// Default is 60 seconds, which is appropriate for interactive apps and services.
        /// For bulk/offline jobs or CI environments, consider increasing to 300-600 seconds
        /// using the `.largeBatch` preset or setting explicitly.
        public var webViewAcquisitionTimeout: Duration

        // MARK: - File System

        /// Automatically create directories if they don't exist
        public var createDirectories: Bool

        // MARK: - Naming Strategy

        /// How to name files in batch operations
        public var namingStrategy: NamingStrategy

        // MARK: - Computed Properties

        /// Pre-computed margin CSS bytes for performance
        /// Generated on-demand and cached based on margins
        public var marginCSSBytes: ContiguousArray<UInt8> {
            let css = """
            <style>
            @media print, screen {
                html {
                    margin: 0;
                    padding: 0;
                }
                body {
                    margin: 0;
                    padding: \(margins.top)pt \(margins.right)pt \(margins.bottom)pt \(margins.left)pt;
                    box-sizing: border-box;
                }
            }
            </style>
            """
            return ContiguousArray(css.utf8)
        }

        public init(
            paperSize: CGSize = .a4,
            margins: EdgeInsets = .standard,
            baseURL: URL? = nil,
            paginationMode: PaginationMode = .continuous,
            concurrency: ConcurrencyStrategy = .automatic,
            adaptiveThroughputOptimization: Bool = false,
            poolReplacementThreshold: Int? = 30_000,
            documentTimeout: Duration? = nil,
            batchTimeout: Duration? = nil,
            webViewAcquisitionTimeout: Duration = .seconds(60),
            createDirectories: Bool = true,
            namingStrategy: NamingStrategy = .sequential
        ) {
            self.paperSize = paperSize
            self.margins = margins
            self.baseURL = baseURL
            self.paginationMode = paginationMode
            self.concurrency = concurrency
            self.adaptiveThroughputOptimization = adaptiveThroughputOptimization
            self.poolReplacementThreshold = poolReplacementThreshold
            self.documentTimeout = documentTimeout
            self.batchTimeout = batchTimeout
            self.webViewAcquisitionTimeout = webViewAcquisitionTimeout
            self.createDirectories = createDirectories
            self.namingStrategy = namingStrategy
        }
    }
}

// MARK: - Configuration Presets

extension PDF.Configuration {
    /// Default configuration (A4, standard margins, continuous mode for fast rendering)
    public static let `default` = PDF.Configuration()

    /// US Letter size with standard margins
    public static let letter = PDF.Configuration(paperSize: .letter)

    /// A4 landscape with minimal margins
    public static let landscapeMinimal = PDF.Configuration(
        paperSize: .a4.landscape,
        margins: .minimal
    )

    /// Multi-page documents with correct A4 dimensions (alias for .default)
    public static let multiPage = PDF.Configuration(
        paginationMode: .paginated
    )

    /// Fast continuous mode for screen viewing (single tall page)
    public static let continuous = PDF.Configuration(
        paginationMode: .continuous
    )

    /// Smart auto-detection based on content
    public static let smart = PDF.Configuration(
        paginationMode: .automatic()
    )

    /// Optimized for large batch processing (auto-detect with speed preference)
    public static let largeBatch = PDF.Configuration(
        paginationMode: .automatic(heuristic: .preferSpeed),
        concurrency: .automatic,
        batchTimeout: .seconds(86400), // 24 hours
        webViewAcquisitionTimeout: .seconds(600)
    )

    /// Optimized for current platform
    public static var platformOptimized: Self {
        .init(
            paperSize: .a4,
            margins: .standard,
            concurrency: .automatic,
            webViewAcquisitionTimeout: .seconds(60)
        )
    }
}

// MARK: - Dependency Registration

extension PDF.Configuration: TestDependencyKey {
    public static let testValue = PDF.Configuration.default
}

// Note: PDF.Configuration is now accessed via \.pdf.configuration
// The PDF struct (in PDF.swift) handles the main dependency registration


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.Document.swift
// ========================================

//
//  PDF.Document.swift
//  swift-html-to-pdf
//
//  Document model for PDF rendering (Types - no HTML library dependencies)
//

import Foundation

// MARK: - CSS Injection Cache

/// Thread-safe cache for CSS-injected HTML to avoid redundant processing
private actor CSSInjectionCache {
    private var cache: [Int: ContiguousArray<UInt8>] = [:]
    private var accessOrder: [Int] = []
    private let maxEntries = 100

    func get(key: Int) -> ContiguousArray<UInt8>? {
        cache[key]
    }

    func set(key: Int, value: ContiguousArray<UInt8>) {
        // Evict oldest entry if at capacity
        if cache.count >= maxEntries, !cache.keys.contains(key) {
            if let oldestKey = accessOrder.first {
                cache.removeValue(forKey: oldestKey)
                accessOrder.removeFirst()
            }
        }

        cache[key] = value
        accessOrder.append(key)
    }

    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
}

private let cssInjectionCache = CSSInjectionCache()

extension PDF {
    /// A document to be rendered as a PDF
    ///
    /// Examples:
    /// ```swift
    /// // Using String (simple)
    /// let doc = PDF.Document(htmlString: "<html><body>Hello</body></html>", destination: fileURL)
    ///
    /// // Using raw bytes (advanced)
    /// let doc = PDF.Document(htmlBytes: bytes, destination: fileURL)
    /// ```
    public struct Document: Sendable {
        let htmlBytes: ContiguousArray<UInt8>
        public let destination: URL

        // MARK: - Initializers

        /// Create a document from raw HTML bytes (advanced usage)
        public init(htmlBytes: ContiguousArray<UInt8>, destination: URL) {
            self.htmlBytes = htmlBytes
            self.destination = destination
        }

        public init(htmlBytes: ContiguousArray<UInt8>, title: String, in directory: URL) {
            self.htmlBytes = htmlBytes
            self.destination = directory
                .appendingPathComponent(title.replacingSlashesWithDivisionSlash())
                .appendingPathExtension("pdf")
        }

        /// Create a document from an HTML string (convenience)
        public init(htmlString: String, destination: URL) {
            self.htmlBytes = ContiguousArray(htmlString.utf8)
            self.destination = destination
        }

        public init(htmlString: String, title: String, in directory: URL) {
            self.htmlBytes = ContiguousArray(htmlString.utf8)
            self.destination = directory
                .appendingPathComponent(title.replacingSlashesWithDivisionSlash())
                .appendingPathExtension("pdf")
        }

        // MARK: - Internal Access

        /// Access the HTML bytes for rendering
        public var html: ContiguousArray<UInt8> { htmlBytes }
    }
}

// MARK: - String Utilities

extension String {
    func replacingSlashesWithDivisionSlash() -> String {
        let divisionSlash = "\u{2215}" // Unicode for Division Slash (∕)
        return self
            .replacingOccurrences(of: "/", with: divisionSlash)
            .replacingOccurrences(of: ":", with: "-")      // Colon not allowed in filenames
            .replacingOccurrences(of: "?", with: "")       // Question mark not allowed
            .replacingOccurrences(of: "*", with: "-")      // Asterisk not allowed
            .replacingOccurrences(of: "<", with: "")       // Less-than not allowed
            .replacingOccurrences(of: ">", with: "")       // Greater-than not allowed
            .replacingOccurrences(of: "|", with: "-")      // Pipe not allowed
            .replacingOccurrences(of: "\"", with: "")      // Quote not allowed
            .replacingOccurrences(of: "\\", with: divisionSlash)  // Backslash treated like forward slash
    }
}

// MARK: - ContiguousArray Utilities

extension ContiguousArray where Element == UInt8 {
    /// Injects CSS bytes into HTML with caching for repeated injections
    ///
    /// This method caches the result to avoid redundant work when the same HTML+CSS
    /// combination is processed multiple times (common in batch operations).
    public func injectingCSS(_ cssBytes: ContiguousArray<UInt8>) async -> ContiguousArray<UInt8> {
        // Generate cache key from HTML + CSS content
        let cacheKey = generateCacheKey(html: self, css: cssBytes)

        // Check cache first
        if let cached = await cssInjectionCache.get(key: cacheKey) {
            return cached
        }

        // Cache miss - perform injection
        let result = performCSSInjection(cssBytes)

        // Store in cache for future reuse
        await cssInjectionCache.set(key: cacheKey, value: result)

        return result
    }

    /// Generate a cache key for HTML + CSS combination
    private func generateCacheKey(html: ContiguousArray<UInt8>, css: ContiguousArray<UInt8>) -> Int {
        // Use Swift's Hasher (xxHash-based) - 10-100x faster than SHA256
        // Collision resistance is sufficient for cache keys
        var hasher = Hasher()
        html.withUnsafeBufferPointer { htmlBuffer in
            hasher.combine(bytes: UnsafeRawBufferPointer(htmlBuffer))
        }
        css.withUnsafeBufferPointer { cssBuffer in
            hasher.combine(bytes: UnsafeRawBufferPointer(cssBuffer))
        }
        return hasher.finalize()
    }

    /// Perform the actual CSS injection (uncached)
    private func performCSSInjection(_ cssBytes: ContiguousArray<UInt8>) -> ContiguousArray<UInt8> {
        let headEndBytes = ContiguousArray("</head>".utf8)
        let headStartBytes = ContiguousArray("<head>".utf8)
        let bodyBytes = ContiguousArray("<body".utf8)

        // Try to inject before </head>
        if let range = self.firstRange(of: headEndBytes, options: .caseInsensitive) {
            var result = ContiguousArray<UInt8>()
            result.reserveCapacity(self.count + cssBytes.count)
            result.append(contentsOf: self[..<range.lowerBound])
            result.append(contentsOf: cssBytes)
            result.append(contentsOf: self[range.lowerBound...])
            return result
        }
        // Try to inject after <head>
        else if let headRange = self.firstRange(of: headStartBytes, options: .caseInsensitive) {
            // Find closing >
            if let closingBracket = self[headRange.upperBound...].firstIndex(of: UInt8(ascii: ">")) {
                let insertPoint = self.index(after: closingBracket)
                var result = ContiguousArray<UInt8>()
                result.reserveCapacity(self.count + cssBytes.count)
                result.append(contentsOf: self[..<insertPoint])
                result.append(contentsOf: cssBytes)
                result.append(contentsOf: self[insertPoint...])
                return result
            }
        }
        // Try to inject before <body>
        else if let bodyRange = self.firstRange(of: bodyBytes, options: .caseInsensitive) {
            var result = ContiguousArray<UInt8>()
            result.reserveCapacity(self.count + cssBytes.count)
            result.append(contentsOf: self[..<bodyRange.lowerBound])
            result.append(contentsOf: cssBytes)
            result.append(contentsOf: self[bodyRange.lowerBound...])
            return result
        }

        // Otherwise inject at the beginning
        var result = cssBytes
        result.append(contentsOf: self)
        return result
    }

    /// Convert to Data for WKWebView loading
    public func toData() -> Data {
        Data(self)
    }
}

// MARK: - Byte Search Utilities

extension ContiguousArray where Element == UInt8 {
    enum SearchOptions {
        case caseInsensitive
    }

    /// Find first occurrence of pattern in array
    func firstRange(of pattern: ContiguousArray<UInt8>, options: SearchOptions? = nil) -> Range<Int>? {
        guard !pattern.isEmpty, pattern.count <= self.count else { return nil }

        let caseInsensitive = options == .caseInsensitive

        for i in 0...(count - pattern.count) {
            var matches = true
            for j in 0..<pattern.count {
                let selfByte = caseInsensitive ? self[i + j].lowercased : self[i + j]
                let patternByte = caseInsensitive ? pattern[j].lowercased : pattern[j]
                if selfByte != patternByte {
                    matches = false
                    break
                }
            }
            if matches {
                return i..<(i + pattern.count)
            }
        }
        return nil
    }
}

extension UInt8 {
    /// Simple ASCII lowercase conversion
    var lowercased: UInt8 {
        if self >= 65 && self <= 90 { // A-Z
            return self + 32
        }
        return self
    }
}


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.EdgeInsets.swift
// ========================================

//
//  PDF.EdgeInsets.swift
//  swift-html-to-pdf
//
//  Edge insets for PDF margins
//

import Foundation

/// Edge insets for defining margins
///
/// All margin values must be non-negative. Negative values are automatically clamped to zero.
///
/// ## Example
///
/// ```swift
/// // Using presets (recommended)
/// let margins = EdgeInsets.standard  // 0.5 inch (36pt) on all sides
///
/// // Custom margins
/// let margins = EdgeInsets(top: 50, left: 40, bottom: 50, right: 40)
///
/// // Negative values are clamped to zero
/// let margins = EdgeInsets(all: -10)  // Results in 0 on all sides
/// ```
public struct EdgeInsets: Sendable {
    public let top: CGFloat
    public let left: CGFloat
    public let bottom: CGFloat
    public let right: CGFloat

    /// Creates edge insets with the specified margins
    ///
    /// Negative values are automatically clamped to zero to prevent invalid margin configurations.
    ///
    /// - Parameters:
    ///   - top: Top margin in points (clamped to >= 0)
    ///   - left: Left margin in points (clamped to >= 0)
    ///   - bottom: Bottom margin in points (clamped to >= 0)
    ///   - right: Right margin in points (clamped to >= 0)
    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = max(0, top)
        self.left = max(0, left)
        self.bottom = max(0, bottom)
        self.right = max(0, right)
    }

    // Convenience initializers

    /// Creates edge insets with the same margin on all sides
    ///
    /// Negative values are automatically clamped to zero.
    ///
    /// - Parameter all: Margin for all sides in points (clamped to >= 0)
    public init(all: CGFloat) {
        self.init(top: all, left: all, bottom: all, right: all)
    }

    /// Creates edge insets with horizontal and vertical margins
    ///
    /// Negative values are automatically clamped to zero.
    ///
    /// - Parameters:
    ///   - horizontal: Left and right margin in points (clamped to >= 0)
    ///   - vertical: Top and bottom margin in points (clamped to >= 0)
    public init(horizontal: CGFloat, vertical: CGFloat) {
        self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}

// MARK: - Presets

extension EdgeInsets {
    /// No margins
    public static let none = EdgeInsets(all: 0)

    /// Minimal margins (0.25 inch)
    public static let minimal = EdgeInsets(all: 18)

    /// Standard margins (0.5 inch)
    public static let standard = EdgeInsets(all: 36)

    /// Comfortable margins (0.75 inch)
    public static let comfortable = EdgeInsets(all: 54)

    /// Wide margins (1 inch)
    public static let wide = EdgeInsets(all: 72)
}

// MARK: - Platform Conversions

#if os(macOS)
import AppKit

extension NSEdgeInsets {
    init(edgeInsets: EdgeInsets) {
        self = .init(
            top: edgeInsets.top,
            left: edgeInsets.left,
            bottom: edgeInsets.bottom,
            right: edgeInsets.right
        )
    }
}
#endif

#if canImport(UIKit)
import UIKit

extension UIEdgeInsets {
    init(edgeInsets: EdgeInsets) {
        self = .init(
            top: .init(edgeInsets.top),
            left: .init(edgeInsets.left),
            bottom: .init(edgeInsets.bottom),
            right: .init(edgeInsets.right)
        )
    }
}
#endif


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.FailedDocument.swift
// ========================================

//
//  PDF.FailedDocument.swift
//  swift-html-to-pdf
//
//  Error information for failed document rendering
//

import Foundation

extension PDF {
    /// Information about a document that failed to render
    ///
    /// Used in resilient batch operations to report failures without stopping the entire batch.
    public struct FailedDocument: Sendable, Error {
        /// The document that failed to render
        public let document: PDF.Document

        /// The index of this document in the batch
        public let index: Int

        /// The underlying error that caused the failure
        public let error: Error

        /// How long was spent attempting to render before failure
        public let duration: Duration

        public init(
            document: PDF.Document,
            index: Int,
            error: Error,
            duration: Duration
        ) {
            self.document = document
            self.index = index
            self.error = error
            self.duration = duration
        }
    }
}

extension PDF.FailedDocument: LocalizedError {
    public var errorDescription: String? {
        "Failed to render document \(index + 1) ('\(document.destination.lastPathComponent)'): \(error.localizedDescription)"
    }

    public var failureReason: String? {
        (error as? LocalizedError)?.failureReason
    }

    public var recoverySuggestion: String? {
        (error as? LocalizedError)?.recoverySuggestion
    }
}


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.NamingStrategy.swift
// ========================================

//
//  PDF.NamingStrategy.swift
//  swift-html-to-pdf
//
//  Naming strategies for batch PDF operations
//

import Foundation

extension PDF {
    /// Strategy for naming files in batch operations
    public struct NamingStrategy: Sendable {
        private let _filename: @Sendable (Int) -> String

        /// Create a custom naming strategy
        public init(filename: @escaping @Sendable (Int) -> String) {
            self._filename = filename
        }

        /// Generate filename for given index
        public func filename(for index: Int) -> String {
            _filename(index)
        }
    }
}

// MARK: - Presets

extension PDF.NamingStrategy {
    /// Sequential numbering: "1.pdf", "2.pdf", ...
    public static let sequential = PDF.NamingStrategy { index in
        "\(index + 1)"
    }

    /// UUID-based names
    public static let uuid = PDF.NamingStrategy { _ in
        UUID().uuidString
    }
}


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.PaginationMode.swift
// ========================================

//
//  PDF.PaginationMode.swift
//  swift-html-to-pdf
//
//  Pagination mode for PDF rendering
//

import Foundation

extension PDF {
    /// How content should be paginated in the PDF
    ///
    /// This determines how HTML content flows into the PDF:
    ///
    /// - `.paginated`: Content is split into multiple pages (e.g., 3 pages of A4)
    ///   - Best for: Invoices, reports, documents for printing
    ///   - Performance: Slower (538 PDFs/sec on M1)
    ///   - Implementation: Uses NSPrintOperation (macOS) or UIPrintPageRenderer (iOS)
    ///
    /// - `.continuous`: Single tall page containing all content
    ///   - Best for: Articles, web captures, infographics for screen viewing
    ///   - Performance: Fast (1796 PDFs/sec on M1)
    ///   - Implementation: Uses WKWebView.createPDF
    ///
    /// - `.automatic`: Chooses based on content analysis
    ///   - Best for: Unknown content, balanced performance
    ///   - Performance: Varies based on detection
    public enum PaginationMode: Sendable, Equatable {
        /// Split content into multiple pages of exact paperSize
        ///
        /// Each page will match the configured `paperSize` exactly.
        /// CSS page breaks are respected.
        /// Margins are applied via print settings.
        case paginated

        /// Single continuous page
        ///
        /// Width matches `paperSize.width`, height matches content height.
        /// CSS page breaks are ignored.
        /// Margins are applied via CSS padding.
        case continuous

        /// Automatically choose based on content analysis
        ///
        /// Uses the provided heuristic to determine whether to use
        /// paginated or continuous mode.
        case automatic(heuristic: AutomaticHeuristic = .contentLength())
    }

    /// Strategy for automatic pagination detection
    public enum AutomaticHeuristic: Sendable, Equatable {
        /// Choose based on estimated page count
        ///
        /// Measures content height and compares to page height.
        /// If content would span more than the threshold (in pages), uses paginated mode.
        ///
        /// - Parameter threshold: Number of pages that triggers pagination (default: 1.5)
        ///
        /// Example: threshold of 1.5 means content over 1.5 pages uses paginated mode
        case contentLength(threshold: CGFloat = 1.5)

        /// Choose based on HTML structure
        ///
        /// Detects presence of print-specific CSS or page break directives.
        /// If found, uses paginated mode for proper print output.
        case htmlStructure

        /// Always prefer speed (continuous mode)
        ///
        /// Uses WKWebView.createPDF for maximum throughput.
        /// Results in continuous tall pages.
        case preferSpeed

        /// Always prefer print-ready output (paginated mode)
        ///
        /// Uses NSPrintOperation/UIPrintPageRenderer for proper pagination.
        /// Results in properly paginated documents.
        case preferPrintReady
    }
}

// MARK: - Metrics Support

extension PDF.PaginationMode {
    /// Label for metrics dimension tracking
    ///
    /// Provides a stable string representation for use in metrics dimensions.
    /// This allows segmentation of render duration metrics by pagination mode.
    var metricsLabel: String {
        switch self {
        case .continuous:
            return "continuous"
        case .paginated:
            return "paginated"
        case .automatic(let heuristic):
            switch heuristic {
            case .contentLength:
                return "automatic_content_length"
            case .htmlStructure:
                return "automatic_html_structure"
            case .preferSpeed:
                return "automatic_prefer_speed"
            case .preferPrintReady:
                return "automatic_prefer_print_ready"
            }
        }
    }
}

// MARK: - Internal Rendering Method

extension PDF {
    /// Internal rendering method (not exposed in public API)
    ///
    /// This is the actual implementation strategy chosen after
    /// analyzing the pagination mode and content.
    public enum InternalRenderingMethod {
        case webView
        case printOperation
    }
}


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.PaperSize.swift
// ========================================

//
//  PDF.PaperSize.swift
//  swift-html-to-pdf
//
//  Paper size extensions for CGSize
//

import Foundation

/// Paper size extensions for CGSize
///
/// Provides standard paper sizes in points (1 point = 1/72 inch).
///
/// ## Important
///
/// When creating custom paper sizes, ensure both width and height are positive values.
/// Using the provided static properties (`.a4`, `.letter`, etc.) is recommended for
/// standard sizes.
///
/// ## Example
///
/// ```swift
/// // Using standard sizes (recommended)
/// configuration.paperSize = .a4
/// configuration.paperSize = .letter
///
/// // Custom size
/// configuration.paperSize = CGSize(width: 600, height: 800)
///
/// // Landscape orientation
/// configuration.paperSize = .a4.landscape
/// ```
extension CGSize {
    // MARK: - ISO 216 Sizes (in points)

    /// A3 paper size (297 × 420 mm)
    public static let a3 = CGSize(width: 841.89, height: 1190.55)

    /// A4 paper size (210 × 297 mm)
    public static let a4 = CGSize(width: 595.28, height: 841.89)

    /// A5 paper size (148 × 210 mm)
    public static let a5 = CGSize(width: 420.94, height: 595.28)

    // MARK: - US Paper Sizes (in points)

    /// US Letter size (8.5 × 11 inches)
    public static let letter = CGSize(width: 612, height: 792)

    /// US Legal size (8.5 × 14 inches)
    public static let legal = CGSize(width: 612, height: 1008)

    /// US Tabloid size (11 × 17 inches)
    public static let tabloid = CGSize(width: 792, height: 1224)

    // MARK: - Orientation

    /// Returns landscape version of this size (wider than tall)
    public var landscape: CGSize {
        CGSize(
            width: max(width, height),
            height: min(width, height)
        )
    }

    /// Returns portrait version of this size (taller than wide)
    public var portrait: CGSize {
        CGSize(
            width: min(width, height),
            height: max(width, height)
        )
    }

    /// Whether this size is landscape orientation
    public var isLandscape: Bool { width > height }

    /// Whether this size is portrait orientation
    public var isPortrait: Bool { height >= width }
}


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.Render.Client.swift
// ========================================

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
    }
}


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.Render.Metrics+macOS.swift
// ========================================

//
//  PDF.Render.Metrics+macOS.swift
//  swift-html-to-pdf
//
//  Live metrics implementation using swift-metrics
//

#if os(macOS) || os(iOS)
import Dependencies
import Metrics

extension PDF.Render.Metrics: DependencyKey {
    /// Live implementation delegating to swift-metrics
    ///
    /// Creates swift-metrics Counter/Timer/Gauge instances and delegates
    /// operations to them. Requires MetricsSystem.bootstrap() at app startup.
    public static var liveValue: Self {
        // Create swift-metrics instances (captured in closures)
        let pdfsGenerated = Counter(label: "htmltopdf_pdfs_generated_total")
        let pdfsFailed = Counter(label: "htmltopdf_pdfs_failed_total")
        let poolReplacements = Counter(label: "htmltopdf_pool_replacements_total")
        let renderDuration = Timer(label: "htmltopdf_render_duration_seconds")
        let poolUtilization = Gauge(label: "htmltopdf_pool_utilization")
        let currentThroughput = Gauge(label: "htmltopdf_throughput_pdfs_per_sec")

        return Self(
            incrementPDFsGenerated: { pdfsGenerated.increment() },
            incrementPDFsFailed: { pdfsFailed.increment() },
            incrementPoolReplacements: { poolReplacements.increment() },
            recordRenderDuration: { duration, mode in
                let nanoseconds = duration.components.seconds * 1_000_000_000 +
                                duration.components.attoseconds / 1_000_000_000
                if let mode = mode {
                    Timer(
                        label: "htmltopdf_render_duration_seconds",
                        dimensions: [("mode", mode.metricsLabel)]
                    ).recordNanoseconds(nanoseconds)
                } else {
                    renderDuration.recordNanoseconds(nanoseconds)
                }
            },
            updatePoolUtilization: { count in poolUtilization.record(count) },
            updateThroughput: { pdfsPerSecond in currentThroughput.record(pdfsPerSecond) }
        )
    }
}
#endif


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.Render.Metrics.swift
// ========================================

//
//  PDF.Render.Metrics.swift
//  swift-html-to-pdf
//
//  Metrics for PDF rendering observability
//

import Dependencies
import DependenciesMacros
import Foundation

extension PDF.Render {
    /// Metrics for PDF rendering operations
    ///
    /// Following the domain-first pattern where Metrics is a capability
    /// with operations defined as dependency endpoints for testability.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Dependency(\.pdf.render.metrics) var metrics
    ///
    /// metrics.recordSuccess(duration: duration, mode: .paginated)
    /// metrics.recordFailure(error: error)
    /// ```
    ///
    /// ## Production Integration
    ///
    /// The live implementation delegates to swift-metrics. Bootstrap once at startup:
    ///
    /// ```swift
    /// import Metrics
    ///
    /// @main
    /// struct MyApp {
    ///     static func main() {
    ///         MetricsSystem.bootstrap(PrometheusMetricsFactory())
    ///         // ...
    ///     }
    /// }
    /// ```
    ///
    /// ## Available Metrics
    ///
    /// **Counters:**
    /// - `htmltopdf_pdfs_generated_total`: Total PDFs successfully generated
    /// - `htmltopdf_pdfs_failed_total`: Total PDF generation failures
    /// - `htmltopdf_pool_replacements_total`: Total resource pool replacements
    ///
    /// **Timers:**
    /// - `htmltopdf_render_duration_seconds`: PDF render duration (p50/p95/p99)
    ///
    /// **Gauges:**
    /// - `htmltopdf_pool_utilization`: Current WebViews in pool
    /// - `htmltopdf_throughput_pdfs_per_sec`: Current throughput
    @DependencyClient
    public struct Metrics: @unchecked Sendable {

        // MARK: - Counter Operations

        /// Increment PDFs generated counter
        @DependencyEndpoint
        public var incrementPDFsGenerated: @Sendable () -> Void

        /// Increment PDFs failed counter
        @DependencyEndpoint
        public var incrementPDFsFailed: @Sendable () -> Void

        /// Increment pool replacements counter
        @DependencyEndpoint
        public var incrementPoolReplacements: @Sendable () -> Void

        // MARK: - Timer Operations

        /// Record render duration
        @DependencyEndpoint
        public var recordRenderDuration: @Sendable (_ duration: Duration, _ mode: PDF.PaginationMode?) -> Void

        // MARK: - Gauge Operations

        /// Update pool utilization gauge
        @DependencyEndpoint
        public var updatePoolUtilization: @Sendable (_ count: Int) -> Void

        /// Update throughput gauge
        @DependencyEndpoint
        public var updateThroughput: @Sendable (_ pdfsPerSecond: Double) -> Void

        // MARK: - Convenience Methods

        /// Record successful PDF generation
        ///
        /// Increments the counter and records the render duration.
        ///
        /// - Parameters:
        ///   - duration: Time taken to render the PDF
        ///   - mode: Optional pagination mode for dimensional tracking
        public func recordSuccess(duration: Duration, mode: PDF.PaginationMode? = nil) {
            incrementPDFsGenerated()
            recordRenderDuration(duration, mode)
        }

        /// Record PDF generation failure
        ///
        /// Increments the failures counter.
        ///
        /// - Parameter error: Optional error for dimensional tracking
        public func recordFailure(error: PrintingError? = nil) {
            incrementPDFsFailed()
        }

        /// Record pool replacement
        ///
        /// Increments the pool replacements counter.
        public func recordPoolReplacement() {
            incrementPoolReplacements()
        }
    }
}


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.Render.Result.swift
// ========================================

//
//  PDF.Render.Result.swift
//  swift-html-to-pdf
//
//  Result type for rendering operations
//

import Foundation


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.Render.swift
// ========================================

//
//  PDF.Render.swift
//  swift-html-to-pdf
//
//  Rendering capability within the PDF domain
//

import Dependencies
import Foundation

extension PDF {
    /// Rendering capability containing client, configuration, and metrics.
    ///
    /// This follows the domain-first pattern where the business capability (Render)
    /// is primary, with technical implementations (Client, Configuration, Metrics) as nested types.
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
    ///
    /// // Access metrics
    /// let metrics = pdf.render.metrics
    /// ```
    public struct Render: Sendable {
        /// Client for rendering operations
        public var client: PDF.Render.Client

        /// Configuration for PDF rendering
        public var configuration: PDF.Configuration

        /// Metrics for production observability
        public var metrics: PDF.Render.Metrics

        public init(
            client: PDF.Render.Client,
            configuration: PDF.Configuration,
            metrics: PDF.Render.Metrics
        ) {
            self.client = client
            self.configuration = configuration
            self.metrics = metrics
        }
    }
}


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.Result.swift
// ========================================

//
//  PDF.Result.swift
//  swift-html-to-pdf
//
//  Result type for batch PDF operations
//

import Foundation

extension PDF {
    /// Result of a single PDF generation operation
    ///
    /// Returned by batch rendering operations to provide progress information
    /// and verification data.
    public struct Result: Sendable {
        /// The URL where the PDF was saved
        public let url: URL

        /// The index of this document in the batch
        public let index: Int

        /// How long it took to render this PDF
        public let duration: Duration

        /// The pagination mode that was actually used for rendering
        public let paginationMode: PaginationMode

        /// Number of pages in the generated PDF
        public let pageCount: Int

        /// Dimensions of each page in the PDF
        public let pageDimensions: [CGSize]

        public init(
            url: URL,
            index: Int,
            duration: Duration,
            paginationMode: PaginationMode,
            pageCount: Int,
            pageDimensions: [CGSize]
        ) {
            self.url = url
            self.index = index
            self.duration = duration
            self.paginationMode = paginationMode
            self.pageCount = pageCount
            self.pageDimensions = pageDimensions
        }
    }
}


// ========================================
// File: Sources/HtmlToPdfTypes/PDF.swift
// ========================================

//
//  PDF.swift
//  swift-html-to-pdf
//
//  Core namespace for PDF rendering operations
//

import Dependencies
import Foundation

/// PDF domain containing rendering capability
///
/// This type serves as the unified entry point for all PDF operations,
/// following the domain-first pattern where the business capability (Render)
/// is primary with technical implementations (Client, Configuration) as nested types.
///
/// ## Basic Usage
///
/// ```swift
/// @Dependency(\.pdf) var pdf
///
/// // Render documents
/// try await pdf.render.client.documents(documents)
///
/// // Render single HTML to file
/// try await pdf.render.client.html(html, destination)
///
/// // Configure and render
/// try await withDependencies {
///     $0.pdf.render.configuration.paperSize = .letter
///     $0.pdf.render.configuration.margins = .wide
/// } operation: {
///     try await pdf.render.client.documents(documents)
/// }
/// ```
///
/// ## Direct Access
///
/// ```swift
/// @Dependency(\.pdf.render.client) var renderClient
/// @Dependency(\.pdf.render.configuration) var config
///
/// // Access client directly
/// let stream = try await renderClient.documents(documents)
///
/// // Access configuration directly
/// let poolSize = config.concurrency
/// ```
///
/// ## Convenience Methods for Configuration
///
/// ```swift
/// @Dependency(\.pdf) var pdf
///
/// // Set baseURL for resolving relative resources
/// try await pdf.withBaseURL(
///     URL(fileURLWithPath: "/path/to/assets"),
///     render: htmlWithRelativeImages,
///     to: output
/// )
/// ```
public struct PDF: Sendable {
    /// Rendering capability containing client and configuration
    public var render: Render

    public init(
        render: Render
    ) {
        self.render = render
    }
}

// MARK: - Dependency Registration
// DependencyKey conformances and DependencyValues extension are in HtmlToPdfLive target



// ========================================
// File: Sources/HtmlToPdfTypes/PrintingError.swift
// ========================================

//
//  PrintingError.swift
//  swift-html-to-pdf
//
//  Created on 2025-09-29.
//

import Foundation

/// Errors that can occur during PDF printing operations
public enum PrintingError: Error, LocalizedError, Sendable {

    // MARK: - Document Errors

    /// The provided HTML content could not be rendered
    case invalidHTML(String)

    /// The target file path is not accessible or writable
    case invalidFilePath(URL, underlyingError: Error?)

    /// Failed to create required directories
    case directoryCreationFailed(URL, underlyingError: Error)

    // MARK: - WebView Errors

    /// Failed to load HTML content into WebView
    case webViewLoadingFailed(underlyingError: Error)

    /// WebView navigation failed
    case webViewNavigationFailed(underlyingError: Error)

    /// WebView rendering timed out
    case webViewRenderingTimeout(timeoutSeconds: TimeInterval)

    // MARK: - Pool Errors

    /// WebView pool exhausted and cannot provide a WebView
    case webViewPoolExhausted(pendingRequests: Int)

    /// Failed to acquire WebView from pool within timeout
    case webViewAcquisitionTimeout(timeoutSeconds: TimeInterval)

    /// WebView pool initialization failed
    case webViewPoolInitializationFailed(underlyingError: Error?)

    // MARK: - PDF Generation Errors

    /// PDF generation failed
    case pdfGenerationFailed(underlyingError: Error)

    /// Print operation failed
    case printOperationFailed(success: Bool, underlyingError: Error?)

    /// Document processing timed out
    case documentTimeout(documentURL: URL, timeoutSeconds: TimeInterval)

    /// Batch processing timed out
    case batchTimeout(completedCount: Int, totalCount: Int, timeoutSeconds: TimeInterval)

    // MARK: - Cancellation

    /// Operation was cancelled
    case cancelled(message: String?)

    /// No result was produced from rendering operation
    case noResultProduced

    // MARK: - Platform Capability Errors

    /// Platform lacks required capability for this operation
    case capabilityUnavailable(capability: String, platform: String, reason: String)

    // MARK: - LocalizedError Implementation

    public var errorDescription: String? {
        switch self {
        case .invalidHTML(let html):
            let preview = String(html.prefix(100))
            return "Invalid HTML content: \(preview)..."

        case .invalidFilePath(let url, let error):
            if let error = error {
                return "Cannot write to file path '\(url.path)': \(error.localizedDescription)"
            }
            return "Cannot write to file path: \(url.path)"

        case .directoryCreationFailed(let url, let error):
            return "Failed to create directory at '\(url.path)': \(error.localizedDescription)"

        case .webViewLoadingFailed(let error):
            return "Failed to load HTML into WebView: \(error.localizedDescription)"

        case .webViewNavigationFailed(let error):
            return "WebView navigation failed: \(error.localizedDescription)"

        case .webViewRenderingTimeout(let timeout):
            return "WebView rendering timed out after \(Int(timeout)) seconds"

        case .webViewPoolExhausted(let pending):
            return "WebView pool is exhausted with \(pending) pending requests"

        case .webViewAcquisitionTimeout(let timeout):
            return "Failed to acquire WebView from pool within \(Int(timeout)) seconds"

        case .webViewPoolInitializationFailed(let error):
            if let error = error {
                return "WebView pool initialization failed: \(error.localizedDescription)"
            }
            return "WebView pool initialization failed"

        case .pdfGenerationFailed(let error):
            return "PDF generation failed: \(error.localizedDescription)"

        case .printOperationFailed(let success, let error):
            if let error = error {
                return "Print operation failed: \(error.localizedDescription)"
            }
            return "Print operation failed (success: \(success))"

        case .documentTimeout(let url, let timeout):
            return "Document processing timed out for '\(url.lastPathComponent)' after \(Int(timeout)) seconds"

        case .batchTimeout(let completed, let total, let timeout):
            return "Batch processing timed out after \(Int(timeout)) seconds (\(completed)/\(total) completed)"

        case .cancelled(let message):
            if let message = message {
                return "Operation cancelled: \(message)"
            }
            return "Operation cancelled"

        case .noResultProduced:
            return "No result was produced from rendering operation"

        case .capabilityUnavailable(let capability, let platform, let reason):
            return "Platform '\(platform)' does not support '\(capability)': \(reason)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidHTML:
            return "The HTML content may be malformed or contain unsupported elements"

        case .invalidFilePath:
            return "The file path may not exist, lack write permissions, or be on a read-only volume"

        case .directoryCreationFailed:
            return "Insufficient permissions or disk space to create the directory"

        case .webViewLoadingFailed, .webViewNavigationFailed:
            return "The HTML content may contain resources that cannot be loaded"

        case .webViewRenderingTimeout:
            return "The HTML content may be too complex or contain infinite loops"

        case .webViewPoolExhausted:
            return "Too many concurrent print operations for available resources"

        case .webViewAcquisitionTimeout:
            return "All WebViews are busy processing other documents"

        case .webViewPoolInitializationFailed:
            return "System resources may be insufficient to create WebViews"

        case .pdfGenerationFailed:
            return "The rendering engine encountered an error creating the PDF"

        case .printOperationFailed:
            return "The system print operation could not complete"

        case .documentTimeout:
            return "Document is too large or complex to process within the timeout"

        case .batchTimeout:
            return "Batch contains too many documents to process within the timeout"

        case .cancelled:
            return "User or system cancelled the operation"

        case .noResultProduced:
            return "The rendering operation completed but produced no output"

        case .capabilityUnavailable:
            return "This operation requires platform capabilities that are not available"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidHTML:
            return "Validate your HTML using an HTML validator and ensure it's well-formed"

        case .invalidFilePath:
            return "Verify the file path exists and has write permissions"

        case .directoryCreationFailed:
            return "Check disk space and permissions for the parent directory"

        case .webViewLoadingFailed, .webViewNavigationFailed:
            return "Ensure all referenced resources are accessible or use base64-encoded data"

        case .webViewRenderingTimeout:
            return "Simplify the HTML content or increase the timeout duration"

        case .webViewPoolExhausted:
            return "Reduce maxConcurrentOperations in PrintingConfiguration"

        case .webViewAcquisitionTimeout:
            return "Increase webViewAcquisitionTimeout or reduce concurrent operations"

        case .webViewPoolInitializationFailed:
            return "Restart the application or reduce the pool size"

        case .pdfGenerationFailed:
            return "Check the HTML content for rendering issues"

        case .printOperationFailed:
            return "Check system print settings and available disk space"

        case .documentTimeout:
            return "Increase documentTimeout in PrintingConfiguration or simplify the document"

        case .batchTimeout:
            return "Increase batchTimeout, reduce batch size, or process in smaller chunks"

        case .cancelled:
            return "Retry the operation if needed"

        case .noResultProduced:
            return "Check that the document was properly configured and retry"

        case .capabilityUnavailable(let capability, let platform, _):
            return "Use a different platform or reduce '\(capability)' requirements to match '\(platform)' capabilities"
        }
    }
}

// MARK: - Error Code Support

extension PrintingError {
    /// Stable error code for programmatic branching
    ///
    /// Use this for switch statements and error handling logic instead of pattern matching.
    /// These codes are guaranteed to remain stable across versions for long-term compatibility.
    ///
    /// Example:
    /// ```swift
    /// do {
    ///     try await pdf.render(html, to: url)
    /// } catch let error as PrintingError {
    ///     switch error.errorCode {
    ///     case "webview_acquisition_timeout":
    ///         // Increase timeout and retry
    ///     case "pdf_generation_failed":
    ///         // Check underlying error
    ///         if let underlying = error.underlyingError {
    ///             // Handle specific underlying error
    ///         }
    ///     default:
    ///         // Generic error handling
    ///     }
    /// }
    /// ```
    public var errorCode: String {
        metricsReason
    }

    /// Access to underlying error for branching logic
    ///
    /// Many errors wrap underlying system errors (WKError, URLError, NSError).
    /// Use this to access the underlying error for more specific error handling.
    public var underlyingError: Error? {
        switch self {
        case .invalidFilePath(_, let error),
             .webViewPoolInitializationFailed(let error),
             .printOperationFailed(_, let error):
            return error
        case .directoryCreationFailed(_, let error),
             .webViewLoadingFailed(let error),
             .webViewNavigationFailed(let error),
             .pdfGenerationFailed(let error):
            return error
        default:
            return nil
        }
    }
}

// MARK: - Metrics Support

extension PrintingError {
    /// Label for metrics dimension tracking
    ///
    /// Provides a stable string representation for use in metrics dimensions.
    /// This allows segmentation of failure metrics by error type.
    var metricsReason: String {
        switch self {
        // Document Errors
        case .invalidHTML:
            return "invalid_html"
        case .invalidFilePath:
            return "invalid_file_path"
        case .directoryCreationFailed:
            return "directory_creation_failed"

        // WebView Errors
        case .webViewLoadingFailed:
            return "webview_loading_failed"
        case .webViewNavigationFailed:
            return "webview_navigation_failed"
        case .webViewRenderingTimeout:
            return "webview_rendering_timeout"

        // Pool Errors
        case .webViewPoolExhausted:
            return "webview_pool_exhausted"
        case .webViewAcquisitionTimeout:
            return "webview_acquisition_timeout"
        case .webViewPoolInitializationFailed:
            return "webview_pool_initialization_failed"

        // PDF Generation Errors
        case .pdfGenerationFailed:
            return "pdf_generation_failed"
        case .printOperationFailed:
            return "print_operation_failed"
        case .documentTimeout:
            return "document_timeout"
        case .batchTimeout:
            return "batch_timeout"

        // Cancellation
        case .cancelled:
            return "cancelled"
        case .noResultProduced:
            return "no_result_produced"

        // Platform Capability Errors
        case .capabilityUnavailable:
            return "capability_unavailable"
        }
    }
}

// MARK: - Convenience Initializers

//extension PrintingError {
//
//    /// Create an error from a WebViewPoolActor.Error
//    /// Pass the actual timeout value if available instead of using default
//    static func from(poolError: WebViewPoolActor.Error, timeoutSeconds: TimeInterval = 300) -> PrintingError {
//        switch poolError {
//        case .timeout:
//            return .webViewAcquisitionTimeout(timeoutSeconds: timeoutSeconds)
//        case .cancelled:
//            return .cancelled(message: nil)
//        }
//    }
//}


// ========================================
// File: Sources/HtmlToPdfTypes/exports.swift
// ========================================

@_exported import struct Foundation.URL
@_exported import struct Foundation.Data
@_exported import Dependencies


// ========================================
// File: Sources/PDFTestSupport/MetricsTestSupport.swift
// ========================================

//
//  MetricsTestSupport.swift
//  PDFTestSupport
//
//  Utilities for testing with metrics
//

import Foundation
import Metrics

// MARK: - Live Metrics Display

/// Display live metrics during long-running tests
///
/// Example:
/// ```swift
/// let display = LiveMetricsDisplay(metricsBackend: backend)
/// await display.start()
/// // ... run your test ...
/// await display.stop()
/// ```
public actor LiveMetricsDisplay {
    private let metricsBackend: TestMetricsBackend
    private let updateInterval: Duration
    private var displayTask: Task<Void, Never>?
    private var isRunning = false

    public init(
        metricsBackend: TestMetricsBackend,
        updateInterval: Duration = .seconds(2)
    ) {
        self.metricsBackend = metricsBackend
        self.updateInterval = updateInterval
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        displayTask = Task {
            while !Task.isCancelled {
                await printCurrentMetrics()
                try? await Task.sleep(for: updateInterval)
            }
        }
    }

    public func stop() {
        isRunning = false
        displayTask?.cancel()
        displayTask = nil
    }

    private func printCurrentMetrics() async {
        let pdfsGenerated = metricsBackend.counter("htmltopdf_pdfs_generated_total")?.value ?? 0
        let pdfsFailed = metricsBackend.counter("htmltopdf_pdfs_failed_total")?.value ?? 0
        let poolUtil = metricsBackend.gauge("htmltopdf_pool_utilization")?.value ?? 0
        let throughput = metricsBackend.gauge("htmltopdf_throughput_pdfs_per_sec")?.value ?? 0

        let timer = metricsBackend.timer("htmltopdf_render_duration_seconds")
        let p95 = (timer?.p95 ?? 0) * 1000 // Convert to ms

        print("📊 Live Metrics | PDFs: \(pdfsGenerated) | Failed: \(pdfsFailed) | Pool: \(Int(poolUtil)) | Throughput: \(String(format: "%.0f", throughput))/sec | p95: \(String(format: "%.1f", p95))ms")
    }
}

// MARK: - Metrics Assertions

/// Assert that a counter has a specific value
///
/// Example:
/// ```swift
/// try await expectCounter(
///     "htmltopdf_pdfs_generated_total",
///     equals: 100,
///     in: metricsBackend
/// )
/// ```
public func expectCounter(
    _ label: String,
    equals expectedValue: Int64,
    in backend: TestMetricsBackend,
    file: StaticString = #file,
    line: UInt = #line
) async throws {
    let counter = backend.counter(label)
    guard let counter = counter else {
        throw MetricsTestError.metricNotFound(label: label)
    }
    let actualValue = counter.value
    guard actualValue == expectedValue else {
        throw MetricsTestError.valueMismatch(
            label: label,
            expected: "\(expectedValue)",
            actual: "\(actualValue)"
        )
    }
}

/// Assert that a timer's p95 latency is below a threshold
///
/// Example:
/// ```swift
/// try await expectLatency(
///     "htmltopdf_render_duration_seconds",
///     p95LessThan: 0.1, // 100ms
///     in: metricsBackend
/// )
/// ```
public func expectLatency(
    _ label: String,
    p95LessThan threshold: TimeInterval,
    in backend: TestMetricsBackend,
    file: StaticString = #file,
    line: UInt = #line
) async throws {
    let timer = backend.timer(label)
    guard let timer = timer else {
        throw MetricsTestError.metricNotFound(label: label)
    }
    let p95 = timer.p95
    guard p95 < threshold else {
        throw MetricsTestError.thresholdExceeded(
            label: label,
            metric: "p95 latency",
            threshold: "\(threshold)s",
            actual: "\(p95)s"
        )
    }
}

/// Assert that throughput exceeds a minimum threshold
///
/// Example:
/// ```swift
/// try await expectThroughput(
///     greaterThan: 1000.0,
///     pdfsGenerated: 10_000,
///     duration: 10.0,
///     in: metricsBackend
/// )
/// ```
public func expectThroughput(
    greaterThan threshold: Double,
    pdfsGenerated: Int64,
    duration: TimeInterval,
    in backend: TestMetricsBackend,
    file: StaticString = #file,
    line: UInt = #line
) async throws {
    let throughput = Double(pdfsGenerated) / duration
    guard throughput > threshold else {
        throw MetricsTestError.thresholdExceeded(
            label: "throughput",
            metric: "PDFs/sec",
            threshold: "\(threshold)",
            actual: "\(throughput)"
        )
    }
}

// MARK: - Metrics Comparison

/// Compare metrics against a baseline to detect regressions
///
/// Example:
/// ```swift
/// let comparison = await compareMetrics(
///     current: currentBackend,
///     baseline: baselineValues,
///     tolerance: 0.10 // 10% regression allowed
/// )
/// if comparison.hasRegressions {
///     print(comparison.summary())
/// }
/// ```
public struct MetricsComparison: Sendable {
    public let currentP95Latency: TimeInterval
    public let baselineP95Latency: TimeInterval
    public let currentThroughput: Double
    public let baselineThroughput: Double
    public let tolerance: Double

    public init(
        currentP95Latency: TimeInterval,
        baselineP95Latency: TimeInterval,
        currentThroughput: Double,
        baselineThroughput: Double,
        tolerance: Double
    ) {
        self.currentP95Latency = currentP95Latency
        self.baselineP95Latency = baselineP95Latency
        self.currentThroughput = currentThroughput
        self.baselineThroughput = baselineThroughput
        self.tolerance = tolerance
    }

    public var latencyRegression: Double {
        (currentP95Latency - baselineP95Latency) / baselineP95Latency
    }

    public var throughputRegression: Double {
        (baselineThroughput - currentThroughput) / baselineThroughput
    }

    public var hasRegressions: Bool {
        latencyRegression > tolerance || throughputRegression > tolerance
    }

    public func summary() -> String {
        var lines = ["Performance Comparison:"]
        lines.append("  p95 Latency: \(String(format: "%.2f", currentP95Latency * 1000))ms (baseline: \(String(format: "%.2f", baselineP95Latency * 1000))ms)")
        if latencyRegression > tolerance {
            lines.append("    ⚠️  REGRESSION: +\(String(format: "%.1f", latencyRegression * 100))% (tolerance: \(String(format: "%.1f", tolerance * 100))%)")
        }
        lines.append("  Throughput: \(String(format: "%.0f", currentThroughput)) PDFs/sec (baseline: \(String(format: "%.0f", baselineThroughput)) PDFs/sec)")
        if throughputRegression > tolerance {
            lines.append("    ⚠️  REGRESSION: -\(String(format: "%.1f", throughputRegression * 100))% (tolerance: \(String(format: "%.1f", tolerance * 100))%)")
        }
        return lines.joined(separator: "\n")
    }
}

public func compareMetrics(
    current: TestMetricsBackend,
    baselineP95Latency: TimeInterval,
    baselineThroughput: Double,
    tolerance: Double = 0.10
) async -> MetricsComparison {
    let timer = current.timer("htmltopdf_render_duration_seconds")
    let currentP95 = timer?.p95 ?? 0

    let pdfsGenerated = current.counter("htmltopdf_pdfs_generated_total")?.value ?? 0
    let timer2 = current.timer("htmltopdf_render_duration_seconds")
    let totalDuration = (timer2?.values.reduce(0, +) ?? 0)
    let currentThroughput = totalDuration > 0 ? Double(pdfsGenerated) / (TimeInterval(totalDuration) / 1_000_000_000) : 0

    return MetricsComparison(
        currentP95Latency: currentP95,
        baselineP95Latency: baselineP95Latency,
        currentThroughput: currentThroughput,
        baselineThroughput: baselineThroughput,
        tolerance: tolerance
    )
}

// MARK: - Metrics Summary Formatting

/// Format metrics for pretty-printing in tests
public func formatMetricsSummary(_ backend: TestMetricsBackend) async -> String {
    var lines = ["╔══════════════════════════════════════════════════════════╗"]
    lines.append("║              TEST METRICS SUMMARY                        ║")
    lines.append("╚══════════════════════════════════════════════════════════╝")

    let pdfsGenerated = backend.counter("htmltopdf_pdfs_generated_total")?.value ?? 0
    let pdfsFailed = backend.counter("htmltopdf_pdfs_failed_total")?.value ?? 0
    let poolReplacements = backend.counter("htmltopdf_pool_replacements_total")?.value ?? 0

    lines.append("\n📊 Counters:")
    lines.append("  • PDFs Generated: \(pdfsGenerated)")
    lines.append("  • PDFs Failed: \(pdfsFailed)")
    lines.append("  • Pool Replacements: \(poolReplacements)")

    let poolUtil = backend.gauge("htmltopdf_pool_utilization")?.value ?? 0
    let throughput = backend.gauge("htmltopdf_throughput_pdfs_per_sec")?.value ?? 0

    lines.append("\n📏 Gauges:")
    lines.append("  • Pool Utilization: \(Int(poolUtil))")
    lines.append("  • Throughput: \(String(format: "%.0f", throughput)) PDFs/sec")

    if let timer = backend.timer("htmltopdf_render_duration_seconds") {
        lines.append("\n⏱️  Render Duration:")
        lines.append("  • Count: \(timer.values.count)")
        lines.append("  • Average: \(String(format: "%.2f", timer.average * 1000))ms")
        lines.append("  • p50: \(String(format: "%.2f", timer.p50 * 1000))ms")
        lines.append("  • p95: \(String(format: "%.2f", timer.p95 * 1000))ms")
        lines.append("  • p99: \(String(format: "%.2f", timer.p99 * 1000))ms")
    }

    lines.append("\n╚══════════════════════════════════════════════════════════╝")
    return lines.joined(separator: "\n")
}

// MARK: - Dimension Helpers

/// Get metrics grouped by dimension
///
/// Example:
/// ```swift
/// let byMode = await metricsByDimension(
///     label: "htmltopdf_render_duration_seconds",
///     dimension: "mode",
///     in: backend
/// )
/// // Returns: ["continuous": TestTimer, "paginated": TestTimer]
/// ```
public func timersByDimension(
    label: String,
    dimension: String,
    in backend: TestMetricsBackend
) async -> [String: TestTimer] {
    let timers = backend.timers(withLabel: label)
    var result: [String: TestTimer] = [:]

    for timer in timers {
        if let value = timer.dimensions.first(where: { $0.0 == dimension })?.1 {
            result[value] = timer
        }
    }

    return result
}

/// Get counters grouped by dimension
public func countersByDimension(
    label: String,
    dimension: String,
    in backend: TestMetricsBackend
) async -> [String: TestCounter] {
    let counters = backend.counters(withLabel: label)
    var result: [String: TestCounter] = [:]

    for counter in counters {
        if let value = counter.dimensions.first(where: { $0.0 == dimension })?.1 {
            result[value] = counter
        }
    }

    return result
}

// MARK: - Error Types

public enum MetricsTestError: Error, CustomStringConvertible {
    case metricNotFound(label: String)
    case valueMismatch(label: String, expected: String, actual: String)
    case thresholdExceeded(label: String, metric: String, threshold: String, actual: String)

    public var description: String {
        switch self {
        case .metricNotFound(let label):
            return "Metric not found: \(label)"
        case .valueMismatch(let label, let expected, let actual):
            return "Metric '\(label)' value mismatch - expected: \(expected), actual: \(actual)"
        case .thresholdExceeded(let label, let metric, let threshold, let actual):
            return "Metric '\(label)' \(metric) exceeded threshold - threshold: \(threshold), actual: \(actual)"
        }
    }
}


// ========================================
// File: Sources/PDFTestSupport/PDF.Render.Metrics+TestSupport.swift
// ========================================

//
//  PDF.Render.Metrics+TestSupport.swift
//  PDFTestSupport
//
//  Test implementation with in-memory storage
//

import Dependencies
import Foundation
@testable import HtmlToPdfTypes

/// Create test metrics with storage for assertions
public func makeTestMetrics() -> (metrics: PDF.Render.Metrics, storage: TestMetricsStorage) {
    let storage = TestMetricsStorage()

    let metrics = PDF.Render.Metrics(
        incrementPDFsGenerated: { storage.pdfsGenerated += 1 },
        incrementPDFsFailed: { storage.pdfsFailed += 1 },
        incrementPoolReplacements: { storage.poolReplacements += 1 },
        recordRenderDuration: { duration, mode in
            storage.renderDurations.append((duration, mode))
        },
        updatePoolUtilization: { count in storage.poolUtilization = count },
        updateThroughput: { throughput in storage.currentThroughput = throughput }
    )

    return (metrics, storage)
}

/// In-memory storage for test metrics
public final class TestMetricsStorage: @unchecked Sendable {
    private let lock = NSLock()

    private var _pdfsGenerated: Int64 = 0
    private var _pdfsFailed: Int64 = 0
    private var _poolReplacements: Int64 = 0
    private var _renderDurations: [(Duration, PDF.PaginationMode?)] = []
    private var _poolUtilization: Int = 0
    private var _currentThroughput: Double = 0

    public init() {}

    public var pdfsGenerated: Int64 {
        get { lock.withLock { _pdfsGenerated } }
        set { lock.withLock { _pdfsGenerated = newValue } }
    }

    public var pdfsFailed: Int64 {
        get { lock.withLock { _pdfsFailed } }
        set { lock.withLock { _pdfsFailed = newValue } }
    }

    public var poolReplacements: Int64 {
        get { lock.withLock { _poolReplacements } }
        set { lock.withLock { _poolReplacements = newValue } }
    }

    public var renderDurations: [(Duration, PDF.PaginationMode?)] {
        get { lock.withLock { _renderDurations } }
        set { lock.withLock { _renderDurations = newValue } }
    }

    public var poolUtilization: Int {
        get { lock.withLock { _poolUtilization } }
        set { lock.withLock { _poolUtilization = newValue } }
    }

    public var currentThroughput: Double {
        get { lock.withLock { _currentThroughput } }
        set { lock.withLock { _currentThroughput = newValue } }
    }

    // Computed properties
    public var p95Duration: Duration? {
        let durations = renderDurations.map { $0.0 }.sorted()
        guard !durations.isEmpty else { return nil }
        let index = Int(Double(durations.count) * 0.95)
        return durations[min(index, durations.count - 1)]
    }

    public func reset() {
        lock.withLock {
            _pdfsGenerated = 0
            _pdfsFailed = 0
            _poolReplacements = 0
            _renderDurations = []
            _poolUtilization = 0
            _currentThroughput = 0
        }
    }
}


// ========================================
// File: Sources/PDFTestSupport/PDFVerification.swift
// ========================================

//
//  PDFVerification.swift
//  PDFTestSupport
//
//  Basic PDF verification utilities for testing
//

import Foundation

#if canImport(PDFKit)
import PDFKit

/// Verify that a PDF file exists and can be loaded
///
/// Usage:
/// ```swift
/// let url = try await pdf.render.client.html(html, to: output)
/// let doc = try verifyPDFExists(at: url)
/// #expect(doc.pageCount == 1)
/// ```
///
/// - Parameter url: The file URL where the PDF should exist
/// - Returns: A loaded PDFDocument ready for inspection
/// - Throws: TestError if the file doesn't exist or cannot be loaded as a PDF
public func verifyPDFExists(at url: URL) throws -> PDFDocument {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw TestError.pdfNotFound(url)
    }

    guard let doc = PDFDocument(url: url) else {
        throw TestError.cannotLoadPDF(url)
    }

    return doc
}

/// Test errors for PDF verification
public enum TestError: Error, CustomStringConvertible {
    case pdfNotFound(URL)
    case cannotLoadPDF(URL)

    public var description: String {
        switch self {
        case .pdfNotFound(let url):
            return "PDF not found at: \(url.path)"
        case .cannotLoadPDF(let url):
            return "Cannot load PDF at: \(url.path)"
        }
    }
}

#endif


// ========================================
// File: Sources/PDFTestSupport/TestCSS.swift
// ========================================

//
//  TestCSS.swift
//  PDFTestSupport
//
//  Reusable CSS styles for PDF testing
//

import Foundation

/// Common CSS styles for visual verification tests
public enum TestCSS {
    /// Modern document styling with gradients, sections, and responsive layout
    public static let modern = """
    body {
        font-family: 'Helvetica Neue', Arial, sans-serif;
        padding: 30px;
        line-height: 1.6;
        color: #333;
    }
    .header {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 30px;
        text-align: center;
        border-radius: 8px;
        margin-bottom: 20px;
    }
    .header h1 {
        margin: 0;
        font-size: 32px;
    }
    .section {
        margin: 20px 0;
        padding: 20px;
        background: #f8f9fa;
        border-left: 4px solid #667eea;
        border-radius: 4px;
    }
    .section h2 {
        margin-top: 0;
        color: #667eea;
    }
    code {
        background: #f4f4f4;
        padding: 2px 6px;
        border-radius: 3px;
        font-family: 'Monaco', monospace;
        color: #e83e8c;
    }
    .warning {
        background: #fff3cd;
        border-left-color: #ffc107;
        color: #856404;
    }
    .success {
        background: #d4edda;
        border-left-color: #28a745;
        color: #155724;
    }
    .footer {
        margin-top: 30px;
        padding: 20px;
        text-align: center;
        color: #6c757d;
        border-top: 2px solid #e9ecef;
    }
    """

    /// Rich verification CSS with tables, grids, and complex layouts
    public static let richVerification = """
    body {
        font-family: 'Helvetica Neue', Arial, sans-serif;
        line-height: 1.6;
        color: #333;
    }
    .header {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 40px;
        text-align: center;
        border-radius: 8px;
        margin-bottom: 30px;
    }
    .header h1 {
        margin: 0;
        font-size: 48px;
        font-weight: bold;
    }
    .header p {
        margin: 10px 0 0 0;
        font-size: 18px;
        opacity: 0.9;
    }
    .section {
        margin: 30px 0;
        padding: 20px;
        background: #f8f9fa;
        border-left: 4px solid #667eea;
        border-radius: 4px;
    }
    .section h2 {
        margin-top: 0;
        color: #667eea;
    }
    .feature-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 20px;
        margin: 20px 0;
    }
    .feature {
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .feature h3 {
        margin-top: 0;
        color: #764ba2;
    }
    table {
        width: 100%;
        border-collapse: collapse;
        margin: 20px 0;
        background: white;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    th {
        background: #667eea;
        color: white;
        padding: 12px;
        text-align: left;
    }
    td {
        padding: 12px;
        border-bottom: 1px solid #e9ecef;
    }
    tr:hover {
        background: #f8f9fa;
    }
    code {
        background: #f4f4f4;
        padding: 2px 6px;
        border-radius: 3px;
        font-family: 'Monaco', 'Courier New', monospace;
        color: #e83e8c;
    }
    .footer {
        margin-top: 40px;
        padding: 20px;
        text-align: center;
        color: #6c757d;
        border-top: 2px solid #e9ecef;
    }
    """
}


// ========================================
// File: Sources/PDFTestSupport/TestHTML.swift
// ========================================

//
//  TestHTML.swift
//  PDFTestSupport
//
//  Common HTML fixtures for PDF testing
//

import Foundation

/// Pre-built HTML fixtures for common test scenarios
///
/// Provides consistent HTML test data across test suites, reducing duplication
/// and ensuring tests use well-formed, predictable content.
public enum TestHTML {
    /// Minimal valid HTML document
    public static let minimal = "<html><body></body></html>"

    /// Simple single-page content with heading and paragraph
    public static let simple = """
    <html>
        <head><meta charset="UTF-8"></head>
        <body>
            <h1>Hello, World!</h1>
            <p>This is a test document.</p>
        </body>
    </html>
    """

    /// Generate HTML with multiple items for pagination testing
    ///
    /// Creates a document with the specified number of styled items,
    /// useful for testing multi-page rendering and pagination behavior.
    ///
    /// - Parameter count: Number of items to generate
    /// - Returns: HTML string with styled item divs
    public static func items(_ count: Int) -> String {
        let items = (1...count).map { i in
            """
            <div style="padding: 15px; margin: 10px 0; background: #f5f5f5; border-radius: 4px;">
                <h3>Item \(i)</h3>
                <p>Test content for item number \(i). This text helps verify that content flows correctly across pages.</p>
            </div>
            """
        }.joined(separator: "\n")

        return """
        <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    body {
                        font-family: Arial, sans-serif;
                        line-height: 1.6;
                        margin: 20px;
                    }
                </style>
            </head>
            <body>
                \(items)
            </body>
        </html>
        """
    }

    /// Rich formatting test with CSS, gradients, and tables
    public static let richFormatting = """
    <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: 'Helvetica Neue', Arial, sans-serif;
                    margin: 0;
                    padding: 0;
                }
                .header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 20px;
                    text-align: center;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 20px 0;
                }
                th {
                    background: #667eea;
                    color: white;
                    padding: 10px;
                    text-align: left;
                }
                td {
                    padding: 10px;
                    border-bottom: 1px solid #ddd;
                }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>Rich Formatting Test</h1>
            </div>
            <table>
                <tr><th>Column 1</th><th>Column 2</th></tr>
                <tr><td>Data 1</td><td>Data 2</td></tr>
                <tr><td>Data 3</td><td>Data 4</td></tr>
            </table>
        </body>
    </html>
    """

    /// Unicode and emoji test content
    public static let unicode = """
    <html>
        <head><meta charset="UTF-8"></head>
        <body>
            <h1>Unicode Test</h1>
            <p>Emoji: 🎉 🚀 ✨ 💡 🔥 ⚡️</p>
            <p>Math: α β γ δ ∑ ∫ √ ∞ ≈ ≠</p>
            <p>Currency: $ € £ ¥ ₹ ₿</p>
            <p>Accents: café, naïve, résumé, façade</p>
        </body>
    </html>
    """

    /// Build custom HTML with title, body content, and optional CSS
    ///
    /// - Parameters:
    ///   - title: Document title (default: "Test Document")
    ///   - body: HTML body content
    ///   - css: Optional CSS styles
    /// - Returns: Complete HTML document string
    public static func custom(
        title: String = "Test Document",
        body: String,
        css: String = ""
    ) -> String {
        """
        <html>
            <head>
                <meta charset="UTF-8">
                <title>\(title)</title>
                <style>\(css)</style>
            </head>
            <body>
                \(body)
            </body>
        </html>
        """
    }
}


// ========================================
// File: Sources/PDFTestSupport/TestImages.swift
// ========================================

//
//  TestImages.swift
//  PDFTestSupport
//
//  Image loading utilities for PDF testing
//

import Foundation

/// Test image utilities for loading and encoding test images
public enum TestImages {
    /// Load an image from the test bundle and encode as base64
    ///
    /// Usage:
    /// ```swift
    /// // In test file with Bundle.module:
    /// let base64PNG = try TestImages.loadBase64(named: "coenttb", extension: "png", from: .module)
    /// let html = #"<img src="data:image/png;base64,\#(base64PNG)">"#
    /// ```
    ///
    /// - Parameters:
    ///   - name: Image filename without extension
    ///   - ext: File extension (e.g., "png", "jpg")
    ///   - bundle: Bundle containing the resource (must be provided by caller)
    /// - Returns: Base64-encoded string of the image data
    /// - Throws: Error if image resource not found
    public static func loadBase64(
        named name: String,
        extension ext: String,
        from bundle: Bundle
    ) throws -> String {
        guard let imageURL = bundle.url(forResource: name, withExtension: ext) else {
            throw TestError.resourceNotFound(name: "\(name).\(ext)")
        }
        let imageData = try Data(contentsOf: imageURL)
        return imageData.base64EncodedString()
    }

    /// Common SVG test images encoded as base64
    public enum SVG {
        /// Red 50x50px square
        public static let redSquare = "PHN2ZyB3aWR0aD0iNTAiIGhlaWdodD0iNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHJlY3Qgd2lkdGg9IjUwIiBoZWlnaHQ9IjUwIiBmaWxsPSIjZmYwMDAwIi8+PC9zdmc+"

        /// Green 50x50px square
        public static let greenSquare = "PHN2ZyB3aWR0aD0iNTAiIGhlaWdodD0iNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHJlY3Qgd2lkdGg9IjUwIiBoZWlnaHQ9IjUwIiBmaWxsPSIjMDBmZjAwIi8+PC9zdmc+"

        /// Blue 50x50px square
        public static let blueSquare = "PHN2ZyB3aWR0aD0iNTAiIGhlaWdodD0iNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHJlY3Qgd2lkdGg9IjUwIiBoZWlnaHQ9IjUwIiBmaWxsPSIjMDAwMGZmIi8+PC9zdmc+"
    }

    public enum TestError: Error, CustomStringConvertible {
        case resourceNotFound(name: String)

        public var description: String {
            switch self {
            case .resourceNotFound(let name):
                return "Test resource not found: \(name)"
            }
        }
    }
}


// ========================================
// File: Sources/PDFTestSupport/TestMetricsBackend.swift
// ========================================

//
//  TestMetricsBackend.swift
//  PDFTestSupport
//
//  Test-specific metrics backend for capturing and asserting on metrics
//

import Foundation
import Metrics
@testable import CoreMetrics  // Access internal bootstrapInternal for testing
import Dependencies

/// Test metrics backend that captures all recorded metrics for testing
///
/// Use this to validate that metrics are actually being recorded during tests:
///
/// ```swift
/// let metricsBackend = TestMetricsBackend()
/// MetricsSystem.bootstrap(metricsBackend)
///
/// // Run your test code that generates metrics
/// try await pdf.render.client.html(htmls, to: output)
///
/// // Assert on captured metrics
/// #expect(metricsBackend.counters["htmltopdf_pdfs_generated_total"]?.value == 100)
/// #expect(metricsBackend.timers["htmltopdf_render_duration_seconds"]?.p95 < 0.1)
/// ```
public final class TestMetricsBackend: MetricsFactory, @unchecked Sendable {

    // MARK: - Captured Metrics

    private let lock = NSLock()
    private var _counters: [String: TestCounter] = [:]
    private var _meters: [String: TestMeter] = [:]
    private var _timers: [String: TestTimer] = [:]
    private var _recorders: [String: TestRecorder] = [:]

    public var counters: [String: TestCounter] {
        lock.withLock { _counters }
    }

    public var meters: [String: TestMeter] {
        lock.withLock { _meters }
    }

    public var timers: [String: TestTimer] {
        lock.withLock { _timers }
    }

    public var recorders: [String: TestRecorder] {
        lock.withLock { _recorders }
    }

    public init() {}

    // MARK: - MetricsFactory Implementation

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        lock.withLock {
            let key = makeKey(label: label, dimensions: dimensions)
            if let existing = _counters[key] {
                return existing
            }
            let counter = TestCounter(label: label, dimensions: dimensions)
            _counters[key] = counter
            return counter
        }
    }

    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler {
        lock.withLock {
            let key = makeKey(label: label, dimensions: dimensions)
            if let existing = _counters[key] {
                return existing
            }
            let counter = TestCounter(label: label, dimensions: dimensions)
            _counters[key] = counter
            return counter
        }
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        lock.withLock {
            let key = makeKey(label: label, dimensions: dimensions)
            if let existing = _meters[key] {
                return existing
            }
            let meter = TestMeter(label: label, dimensions: dimensions)
            _meters[key] = meter
            return meter
        }
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        lock.withLock {
            let key = makeKey(label: label, dimensions: dimensions)
            if let existing = _timers[key] {
                return existing
            }
            let timer = TestTimer(label: label, dimensions: dimensions)
            _timers[key] = timer
            return timer
        }
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        lock.withLock {
            let key = makeKey(label: label, dimensions: dimensions)
            if let existing = _recorders[key] {
                return existing
            }
            let recorder = TestRecorder(label: label, dimensions: dimensions)
            _recorders[key] = recorder
            return recorder
        }
    }

    public func destroyCounter(_ handler: CounterHandler) {
        lock.withLock {
            if let testCounter = handler as? TestCounter {
                _counters.removeValue(forKey: testCounter.key)
            }
        }
    }

    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {
        lock.withLock {
            if let testCounter = handler as? TestCounter {
                _counters.removeValue(forKey: testCounter.key)
            }
        }
    }

    public func destroyMeter(_ handler: MeterHandler) {
        lock.withLock {
            if let testMeter = handler as? TestMeter {
                _meters.removeValue(forKey: testMeter.key)
            }
        }
    }

    public func destroyTimer(_ handler: TimerHandler) {
        lock.withLock {
            if let testTimer = handler as? TestTimer {
                _timers.removeValue(forKey: testTimer.key)
            }
        }
    }

    public func destroyRecorder(_ handler: RecorderHandler) {
        lock.withLock {
            if let testRecorder = handler as? TestRecorder {
                _recorders.removeValue(forKey: testRecorder.key)
            }
        }
    }

    // MARK: - Test Utilities

    /// Reset all captured metrics
    public func reset() {
        lock.withLock {
            _counters.removeAll()
            _meters.removeAll()
            _timers.removeAll()
            _recorders.removeAll()
        }
    }

    /// Get counter by label (without dimensions)
    public func counter(_ label: String) -> TestCounter? {
        lock.withLock { _counters[label] }
    }

    /// Get gauge by label (without dimensions)
    /// Note: In swift-metrics, Gauge is implemented as a Recorder
    public func gauge(_ label: String) -> TestRecorder? {
        lock.withLock { _recorders[label] }
    }

    /// Get meter by label (without dimensions)
    public func meter(_ label: String) -> TestMeter? {
        lock.withLock { _meters[label] }
    }

    /// Get timer by label (without dimensions)
    public func timer(_ label: String) -> TestTimer? {
        lock.withLock { _timers[label] }
    }

    /// Get all counters with a specific label (across all dimensions)
    public func counters(withLabel label: String) -> [TestCounter] {
        lock.withLock { _counters.values.filter { $0.label == label } }
    }

    /// Get all timers with a specific label (across all dimensions)
    public func timers(withLabel label: String) -> [TestTimer] {
        lock.withLock { _timers.values.filter { $0.label == label } }
    }

    /// Print summary of all captured metrics
    public func printSummary() {
        lock.withLock {
            print("\n╔══════════════════════════════════════════════════════════╗")
            print("║              TEST METRICS SUMMARY                        ║")
            print("╚══════════════════════════════════════════════════════════╝")

            if !_counters.isEmpty {
                print("\n📊 Counters:")
                for (_, counter) in _counters.sorted(by: { $0.key < $1.key }) {
                    let dims = counter.dimensions.isEmpty ? "" : " (\(formatDimensions(counter.dimensions)))"
                    print("  • \(counter.label)\(dims): \(counter.value)")
                }
            }

            if !_meters.isEmpty {
                print("\n📏 Meters/Gauges:")
                for (_, meter) in _meters.sorted(by: { $0.key < $1.key }) {
                    let dims = meter.dimensions.isEmpty ? "" : " (\(formatDimensions(meter.dimensions)))"
                    print("  • \(meter.label)\(dims): \(meter.value)")
                }
            }

            if !_timers.isEmpty {
                print("\n⏱️  Timers:")
                for (_, timer) in _timers.sorted(by: { $0.key < $1.key }) {
                    let dims = timer.dimensions.isEmpty ? "" : " (\(formatDimensions(timer.dimensions)))"
                    print("  • \(timer.label)\(dims):")
                    print("      count: \(timer.values.count)")
                    if !timer.values.isEmpty {
                        print("      p50: \(String(format: "%.3f", timer.p50 * 1000))ms")
                        print("      p95: \(String(format: "%.3f", timer.p95 * 1000))ms")
                        print("      p99: \(String(format: "%.3f", timer.p99 * 1000))ms")
                    }
                }
            }

            print("\n╚══════════════════════════════════════════════════════════╝\n")
        }
    }

    // MARK: - Private Helpers

    private func makeKey(label: String, dimensions: [(String, String)]) -> String {
        if dimensions.isEmpty {
            return label
        }
        let dimStr = dimensions.sorted(by: { $0.0 < $1.0 })
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: ",")
        return "\(label){\(dimStr)}"
    }

    private func formatDimensions(_ dimensions: [(String, String)]) -> String {
        dimensions.map { "\($0.0)=\($0.1)" }.joined(separator: ", ")
    }
}

// MARK: - Test Metric Handlers

public final class TestCounter: CounterHandler, FloatingPointCounterHandler, @unchecked Sendable {
    public let label: String
    public let dimensions: [(String, String)]
    fileprivate let key: String

    private let lock = NSLock()
    private var _value: Int64 = 0

    public var value: Int64 {
        lock.withLock { _value }
    }

    init(label: String, dimensions: [(String, String)]) {
        self.label = label
        self.dimensions = dimensions
        self.key = dimensions.isEmpty ? label :
            "\(label){\(dimensions.sorted(by: { $0.0 < $1.0 }).map { "\($0.0)=\($0.1)" }.joined(separator: ","))}"
    }

    public func increment(by amount: Int64) {
        lock.withLock {
            _value += amount
        }
    }

    public func increment(by amount: Double) {
        lock.withLock {
            _value += Int64(amount)
        }
    }

    public func reset() {
        lock.withLock {
            _value = 0
        }
    }
}

public final class TestMeter: MeterHandler, @unchecked Sendable {
    public let label: String
    public let dimensions: [(String, String)]
    fileprivate let key: String

    private let lock = NSLock()
    private var _value: Double = 0

    public var value: Double {
        lock.withLock { _value }
    }

    init(label: String, dimensions: [(String, String)]) {
        self.label = label
        self.dimensions = dimensions
        self.key = dimensions.isEmpty ? label :
            "\(label){\(dimensions.sorted(by: { $0.0 < $1.0 }).map { "\($0.0)=\($0.1)" }.joined(separator: ","))}"
    }

    public func set(_ value: Int64) {
        lock.withLock {
            _value = Double(value)
        }
    }

    public func set(_ value: Double) {
        lock.withLock {
            _value = value
        }
    }

    public func increment(by amount: Double) {
        lock.withLock {
            _value += amount
        }
    }

    public func decrement(by amount: Double) {
        lock.withLock {
            _value -= amount
        }
    }
}

public final class TestTimer: TimerHandler, @unchecked Sendable {
    public let label: String
    public let dimensions: [(String, String)]
    fileprivate let key: String

    private let lock = NSLock()
    private var _values: [Int64] = []

    public var values: [Int64] {
        lock.withLock { _values }
    }

    /// Average duration in seconds
    public var average: TimeInterval {
        let vals = values
        guard !vals.isEmpty else { return 0 }
        let sum = vals.reduce(0, +)
        return TimeInterval(sum) / TimeInterval(vals.count) / 1_000_000_000
    }

    /// Minimum duration in seconds
    public var min: TimeInterval {
        guard let minVal = values.min() else { return 0 }
        return TimeInterval(minVal) / 1_000_000_000
    }

    /// Maximum duration in seconds
    public var max: TimeInterval {
        guard let maxVal = values.max() else { return 0 }
        return TimeInterval(maxVal) / 1_000_000_000
    }

    /// 50th percentile (median) in seconds
    public var p50: TimeInterval {
        percentile(0.50)
    }

    /// 95th percentile in seconds
    public var p95: TimeInterval {
        percentile(0.95)
    }

    /// 99th percentile in seconds
    public var p99: TimeInterval {
        percentile(0.99)
    }

    init(label: String, dimensions: [(String, String)]) {
        self.label = label
        self.dimensions = dimensions
        self.key = dimensions.isEmpty ? label :
            "\(label){\(dimensions.sorted(by: { $0.0 < $1.0 }).map { "\($0.0)=\($0.1)" }.joined(separator: ","))}"
    }

    public func recordNanoseconds(_ duration: Int64) {
        lock.withLock {
            _values.append(duration)
        }
    }

    private func percentile(_ p: Double) -> TimeInterval {
        let vals = values.sorted()
        guard !vals.isEmpty else { return 0 }
        let index = Int(Double(vals.count) * p)
        let clampedIndex = Swift.min(index, vals.count - 1)
        return TimeInterval(vals[clampedIndex]) / 1_000_000_000
    }
}

public final class TestRecorder: RecorderHandler, @unchecked Sendable {
    public let label: String
    public let dimensions: [(String, String)]
    fileprivate let key: String

    private let lock = NSLock()
    private var _values: [Double] = []

    public var values: [Double] {
        lock.withLock { _values }
    }

    /// Current value (for gauge-like usage, returns last recorded value)
    public var value: Double {
        lock.withLock { _values.last ?? 0 }
    }

    init(label: String, dimensions: [(String, String)]) {
        self.label = label
        self.dimensions = dimensions
        self.key = dimensions.isEmpty ? label :
            "\(label){\(dimensions.sorted(by: { $0.0 < $1.0 }).map { "\($0.0)=\($0.1)" }.joined(separator: ","))}"
    }

    public func record(_ value: Int64) {
        lock.withLock {
            _values.append(Double(value))
        }
    }

    public func record(_ value: Double) {
        lock.withLock {
            _values.append(value)
        }
    }
}

// MARK: - Direct Usage (for tests that don't use Dependencies)

extension TestMetricsBackend {
    /// Create and bootstrap a test backend for direct use
    ///
    /// Use this when you need a standalone metrics backend for testing,
    /// outside of the Dependencies framework:
    ///
    /// ```swift
    /// let backend = TestMetricsBackend.forTest()
    /// // Metrics are now captured in this backend
    /// #expect(backend.counter("my_counter")?.value == 1)
    /// ```
    ///
    /// **Note**: For testing with Dependencies, use `@Dependency(\.pdf).render.metrics.testBackend` instead.
    public static func forTest() -> TestMetricsBackend {
        let backend = TestMetricsBackend()
        MetricsSystem.bootstrapInternal(backend)
        return backend
    }
}

// MARK: - Note on Test Isolation with Dependencies
//
// TestMetricsBackend is NOT exposed as a standalone dependency key.
// Instead, it's embedded within PDF.Render.Metrics.testValue.
//
// This ensures the same backend instance used for recording metrics
// is the one tests inspect, solving the "separate instances" problem
// that occurs with Swift 6.2+ where testValue is evaluated once globally.


// ========================================
// File: Sources/PDFTestSupport/TestUtilities.swift
// ========================================

//
//  TestUtilities.swift
//  PDFTestSupport
//
//  Common test utilities and extensions
//

import Foundation
import Testing

// MARK: - URL Extensions

extension URL {
    /// Generate a temporary output URL for test PDFs
    public static func output(id: UUID = UUID()) -> Self {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("html-to-pdf")
            .appendingPathComponent(id.uuidString)
    }

    /// Local HtmlToPdf directory (platform-aware)
    public static var localHtmlToPdf: Self {
        #if os(macOS)
        return URL.documentsDirectory.appendingPathComponent("HtmlToPdf")
        #else
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths.first!.appendingPathComponent("HtmlToPdf")
        #endif
    }
}

// MARK: - FileManager Extensions

extension FileManager {
    /// Remove all items within a directory
    public func removeItems(at url: URL) throws {
        let fileURLs = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        for fileURL in fileURLs {
            try removeItem(at: fileURL)
        }
    }

    /// Clean up any leftover test directories from interrupted tests
    ///
    /// This is useful when tests timeout or are interrupted before cleanup can run
    public static func cleanupTestDirectories() {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("html-to-pdf")

        guard fm.fileExists(atPath: tempDir.path) else { return }

        do {
            let subdirs = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            print("🧹 Cleaning up \(subdirs.count) leftover test directories...")

            for subdir in subdirs {
                try? fm.removeItem(at: subdir)
            }

            try? fm.removeItem(at: tempDir)
            print("✅ Cleanup complete")
        } catch {
            print("⚠️ Cleanup failed: \(error)")
        }
    }
}

// MARK: - AsyncStream Extensions

extension AsyncStream<URL> {
    /// Test that yielded URLs exist on the file system
    public func testIfYieldedUrlExistsOnFileSystem(directory: URL) async throws {
        for await url in self {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).map(\.lastPathComponent)
            #expect(contents.contains(where: { $0 == url.lastPathComponent }))
        }
    }
}

extension AsyncThrowingStream<URL, Error> {
    /// Test that yielded URLs exist on the file system
    public func testIfYieldedUrlExistsOnFileSystem(directory: URL) async throws {
        for try await url in self {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).map(\.lastPathComponent)
            #expect(contents.contains(where: { $0 == url.lastPathComponent }))
        }
    }
}


// ========================================
// File: Sources/PDFTestSupport/iOSPrintFormatterRenderer.swift
// ========================================

//
//  iOSPrintFormatterRenderer.swift
//  PDFTestSupport
//
//  Direct UIMarkupTextPrintFormatter rendering for testing iOS capabilities
//

#if canImport(UIKit)
import UIKit
import Foundation

/// Render HTML directly using UIMarkupTextPrintFormatter for testing
///
/// This bypasses the library's automatic routing logic to test the
/// capabilities and limitations of UIMarkupTextPrintFormatter in isolation.
///
/// **Known limitation**: UIMarkupTextPrintFormatter cannot render images.
/// This was verified through testing - `<img>` tags in HTML are ignored.
///
/// Usage:
/// ```swift
/// let html = "<html><body><h1>Test</h1></body></html>"
/// let url = try await iOSPrintFormatterRenderer.renderPDF(
///     html: html,
///     to: outputURL
/// )
/// ```
@MainActor
public enum iOSPrintFormatterRenderer {
    /// Render HTML to PDF using UIMarkupTextPrintFormatter
    ///
    /// - Parameters:
    ///   - html: HTML string to render
    ///   - destination: Output file URL for the PDF
    ///   - paperSize: Paper dimensions (default: A4)
    ///   - margins: Page margins in points (default: 36pt all sides)
    /// - Returns: Time taken to render in seconds
    /// - Throws: Error if rendering or file writing fails
    @discardableResult
    public static func renderPDF(
        html: String,
        to destination: URL,
        paperSize: CGSize = CGSize(width: 595.28, height: 841.89), // A4
        margins: UIEdgeInsets = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)
    ) throws -> TimeInterval {
        let start = Date()

        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let paperRect = CGRect(origin: .zero, size: paperSize)
        let printableRect = CGRect(
            x: margins.left,
            y: margins.top,
            width: paperSize.width - margins.left - margins.right,
            height: paperSize.height - margins.top - margins.bottom
        )

        renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))

        let bounds = UIGraphicsGetPDFContextBounds()
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: bounds)
        }
        UIGraphicsEndPDFContext()

        try (pdfData as Data).write(to: destination)

        return Date().timeIntervalSince(start)
    }
}
#endif


// ========================================
// File: Sources/PDFTestSupport/withTemporaryDirectory.swift
// ========================================

//
//  TestOutput.swift
//  PDFTestSupport
//
//  Automatic cleanup for PDF test files with parallel test execution support
//

import Foundation

/// Provides a temporary directory for test output with automatic cleanup
///
/// Creates a unique temporary directory, executes the closure with that directory,
/// and automatically removes it when done. Safe for parallel test execution.
///
/// Usage:
/// ```swift
/// try await withTemporaryDirectory { outputDir in
///     let url = try await pdf.render.client.html(
///         TestHTML.simple,
///         to: outputDir.appendingPathComponent("test.pdf")
///     )
///     // Directory is automatically cleaned up when scope exits
/// }
/// ```
public func withTemporaryDirectory<T>(
    id: UUID = UUID(),
    _ body: (URL) async throws -> T
) async rethrows -> T {
    let output = FileManager.default.temporaryDirectory
        .appendingPathComponent("html-to-pdf")
        .appendingPathComponent(id.uuidString)

    try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: output)
    }

    return try await body(output)
}

/// Synchronous variant for non-async tests
public func withTemporaryDirectory<T>(
    id: UUID = UUID(),
    _ body: (URL) throws -> T
) rethrows -> T {
    let output = FileManager.default.temporaryDirectory
        .appendingPathComponent("html-to-pdf")
        .appendingPathComponent(id.uuidString)

    try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: output)
    }

    return try body(output)
}

/// Provides a temporary PDF file URL with automatic cleanup
///
/// Creates a unique temporary file URL based on the calling location,
/// cleans up the entire directory when done. Safe for parallel test execution.
///
/// Usage:
/// ```swift
/// try await withTemporaryPDF { output in
///     let url = try await pdf.render.client.html(TestHTML.simple, to: output)
///     #expect(FileManager.default.fileExists(atPath: url.path))
/// }
/// ```
public func withTemporaryPDF<T>(
    fileID: String = #fileID,
    line: Int = #line,
    _ body: (URL) async throws -> T
) async rethrows -> T {
    let dirID = UUID()
    let outputDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("html-to-pdf")
        .appendingPathComponent(dirID.uuidString)

    // Extract test name from fileID (e.g., "HtmlToPdfTests/BasicFunctionalityTests.swift")
    let fileName = fileID.split(separator: "/").last?.replacingOccurrences(of: ".swift", with: "") ?? "test"
    let uniqueName = "\(fileName)-L\(line).pdf"
    let output = outputDir.appendingPathComponent(uniqueName)

    try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: outputDir)
    }

    return try await body(output)
}

/// Synchronous variant for non-async tests
public func withTemporaryPDF<T>(
    fileID: String = #fileID,
    line: Int = #line,
    _ body: (URL) throws -> T
) rethrows -> T {
    let dirID = UUID()
    let outputDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("html-to-pdf")
        .appendingPathComponent(dirID.uuidString)

    // Extract test name from fileID
    let fileName = fileID.split(separator: "/").last?.replacingOccurrences(of: ".swift", with: "") ?? "test"
    let uniqueName = "\(fileName)-L\(line).pdf"
    let output = outputDir.appendingPathComponent(uniqueName)

    try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: outputDir)
    }

    return try body(output)
}

/// Helper to generate unique PDF filename based on caller location
///
/// Creates a filename like "BasicFunctionalityTests-testSinglePDFGeneration-L42.pdf"
/// Safe for parallel execution as each test gets a unique filename.
///
/// Usage:
/// ```swift
/// try await withTemporaryDirectory { outputDir in
///     let url = try await pdf.render.client.html(
///         TestHTML.simple,
///         to: outputDir.pdfPath()
///     )
/// }
/// ```
public extension URL {
    func pdfPath(
        fileID: String = #fileID,
        line: Int = #line
    ) -> URL {
        // Extract test name from fileID (e.g., "HtmlToPdfTests/BasicFunctionalityTests.swift")
        let fileName = fileID.split(separator: "/").last?.replacingOccurrences(of: ".swift", with: "") ?? "test"
        let uniqueName = "\(fileName)-L\(line).pdf"
        return self.appendingPathComponent(uniqueName)
    }
}

/// Clean up all leftover test directories from interrupted tests
///
/// This is useful for CI cleanup or manual maintenance when tests are killed
/// before cleanup can run. Call this at the start of test suites if desired.
public func cleanupAllTestOutputs() {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent("html-to-pdf")

    guard fm.fileExists(atPath: tempDir.path) else { return }

    do {
        let subdirs = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)

        for subdir in subdirs {
            try? fm.removeItem(at: subdir)
        }

        try? fm.removeItem(at: tempDir)
    } catch {
        // Silently fail - this is a cleanup utility
    }
}


