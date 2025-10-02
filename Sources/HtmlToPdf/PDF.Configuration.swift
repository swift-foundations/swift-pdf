//
//  PDF.Configuration.swift
//  swift-html-to-pdf
//
//  Configuration for PDF rendering
//

import Dependencies
import DependenciesMacros
import Foundation

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

        /// Maximum concurrent rendering operations
        /// nil = use ProcessInfo.processInfo.activeProcessorCount
        public var concurrency: Int?

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

        public init(
            paperSize: CGSize = .a4,
            margins: EdgeInsets = .standard,
            baseURL: URL? = nil,
            paginationMode: PaginationMode = .paginated,
            concurrency: Int? = nil,
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
    /// Default configuration (A4, standard margins, proper pagination for printing)
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
        concurrency: 16,
        batchTimeout: .seconds(86400), // 24 hours
        webViewAcquisitionTimeout: .seconds(600)
    )

    /// Optimized for current platform
    public static var platformOptimized: Self {
        #if os(macOS)
        return .init(
            paperSize: .a4,
            margins: .standard,
            concurrency: 16,
            webViewAcquisitionTimeout: .seconds(300)
        )
        #elseif canImport(UIKit)
        return .init(
            paperSize: .a4,
            margins: .standard,
            concurrency: 4,
            webViewAcquisitionTimeout: .seconds(600)
        )
        #elseif os(Linux)
        return .init(
            paperSize: .a4,
            margins: .standard,
            concurrency: 32,
            webViewAcquisitionTimeout: .seconds(120)
        )
        #else
        return .default
        #endif
    }
}

// MARK: - Dependency Registration

extension PDF.Configuration: TestDependencyKey {
    public static let testValue = PDF.Configuration.default
}

extension DependencyValues {
    public var pdfConfiguration: PDF.Configuration {
        get { self[PDF.Configuration.self] }
        set { self[PDF.Configuration.self] = newValue }
    }
}
