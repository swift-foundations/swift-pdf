//
//  Deprecations.swift
//  swift-html-to-pdf
//
//  Deprecated API from v0.5.x - Will be removed in v1.0.0
//
//  This file provides backward compatibility for the v0.5.x String-based API.
//  New code should use the @Dependency(\.pdf) API introduced in v0.6.0.
//

import Foundation
import HtmlToPdfLive

// MARK: - Type Aliases

/// Old `PDFConfiguration` type - use `PDF.Configuration` instead
@available(*, deprecated, renamed: "PDF.Configuration",
           message: """
           Use PDF.Configuration with the new dependency-based API:

           Old:
             try await html.print(to: url, configuration: .a4)

           New:
             @Dependency(\\.pdf) var pdf
             try await withDependencies {
                 $0.pdf.render.configuration.paperSize = .a4
             } operation: {
                 try await pdf.render(html: html, to: url)
             }
           """)
public typealias PDFConfiguration = OldPDFConfiguration

/// Old `PrintingConfiguration` type - use `PDF.Configuration` instead
@available(*, deprecated, renamed: "PDF.Configuration",
           message: """
           Use PDF.Configuration with the new dependency-based API.

           Old:
             PrintingConfiguration(maxConcurrentOperations: 16)

           New:
             @Dependency(\\.pdf) var pdf
             try await withDependencies {
                 $0.pdf.render.configuration.concurrency = 16
             } operation: {
                 try await pdf.render(html: html, to: url)
             }
           """)
public typealias PrintingConfiguration = OldPrintingConfiguration

/// Old `Document` type - use `PDF.Document` instead
@available(*, deprecated, renamed: "PDF.Document",
           message: """
           Use PDF.Document with the new dependency-based API:

           Old:
             let doc = Document(fileUrl: url, html: html)
             try await doc.print(configuration: .a4)

           New:
             @Dependency(\\.pdf) var pdf
             let doc = PDF.Document(htmlBytes: html.toUTF8Bytes(), destination: url)
             try await pdf.render.client.documents([doc])
           """)
public typealias Document = OldDocument

// MARK: - Deprecated String Extensions

extension String {
    /// Prints a single HTML string to a PDF at the given URL
    ///
    /// - Note: **Deprecated in v0.6.0** - Use the new dependency-based API instead
    ///
    /// **Migration:**
    /// ```swift
    /// // Old (v0.5.x)
    /// try await html.print(to: fileUrl, configuration: .a4)
    ///
    /// // New (v0.6.0+)
    /// import Dependencies
    /// @Dependency(\\.pdf) var pdf
    /// try await pdf.render(html: html, to: fileUrl)
    /// ```
    @available(*, deprecated, message: """
        Use @Dependency(\\.pdf) var pdf; try await pdf.render(html:to:)

        See MIGRATION.md for detailed migration guide.
        """)
    @MainActor
    public func print(
        to fileUrl: URL,
        configuration: PDFConfiguration = .a4,
        printingConfiguration: PrintingConfiguration = .default,
        createDirectories: Bool = true
    ) async throws {
        @Dependency(\.pdf) var pdf

        try await withDependencies {
            configuration.apply(to: &$0.pdf.render.configuration)
            printingConfiguration.apply(to: &$0.pdf.render.configuration)
            $0.pdf.render.configuration.createDirectories = createDirectories
        } operation: {
            try await pdf.render(html: self, to: fileUrl)
        }
    }

    /// Prints a single HTML string to a PDF at the given directory with the title
    ///
    /// - Note: **Deprecated in v0.6.0** - Use the new dependency-based API instead
    ///
    /// **Migration:**
    /// ```swift
    /// // Old (v0.5.x)
    /// try await html.print(title: "invoice", to: .downloadsDirectory)
    ///
    /// // New (v0.6.0+)
    /// let url = URL.downloadsDirectory.appendingPathComponent("invoice.pdf")
    /// try await pdf.render(html: html, to: url)
    /// ```
    @available(*, deprecated, message: """
        Use @Dependency(\\.pdf) var pdf; try await pdf.render(html:to:)

        Construct the full URL yourself: directory.appendingPathComponent(title).appendingPathExtension("pdf")
        """)
    @MainActor
    public func print(
        title: String,
        to directory: URL,
        configuration: PDFConfiguration = .a4,
        printingConfiguration: PrintingConfiguration = .default,
        createDirectories: Bool = true
    ) async throws {
        let fileUrl = directory
            .appendingPathComponent(title.replacingSlashesWithDivisionSlash())
            .appendingPathExtension("pdf")

        try await self.print(
            to: fileUrl,
            configuration: configuration,
            printingConfiguration: printingConfiguration,
            createDirectories: createDirectories
        )
    }
}

extension Sequence<String> {
    /// Prints a collection of Strings to PDFs
    ///
    /// - Note: **Deprecated in v0.6.0** - Use the new dependency-based API instead
    ///
    /// **Migration:**
    /// ```swift
    /// // Old (v0.5.x)
    /// try await html.print(to: directory)
    ///
    /// // New (v0.6.0+)
    /// @Dependency(\\.pdf) var pdf
    /// try await pdf.render(html: html, to: directory)
    /// ```
    @available(*, deprecated, message: """
        Use @Dependency(\\.pdf) var pdf; try await pdf.render(html:to:)

        See MIGRATION.md for detailed migration guide.
        """)
    public func print(
        to directory: URL,
        configuration: PDFConfiguration = .a4,
        printingConfiguration: PrintingConfiguration = .default,
        filename: @escaping @Sendable (Int) -> String = { index in "\(index + 1)" },
        createDirectories: Bool = true
    ) async throws {
        @Dependency(\.pdf) var pdf

        // Capture filename in a local variable to make it @Sendable and @escaping
        let namingStrategy = PDF.NamingStrategy(filename: filename)

        try await withDependencies {
            configuration.apply(to: &$0.pdf.render.configuration)
            printingConfiguration.apply(to: &$0.pdf.render.configuration)
            $0.pdf.render.configuration.createDirectories = createDirectories
            $0.pdf.render.configuration.namingStrategy = namingStrategy
        } operation: {
            // Consume the stream to completion (old API was fire-and-forget)
            for try await _ in try await pdf.render(html: Array(self), to: directory) {
                // Just consume results
            }
        }
    }
}

// MARK: - Old Configuration Types (for backward compatibility)

public struct OldPDFConfiguration: Sendable {
    public let paperSize: CGSize
    public let margins: EdgeInsets
    public let baseURL: URL?

    public init(
        paperSize: CGSize = CGSize.a4,
        margins: EdgeInsets = EdgeInsets.standard,
        baseURL: URL? = nil
    ) {
        self.paperSize = paperSize
        self.margins = margins
        self.baseURL = baseURL
    }

    func apply(to config: inout PDF.Configuration) {
        config.paperSize = paperSize
        config.margins = margins
        config.baseURL = baseURL
    }
}

extension OldPDFConfiguration {
    public static let a4 = OldPDFConfiguration(paperSize: CGSize.a4, margins: EdgeInsets.standard)
    public static let letter = OldPDFConfiguration(paperSize: CGSize.letter, margins: EdgeInsets.standard)
}

public struct OldPrintingConfiguration: Sendable {
    public let maxConcurrentOperations: Int?
    public let documentTimeout: TimeInterval?
    public let batchTimeout: TimeInterval?
    public let webViewAcquisitionTimeout: TimeInterval

    public init(
        maxConcurrentOperations: Int? = nil,
        documentTimeout: TimeInterval? = nil,
        batchTimeout: TimeInterval? = nil,
        webViewAcquisitionTimeout: TimeInterval = 300
    ) {
        self.maxConcurrentOperations = maxConcurrentOperations
        self.documentTimeout = documentTimeout
        self.batchTimeout = batchTimeout
        self.webViewAcquisitionTimeout = webViewAcquisitionTimeout
    }

    public static var `default`: OldPrintingConfiguration {
        OldPrintingConfiguration()
    }

    func apply(to config: inout PDF.Configuration) {
        if let maxConcurrent = maxConcurrentOperations {
            config.concurrency = .fixed(maxConcurrent)
        }
        if let docTimeout = documentTimeout {
            config.documentTimeout = .seconds(Int64(docTimeout))
        }
        if let batchTimeout = batchTimeout {
            config.batchTimeout = .seconds(Int64(batchTimeout))
        }
        config.webViewAcquisitionTimeout = .seconds(Int64(webViewAcquisitionTimeout))
    }
}

public struct OldDocument: Sendable {
    let fileUrl: URL
    let html: String

    public init(fileUrl: URL, html: String) {
        self.fileUrl = fileUrl
        self.html = html
    }
}

// MARK: - Helpers

extension String {
    fileprivate func replacingSlashesWithDivisionSlash() -> String {
        let divisionSlash = "\u{2215}" // Unicode for Division Slash (∕)
        return self.replacingOccurrences(of: "/", with: divisionSlash)
    }
}
