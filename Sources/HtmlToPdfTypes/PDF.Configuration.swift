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

        /// Color scheme appearance for PDF rendering
        ///
        /// Controls whether PDFs render with light or dark backgrounds,
        /// independent of system dark mode settings.
        ///
        /// **Default is `.light`** - ensures professional documents (invoices, reports, contracts)
        /// render with white backgrounds regardless of macOS appearance.
        ///
        /// ## Options
        ///
        /// - `.light`: Force white background, dark text (default, recommended)
        /// - `.dark`: Force dark background, light text (rare - presentations only)
        /// - `.auto`: Respect system appearance (may produce inconsistent results)
        ///
        /// ## Example
        ///
        /// ```swift
        /// // Default behavior (light appearance)
        /// try await pdf.render(html: html, to: url)
        ///
        /// // Respect system dark mode
        /// try await withDependencies {
        ///     $0.pdf.render.configuration.appearance = .auto
        /// } operation: {
        ///     try await pdf.render(html: html, to: url)
        /// }
        /// ```
        ///
        /// See ``PDF/Appearance`` for detailed documentation.
        public var appearance: Appearance = .light

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
            appearance: Appearance = .light,
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
            self.appearance = appearance
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
