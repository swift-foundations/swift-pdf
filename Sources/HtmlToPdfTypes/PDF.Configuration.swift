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
    /// Provides comprehensive control over PDF generation with sensible defaults optimized
    /// for professional document output (invoices, reports, contracts).
    ///
    /// ## Default Behavior
    ///
    /// The default configuration produces print-ready PDFs without any setup:
    /// - **A4 paper size** (595.28 × 841.89 pts) - International standard
    /// - **Standard margins** (0.5 inch / 36pts) - Professional appearance
    /// - **Continuous pagination** - Fast rendering (3x faster than paginated)
    /// - **Light appearance** - White backgrounds regardless of system dark mode
    /// - **Automatic concurrency** - Optimal throughput based on CPU count
    ///
    /// These defaults work well for 80% of use cases without any configuration.
    ///
    /// ## Common Configurations
    ///
    /// ```swift
    /// // Default - Professional documents (recommended, no config needed)
    /// @Dependency(\.pdf) var pdf
    /// try await pdf.render.client.documents(documents)
    ///
    /// // US Letter for American business documents
    /// try await withDependencies {
    ///     $0.pdf.render.configuration = .letter
    /// } operation: {
    ///     try await pdf.render.client.documents(documents)
    /// }
    ///
    /// // Large batch processing with custom settings
    /// try await withDependencies {
    ///     $0.pdf.render.configuration.concurrency = 24
    ///     $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(600)
    /// } operation: {
    ///     // Process thousands of PDFs
    ///     for try await result in try await pdf.render.client.documents(documents) {
    ///         print("Generated \(result.url)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Configuration Properties
    ///
    /// ### Document Configuration
    /// - `paperSize`: Physical page dimensions (default: A4)
    /// - `margins`: Space around content (default: 0.5 inch)
    /// - `baseURL`: Root for resolving relative URLs in HTML
    /// - `paginationMode`: How content flows into pages (default: continuous)
    /// - `appearance`: Light/dark/auto color scheme (default: light for professional docs)
    ///
    /// ### Performance Configuration
    /// - `concurrency`: Concurrent WebView limit (default: automatic based on CPU)
    ///
    /// ### Timeout Configuration
    /// - `documentTimeout`: Per-PDF time limit (default: nil - no limit)
    /// - `batchTimeout`: Entire batch time limit (default: nil - no limit)
    /// - `webViewAcquisitionTimeout`: Pool wait time (default: 60 seconds)
    ///
    /// ### File System Configuration
    /// - `createDirectories`: Auto-create destination folders (default: true)
    /// - `namingStrategy`: Batch file naming pattern (default: sequential)
    ///
    /// ## Platform Differences & Concurrency
    ///
    /// No artificial limits are enforced. Pool capacity equals concurrency value, providing natural resource management.
    ///
    /// **Automatic defaults:**
    /// - **macOS**: 1x CPU count (e.g., 8 on 8-core Mac) - optimal throughput
    /// - **iOS**: min(CPU count, 4) - conservative for thermal/battery constraints
    ///
    /// **Tested values:**
    /// - macOS: 24-32 concurrent works excellently
    /// - iOS: 4-8 tested, varies by device
    ///
    /// **You can set higher:**
    /// ```swift
    /// config.concurrency = .fixed(32)  // ✅ No error - ResourcePool manages resources
    /// ```
    ///
    /// ResourcePool capacity and OS resources are the only real limits.
    public struct Configuration: Sendable {

        // MARK: - Document Configuration

        /// Paper size for PDF documents
        public var paperSize: CGSize

        /// Margins applied to each page
        public var margins: EdgeInsets

        /// Base URL for resolving relative URLs in HTML
        public var baseURL: URL?

        /// How content should be paginated in the PDF
        public var paginationMode: PDF.PaginationMode

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
        public var concurrency: PDF.Render.ConcurrencyStrategy = .automatic

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
        ///
        /// **Internal implementation detail** - Do not use directly.
        ///
        /// This property generates CSS that injects margins into HTML `<body>` tags.
        /// The rendering system automatically applies these margins during PDF generation.
        ///
        /// The CSS is computed on-demand based on current margin values. For performance,
        /// the configuration itself is typically cached by the dependency system.
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
            concurrency: PDF.Render.ConcurrencyStrategy = .automatic,
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
