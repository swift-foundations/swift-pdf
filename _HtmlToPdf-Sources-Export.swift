// ============================================
// File: Sources/HtmlToPdf/PDF+Convenience.swift
// ============================================

//
//  PDF+Convenience.swift
//  swift-html-to-pdf
//
//  Top-level convenience methods for common operations
//

import Foundation
import PointFreeHTML

extension PDF {

    // MARK: - Render Operations

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
    public func render<H: HTML>(
        html: H,
        to destination: URL
    ) async throws -> URL {
        let document = PDF.Document(html: html, destination: destination)
        return try await render.document(document)
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
    public func render<H: HTML>(
        html: H
    ) async throws -> Data {
        let htmlString = String(decoding: html.render(), as: UTF8.self)
        return try await render.data(htmlString)
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

}


// ============================================
// File: Sources/HtmlToPdf/PDF.Capabilities.swift
// ============================================

//
//  PDF.Capabilities.swift
//  swift-html-to-pdf
//
//  Platform capabilities for PDF rendering
//

import Foundation

extension PDF {
    /// Platform-specific capabilities
    public struct Capabilities: Sendable {
        /// Whether this platform supports WebView pooling for performance
        public let supportsWebViewPooling: Bool

        /// Whether this platform supports background rendering
        public let supportsBackgroundRendering: Bool

        /// Whether this platform supports custom fonts
        public let supportsCustomFonts: Bool

        /// Maximum recommended concurrent operations for this platform
        public let maxConcurrentOperations: Int

        public init(
            supportsWebViewPooling: Bool,
            supportsBackgroundRendering: Bool,
            supportsCustomFonts: Bool,
            maxConcurrentOperations: Int
        ) {
            self.supportsWebViewPooling = supportsWebViewPooling
            self.supportsBackgroundRendering = supportsBackgroundRendering
            self.supportsCustomFonts = supportsCustomFonts
            self.maxConcurrentOperations = maxConcurrentOperations
        }
    }
}

// MARK: - Platform Presets

extension PDF.Capabilities {
    /// macOS capabilities
    public static let macOS = PDF.Capabilities(
        supportsWebViewPooling: true,
        supportsBackgroundRendering: true,
        supportsCustomFonts: true,
        maxConcurrentOperations: 16
    )

    /// iOS capabilities
    public static let iOS = PDF.Capabilities(
        supportsWebViewPooling: true,
        supportsBackgroundRendering: false,
        supportsCustomFonts: true,
        maxConcurrentOperations: 8
    )

    /// Linux capabilities (future)
    public static let linux = PDF.Capabilities(
        supportsWebViewPooling: false,
        supportsBackgroundRendering: true,
        supportsCustomFonts: true,
        maxConcurrentOperations: 32
    )

    /// Mock/test capabilities
    public static let mock = PDF.Capabilities(
        supportsWebViewPooling: false,
        supportsBackgroundRendering: false,
        supportsCustomFonts: false,
        maxConcurrentOperations: 1
    )
}


// ============================================
// File: Sources/HtmlToPdf/PDF.ConcurrencyStrategy.swift
// ============================================

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
            return max(2, min(cpuCount, 4))
            #else
            // macOS/Linux: Use 3x CPU count for optimal throughput
            // WebViews spend significant time in I/O, so oversubscription helps
            return max(2, cpuCount * 3)
            #endif
        }

        /// Resolve to concrete concurrency value
        internal var resolved: Int {
            switch mode {
            case .fixed(let value):
                return max(1, value)
            case .automatic:
                return Self.calculateDefaultConcurrency()
            }
        }
    }
}


// ============================================
// File: Sources/HtmlToPdf/PDF.Configuration.swift
// ============================================

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

        /// Timeout per document (nil = no timeout)
        public var documentTimeout: Duration?

        /// Timeout for entire batch (nil = no timeout)
        public var batchTimeout: Duration?

        /// Timeout for acquiring WebView from pool
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
            documentTimeout: Duration? = nil,
            batchTimeout: Duration? = nil,
            webViewAcquisitionTimeout: Duration = .seconds(300),
            createDirectories: Bool = true,
            namingStrategy: NamingStrategy = .sequential
        ) {
            self.paperSize = paperSize
            self.margins = margins
            self.baseURL = baseURL
            self.paginationMode = paginationMode
            self.concurrency = concurrency
            self.adaptiveThroughputOptimization = adaptiveThroughputOptimization
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
            webViewAcquisitionTimeout: .seconds(300)
        )
    }
}

// MARK: - Dependency Registration

extension PDF.Configuration: TestDependencyKey {
    public static let testValue = PDF.Configuration.default
}

// Note: PDF.Configuration is now accessed via \.pdf.configuration
// The PDF struct (in PDF.swift) handles the main dependency registration


// ============================================
// File: Sources/HtmlToPdf/PDF.Document.swift
// ============================================

//
//  PDF.Document.swift
//  swift-html-to-pdf
//
//  Document model for PDF rendering
//

import Foundation
import PointFreeHTML

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
    /// // Using PointFree HTML DSL (type-safe)
    /// struct MyPage: HTMLDocumentProtocol {
    ///     var head: some HTML { title { "My PDF" } }
    ///     var body: some HTML { h1 { "Hello, World!" } }
    /// }
    /// let doc = PDF.Document(html: MyPage(), destination: fileURL)
    ///
    /// // Using String (simple)
    /// let doc = PDF.Document(htmlString: "<html><body>Hello</body></html>", destination: fileURL)
    ///
    /// // Using raw bytes (advanced)
    /// let doc = PDF.Document(htmlBytes: bytes, destination: fileURL)
    /// ```
    public struct Document: Sendable {
        let htmlBytes: ContiguousArray<UInt8>
        public let destination: URL

        // MARK: - Primary Initializers (HTML protocol)

        /// Create a document from any HTML-conforming type
        public init<H: HTML>(html: H, destination: URL) {
            self.htmlBytes = html.render()
            self.destination = destination
        }

        public init<H: HTML>(html: H, title: String, in directory: URL) {
            self.htmlBytes = html.render()
            self.destination = directory
                .appendingPathComponent(title.replacingSlashesWithDivisionSlash())
                .appendingPathExtension("pdf")
        }

        // MARK: - Convenience Initializers

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
        var html: ContiguousArray<UInt8> { htmlBytes }
    }
}

// MARK: - String Utilities

extension String {
    func replacingSlashesWithDivisionSlash() -> String {
        let divisionSlash = "\u{2215}" // Unicode for Division Slash (∕)
        return self.replacingOccurrences(of: "/", with: divisionSlash)
    }
}

// MARK: - ContiguousArray Utilities

extension ContiguousArray where Element == UInt8 {
    /// Injects CSS bytes into HTML with caching for repeated injections
    ///
    /// This method caches the result to avoid redundant work when the same HTML+CSS
    /// combination is processed multiple times (common in batch operations).
    func injectingCSS(_ cssBytes: ContiguousArray<UInt8>) async -> ContiguousArray<UInt8> {
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
    func toData() -> Data {
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


// ============================================
// File: Sources/HtmlToPdf/PDF.EdgeInsets.swift
// ============================================

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


// ============================================
// File: Sources/HtmlToPdf/PDF.FailedDocument.swift
// ============================================

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


// ============================================
// File: Sources/HtmlToPdf/PDF.NamingStrategy.swift
// ============================================

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


// ============================================
// File: Sources/HtmlToPdf/PDF.PaginationMode.swift
// ============================================

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

// MARK: - Internal Rendering Method

extension PDF {
    /// Internal rendering method (not exposed in public API)
    ///
    /// This is the actual implementation strategy chosen after
    /// analyzing the pagination mode and content.
    enum InternalRenderingMethod {
        case webView
        case printOperation
    }
}


// ============================================
// File: Sources/HtmlToPdf/PDF.PaperSize.swift
// ============================================

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


// ============================================
// File: Sources/HtmlToPdf/PDF.Render+Convenience.swift
// ============================================

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

    // MARK: - Platform Capabilities

    /// Get capabilities of current implementation
    ///
    /// Convenience method that forwards to `client.capabilities()`.
    ///
    /// - Returns: Platform capabilities
    public func capabilities() -> PDF.Capabilities {
        client.capabilities()
    }
}


// ============================================
// File: Sources/HtmlToPdf/PDF.Render+TestDependencyKey.swift
// ============================================

//
//  PDF.Render+TestDependencyKey.swift
//  swift-html-to-pdf
//
//  Test dependency configuration for PDF.Render
//

import Dependencies

extension PDF.Render: TestDependencyKey {
    public static let testValue = PDF.Render(
        client: .testValue,
        configuration: .testValue
    )
}

extension PDF.Render.Client: TestDependencyKey {
    public static let testValue = PDF.Render.Client()
}


// ============================================
// File: Sources/HtmlToPdf/PDF.Render.Client+Convenience.swift
// ============================================

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


// ============================================
// File: Sources/HtmlToPdf/PDF.Render.Client+iOS.swift
// ============================================

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
import UIKit
import WebKit

extension PDF.Render.Client: DependencyKey {
    public static let liveValue: Self = .iOS
}

extension PDF.Render.Client {
    /// iOS-specific implementation using UIPrintPageRenderer
    public static let iOS = PDF.Render.Client(
        documents: { documents in
            @Dependency(\.pdf.render.configuration) var config
            return try await renderDocumentsInternal(documents, config: config)
        },
        capabilities: {
            .iOS
        }
    )
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
        if config.createDirectories {
            try FileManager.default.createDirectory(
                at: self.destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        // Check if HTML contains images - use WebView if so
        if self.html.containsImages() {
            return try await renderWithWebView(config: config)
        } else {
            return try await renderWithPrintFormatter(config: config)
        }
    }

    @MainActor
    private func renderWithPrintFormatter(config: PDF.Configuration) async throws -> URL {
        let printFormatter = UIMarkupTextPrintFormatter(markupText: self.html)
        let data = try await renderToDataWithFormatter(printFormatter, config: config)
        try data.write(to: self.destination)
        return self.destination
    }

    @MainActor
    private func renderWithWebView(config: PDF.Configuration) async throws -> URL {
        @Dependency(\.webViewPool) var webViewPool

        let pool = try await webViewPool.pool
        return try await pool.withResource(
            timeout: .seconds(config.webViewAcquisitionTimeout.components.seconds)
        ) { resource in
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
            do {

                let maxConcurrent = config.concurrency ??
                    Swift.min(ProcessInfo.processInfo.activeProcessorCount, 4)

                var completedCount = 0

                try await withThrowingTaskGroup(of: (Int, URL, Int, [CGSize], PDF.PaginationMode, Duration).self) { taskGroup in
                    for (index, document) in documentsArray.prefix(maxConcurrent).enumerated() {
                        taskGroup.addTask {
                            let start = ContinuousClock.now
                            let url = try await document.renderInternal(config: config)
                            let duration = ContinuousClock.now - start
                            // iOS doesn't easily extract page info, default to 1 page with paper size
                            let pageCount = 1
                            let dimensions = [config.paperSize]
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
                        continuation.yield(result)

                        if nextIndex < documentsArray.count {
                            let document = documentsArray[nextIndex]
                            let capturedIndex = nextIndex
                            nextIndex += 1

                            taskGroup.addTask {
                                let start = ContinuousClock.now
                                let url = try await document.renderInternal(config: config)
                                let duration = ContinuousClock.now - start
                                let pageCount = 1
                                let dimensions = [config.paperSize]
                                let mode = config.paginationMode
                                return (capturedIndex, url, pageCount, dimensions, mode, duration)
                            }
                        }
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
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
            webView.loadHTMLString(self.document.html, baseURL: self.configuration.baseURL)

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
                            print("[DocumentWKRenderer] Unexpected error in timeout task: \(error)")
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

#endif


// ============================================
// File: Sources/HtmlToPdf/PDF.Render.Client+macOS.swift
// ============================================

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
import AppKit
import PDFKit

extension PDF: DependencyKey {
    public static let liveValue = PDF(
        render: .liveValue
    )
}

extension PDF.Render: DependencyKey {
    public static let liveValue = PDF.Render(
        client: .macOS,
        configuration: .default
    )
}

// MARK: - Directory Cache

/// Thread-safe cache for validated directories to avoid redundant file system checks
/// Uses NSLock for low-overhead synchronization instead of actor (avoids async overhead)
private final class DirectoryCache: @unchecked Sendable {
    private var validated: Set<String> = []
    private let lock = NSLock()

    func ensureDirectory(
        at url: URL,
        createIfNeeded: Bool
    ) throws {
        let path = url.path

        // Fast path: check cache with lock
        lock.lock()
        let isValidated = validated.contains(path)
        lock.unlock()

        if isValidated {
            return
        }

        // Slow path: check and possibly create (file I/O)
        if createIfNeeded {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
            lock.lock()
            validated.insert(path)
            lock.unlock()
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
            lock.lock()
            validated.insert(path)
            lock.unlock()
        }
    }

    func clear() {
        lock.lock()
        validated.removeAll()
        lock.unlock()
    }
}

/// Shared directory cache for the rendering session
private let directoryCache = DirectoryCache()

// MARK: - NSPrintInfo Cache

/// Pre-configured NSPrintInfo cache to avoid repeated setup overhead
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
            return try await renderDocumentsInternal(documents, config: config)
        },
        documentsResilient: { documents in
            @Dependency(\.pdf.render.configuration) var config
            return await renderDocumentsResilient(documents, config: config)
        },
        capabilities: {
            .macOS
        }
    )
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
            do {

                // Get the pool ONCE at the beginning, not for every document
                // Pool access doesn't require main actor
                @Dependency(\.webViewPool) var webViewPool
                let pool = try await webViewPool.pool

                let maxConcurrent = config.concurrency.resolved

                var completedCount = 0

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
                continuation.finish(throwing: error)

                // Clear directory cache on error as well
                directoryCache.clear()
            }
        }
    }
}

/// Resilient batch rendering - continues on individual failures
private func renderDocumentsResilient(
    _ documents: some Sequence<PDF.Document>,
    config: PDF.Configuration
) async -> AsyncStream<PDF.Render.BatchResult> {
    let documentsArray = Array(documents)
    let (stream, continuation) = AsyncStream.makeStream(of: PDF.Render.BatchResult.self)

    Task {
        await populateResilientBatchStream(
            documents: documentsArray,
            config: config,
            continuation: continuation
        )
    }

    return stream
}

/// Result from a single document render task
private struct RenderTaskResult: Sendable {
    let index: Int
    let renderResult: Swift.Result<(url: URL, pageCount: Int, dimensions: [CGSize], mode: PDF.PaginationMode), Error>
    let duration: Duration
}

/// Populate the resilient batch stream with results
private func populateResilientBatchStream(
    documents: [PDF.Document],
    config: PDF.Configuration,
    continuation: AsyncStream<PDF.Render.BatchResult>.Continuation
) async {
    @Dependency(\.webViewPool) var webViewPool

    guard let pool = try? await webViewPool.pool else {
        for (index, document) in documents.enumerated() {
            let failed = PDF.FailedDocument(
                document: document,
                index: index,
                error: PrintingError.webViewPoolExhausted(pendingRequests: documents.count),
                duration: .zero
            )
            continuation.yield(.failure(failed))
        }
        continuation.finish()
        return
    }

    let maxConcurrent = config.concurrency.resolved

    do {
        try await withThrowingTaskGroup(of: RenderTaskResult.self) { taskGroup in
            for (index, document) in documents.prefix(maxConcurrent).enumerated() {
                taskGroup.addTask {
                    let start = ContinuousClock.now
                    let result = await Swift.Result {
                        try await document.renderWithPool(pool, config: config)
                    }
                    let duration = ContinuousClock.now - start
                    return RenderTaskResult(index: index, renderResult: result, duration: duration)
                }
            }

            var nextIndex = maxConcurrent

            for try await taskResult in taskGroup {
                switch taskResult.renderResult {
                case .success(let (url, pageCount, dimensions, mode)):
                    let pdfResult = PDF.Result(
                        url: url,
                        index: taskResult.index,
                        duration: taskResult.duration,
                        paginationMode: mode,
                        pageCount: pageCount,
                        pageDimensions: dimensions
                    )
                    continuation.yield(.success(pdfResult))
                    try? await webViewPool.recordPDFGenerated()

                case .failure(let error):
                    let failed = PDF.FailedDocument(
                        document: documents[taskResult.index],
                        index: taskResult.index,
                        error: error,
                        duration: taskResult.duration
                    )
                    continuation.yield(.failure(failed))
                }

                if nextIndex < documents.count {
                    let document = documents[nextIndex]
                    let capturedIndex = nextIndex
                    nextIndex += 1

                    taskGroup.addTask {
                        let start = ContinuousClock.now
                        let result = await Swift.Result {
                            try await document.renderWithPool(pool, config: config)
                        }
                        let duration = ContinuousClock.now - start
                        return RenderTaskResult(index: capturedIndex, renderResult: result, duration: duration)
                    }
                }
            }
        }
    } catch {
        // This should never happen since we catch all errors internally with Swift.Result
        // But needed for withThrowingTaskGroup syntax
    }

    continuation.finish()
    directoryCache.clear()
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
                        // File write on background thread
                        try data.write(to: outputURL)

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


// ============================================
// File: Sources/HtmlToPdf/PDF.Render.Client.swift
// ============================================

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
    @DependencyClient
    public struct Client: @unchecked Sendable {

        // MARK: - Primitive Operations

        /// Render documents to PDF files, yielding results as they complete
        ///
        /// This is the sole primitive rendering operation. Documents are rendered concurrently
        /// based on configuration settings, with results streamed as each completes.
        ///
        /// **Fail-Fast Behavior**: Throws on first error, stopping batch processing.
        /// For resilient batch processing that continues on individual failures, use ``documentsResilient(_:)``.
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

        /// Render documents to PDF files, continuing on individual failures
        ///
        /// Resilient variant that reports failures without stopping the batch.
        /// Each document result is wrapped in a `Result` type - successes yield `.success(PDF.Result)`,
        /// failures yield `.failure(PDF.FailedDocument)`.
        ///
        /// **Resilient Behavior**: Never throws - individual failures are reported as `.failure` cases.
        ///
        /// ## Example
        ///
        /// ```swift
        /// for await result in await renderClient.documentsResilient(documents) {
        ///     switch result {
        ///     case .success(let pdf):
        ///         print("✅ \(pdf.url.lastPathComponent)")
        ///     case .failure(let failed):
        ///         print("❌ Document \(failed.index): \(failed.error)")
        ///         // Continue processing remaining documents
        ///     }
        /// }
        /// ```
        ///
        /// - Parameter documents: Documents to render (any sequence)
        /// - Returns: Stream of results (never throws)
        @DependencyEndpoint
        public var documentsResilient: @Sendable (
            _ documents: any Sequence<PDF.Document>
        ) async -> AsyncStream<PDF.Render.BatchResult> = { _ in
            AsyncStream { _ in }
        }

        // MARK: - Platform Capabilities

        /// Get capabilities of current implementation
        @DependencyEndpoint
        public var capabilities: @Sendable () -> PDF.Capabilities = { .mock }
    }
}


// ============================================
// File: Sources/HtmlToPdf/PDF.Render.Result.swift
// ============================================

//
//  PDF.Render.Result.swift
//  swift-html-to-pdf
//
//  Result type for batch rendering operations
//

import Foundation

extension PDF.Render {
    /// Result of a batch rendering operation
    ///
    /// Used in resilient batch processing to distinguish between successful and failed documents.
    public enum BatchResult: Sendable {
        /// Document rendered successfully
        case success(PDF.Result)

        /// Document failed to render
        case failure(PDF.FailedDocument)
    }
}


// ============================================
// File: Sources/HtmlToPdf/PDF.Render.swift
// ============================================

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


// ============================================
// File: Sources/HtmlToPdf/PDF.Result.swift
// ============================================

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


// ============================================
// File: Sources/HtmlToPdf/PDF.swift
// ============================================

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


// ============================================
// File: Sources/HtmlToPdf/PrintingError.swift
// ============================================

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


// ============================================
// File: Sources/HtmlToPdf/WKWebViewResource.swift
// ============================================

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

/// Configuration for creating WKWebView resources
public struct WKWebViewResourceConfig: Sendable {
    /// Whether to use persistent data store
    public let usePersistentDataStore: Bool

    public init(
        usePersistentDataStore: Bool = false
    ) {
        self.usePersistentDataStore = usePersistentDataStore
    }
}

/// WKWebView wrapper that conforms to PoolableResource
@MainActor
public final class WKWebViewResource: PoolableResource {
    public typealias Config = WKWebViewResourceConfig

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

        // Use data store based on configuration
        webViewConfig.websiteDataStore = config.usePersistentDataStore ? .default() : .nonPersistent()

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

// ============================================
// File: Sources/HtmlToPdf/WebViewPoolClient-ResourcePool.swift
// ============================================

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
import ResourcePool
import EnvironmentVariables
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
            print("📊 Adaptive replacement: \(String(format: "%.0f", recentAverage)) PDFs/sec (recent avg) vs \(String(format: "%.0f", localPeak)) PDFs/sec (local peak) - \(String(format: "%.1f", (1.0 - recentAverage/localPeak) * 100))% degradation")
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
    private var batchReplacementThreshold = 30_000 // Reduced from 50K for better sustained performance
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
            print("🎯 Adaptive throughput optimization ENABLED")
        }

        if let existing = sharedPool {
            return existing
        }

        let newPool = try await provider()
        sharedPool = newPool
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
        if totalPDFsGenerated >= batchReplacementThreshold,
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
        print("🔄 Batch replacement triggered at \(oldCount) PDFs (\(reason)) - replacing entire pool")

        // Create new pool (warmup will happen in background)
        let newPool = try await provider()

        // Swap to new pool immediately
        // The old pool will be released when all current operations complete
        // Swift's ARC will handle cleanup automatically
        sharedPool = newPool
        totalPDFsGenerated = 0

        // Reset adaptive optimizer to establish new baseline
        if let optimizer = adaptiveOptimizer {
            await optimizer.resetPeak()
        }

        isReplacing = false

        print("✅ Batch replacement complete - fresh pool ready, old pool will cleanup automatically")
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
                @Dependency(\.envVars) var env

                // Determine pool size
                let poolSize: Int
                if let envPoolSize = env["WEBVIEW_POOL_SIZE"],
                   let customSize = Int(envPoolSize), customSize > 0 {
                    poolSize = customSize
                } else {
                    // Use intelligent defaults based on hardware
                    poolSize = PDF.ConcurrencyStrategy.calculateDefaultConcurrency()
                }

                // Create configuration
                let usePersistentDataStore = env["WEBVIEW_PERSISTENT_DATA_STORE"]?.lowercased() == "true"
                let config = WKWebViewResourceConfig(
                    usePersistentDataStore: usePersistentDataStore
                )

                // Create pool with warmup
                // Batch replacement (every 30K PDFs) handles memory leaks at pool level
                return try await ResourcePool<WKWebViewResource>(
                    capacity: poolSize,
                    resourceConfig: config,
                    warmup: true,
                    maxUsesBeforeCycling: nil  // No per-resource cycling - using batch replacement
                )
            }
        )
    }

    public static var testValue: WebViewPoolClient {
        WebViewPoolClient(poolProvider: { @MainActor in
            let config = WKWebViewResourceConfig(usePersistentDataStore: false)
            return try await ResourcePool<WKWebViewResource>(
                capacity: 2,
                resourceConfig: config,
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


