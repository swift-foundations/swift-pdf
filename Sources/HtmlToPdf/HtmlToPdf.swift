//
//  swift-html-to-pdf | shared.swift
//
//
//  Created by Coen ten Thije Boonkkamp on 15/07/2024.
//

import Foundation

/// A model of a document that will be printed to a PDF.
///
/// ## Example
/// ```swift
/// let document = Document(
///     url: URL(...),
///     html: "..."
/// )
/// ```
///
/// - Parameters:
///   - url: The url at which to print the document.
///   - html: The String representing the HTML that will be printed.
///
public struct Document: Sendable {
    let fileUrl: URL
    let html: String

    public init(
        fileUrl: URL,
        html: String
    ) {
        self.fileUrl = fileUrl
        self.html = html
    }
}


extension String {
    /// Prints a single html string to a PDF at the given URL, with the given margins.
    ///
    /// ## Example
    /// ```swift
    /// let html = "<html><body><h1>Hello, World!</h1></body></html>"
    /// let url = URL.downloadsDirectory
    ///     .appendingPathComponent("helloWorld", conformingTo: .pdf)
    /// try await html.print(to:url)
    /// ```
    ///
    /// - Parameters:
    ///   - url: The url at which to print the PDF
    ///   - configuration: The configuration of the PDF document.
    ///
    /// - Throws: `Error` if the function cannot clean up the temporary .html file it creates.
    ///
    @MainActor
    public func print(
        to fileUrl: URL,
        configuration: PDFConfiguration = .a4,
        printingConfiguration: PrintingConfiguration = .default,
        createDirectories: Bool = true
    ) async throws {
        try await Document(fileUrl: fileUrl, html: self)
            .print(
                configuration: configuration,
                printingConfiguration: printingConfiguration,
                createDirectories: createDirectories
            )
    }
}

extension String {
    /// Prints a single html string to a PDF at the given directory with the title and margins.
    ///
    /// This function is more convenient when you have a directory and just want to title the PDF and save it to the directory.
    ///
    /// ## Example
    /// ```swift
    ///  let html = "<html><body><h1>Hello, World!</h1></body></html>"
    ///  try await html.print(
    ///     title: "helloWorld",
    ///     to: .downloadsDirectory
    ///  )
    /// ```
    ///
    /// - Parameters:
    ///   - title: The title of the PDF
    ///   - directory: The directory at which to print the PDF
    ///   - configuration: The configuration of the PDF document.
    ///
    /// - Throws: `Error` if the function cannot clean up the temporary .html file it creates.
    public func print(
        title: String,
        to directory: URL,
        configuration: PDFConfiguration = .a4,
        printingConfiguration: PrintingConfiguration = .default,
        createDirectories: Bool = true
    ) async throws {
        try await Document(
            fileUrl: directory.appendingPathComponent(title.replacingSlashesWithDivisionSlash()).appendingPathExtension("pdf"),
            html: self
        ).print(
            configuration: configuration,
            printingConfiguration: printingConfiguration,
            createDirectories: createDirectories
        )
    }
}

extension String {
    func replacingSlashesWithDivisionSlash() -> String {
        let divisionSlash = "\u{2215}" // Unicode for Division Slash (∕)
        return self.replacingOccurrences(of: "/", with: divisionSlash)
    }

    /// Injects CSS into HTML, either before </head> or at the beginning if no head tag exists
    func injectingCSS(_ css: String) -> String {
        // Try to inject before </head>
        if let headEndRange = self.range(of: "</head>", options: .caseInsensitive) {
            return self.replacingCharacters(in: headEndRange, with: css + "</head>")
        }
        // Try to inject after <head>
        else if let headStartRange = self.range(of: "<head>", options: .caseInsensitive) {
            // Find the end of the <head> tag (after any attributes)
            if let tagEnd = self.range(of: ">", options: [], range: headStartRange.upperBound..<self.endIndex) {
                let insertPoint = self.index(after: tagEnd.lowerBound)
                return String(self[..<insertPoint]) + css + String(self[insertPoint...])
            } else {
                // If we can't find the closing >, just append after <head
                return self.replacingOccurrences(of: "<head>", with: "<head>" + css, options: .caseInsensitive)
            }
        }
        // Try to inject before <body>
        else if let bodyRange = self.range(of: "<body", options: .caseInsensitive) {
            return String(self[..<bodyRange.lowerBound]) + css + String(self[bodyRange.lowerBound...])
        }
        // Otherwise inject at the beginning
        else {
            return css + self
        }
    }
}

extension Sequence<String> {
    /// Prints a collection of String to PDFs.
    ///
    /// ## Example
    /// ```swift
    /// let htmls = [
    ///     "<html><body><h1>Hello, World 1!</h1></body></html>",
    ///     "<html><body><h1>Hello, World 1!</h1></body></html>",
    ///     ...
    /// ]
    /// try await htmls.print(to: .downloadsDirectory)
    /// ```
    ///
    /// - Parameters:
    ///   - directory: The directory at which to print the documents.
    ///   - configuration: The configuration that the PDFs will use.
    ///   - fileName: A closure that, given an Int that represents the index of the String in the collection, returns a fileName. Defaults to just the Index + 1.
    ///   - createDirectories: If true, the function will call FileManager.default.createDirectory for each document's directory.
    ///
    public func print(
        to directory: URL,
        configuration: PDFConfiguration = .a4,
        printingConfiguration: PrintingConfiguration = .default,
        filename: (Int) -> String = { index in "\(index + 1)" },
        createDirectories: Bool = true
    ) async throws {
        try await self.enumerated()
            .map { (index, html) in
                Document(
                    fileUrl: directory
                        .appendingPathComponent(filename(index))
                        .appendingPathExtension("pdf"),
                    html: html
                )
            }
            .print(
                configuration: configuration,
                printingConfiguration: printingConfiguration,
                createDirectories: createDirectories
            )
    }
}

/// Configuration for printing behavior and resource management
///
/// This configuration controls how the printing process behaves, including
/// concurrency limits, timeouts, and progress tracking.
///
/// - Parameters:
///   - maxConcurrentOperations: Maximum number of concurrent print operations. nil uses system default (CPU count).
///   - documentTimeout: Timeout per document in seconds. nil means no timeout.
///   - batchTimeout: Overall timeout for the entire batch in seconds. nil means no timeout.
///   - webViewAcquisitionTimeout: Timeout for acquiring a WebView from the pool in seconds. Defaults to 300 (5 minutes).
///   - progressHandler: Optional callback for tracking progress (completed, total).
///
public struct PrintingConfiguration: Sendable {
    public let maxConcurrentOperations: Int?
    public let documentTimeout: TimeInterval?
    public let batchTimeout: TimeInterval?
    public let webViewAcquisitionTimeout: TimeInterval
    public let progressHandler: (@Sendable (Int, Int) -> Void)?

    public init(
        maxConcurrentOperations: Int? = nil,
        documentTimeout: TimeInterval? = nil,
        batchTimeout: TimeInterval? = nil,
        webViewAcquisitionTimeout: TimeInterval = 300,
        progressHandler: (@Sendable (Int, Int) -> Void)? = nil
    ) {
        self.maxConcurrentOperations = maxConcurrentOperations
        self.documentTimeout = documentTimeout
        self.batchTimeout = batchTimeout
        self.webViewAcquisitionTimeout = webViewAcquisitionTimeout
        self.progressHandler = progressHandler
    }

    /// Default configuration suitable for most use cases
    public static var `default`: PrintingConfiguration {
        PrintingConfiguration()
    }

    /// Configuration optimized for large batches (millions of documents)
    public static var largeBatch: PrintingConfiguration {
        PrintingConfiguration(
            maxConcurrentOperations: 16,
            documentTimeout: nil, // No per-document timeout
            batchTimeout: 86400, // 24 hours
            webViewAcquisitionTimeout: 600 // 10 minutes
        )
    }
}

/// The configurations used to print to PDF
///
/// - Parameters:
///   - paperSize: The size of the paper.
///   - margins: The margins that are applied to each page of the PDF.
///   - baseURL: The base URL to use when the system resolves relative URLs within the HTML string of the PDF.
///
public struct PDFConfiguration: Sendable {
    public let paperSize: CGSize
    public let margins: EdgeInsets
    public let baseURL: URL?

    public init(
        paperSize: CGSize = .a4,
        margins: EdgeInsets = .standard,
        baseURL: URL? = nil
    ) {
        self.paperSize = paperSize
        self.margins = margins
        self.baseURL = baseURL
    }
}

extension PDFConfiguration {
    // Common presets with standard margins
    public static let a4 = PDFConfiguration(paperSize: .a4, margins: .standard)
    public static let a4Narrow = PDFConfiguration(paperSize: .a4, margins: .minimal)
    public static let a4Wide = PDFConfiguration(paperSize: .a4, margins: .wide)

    public static let letter = PDFConfiguration(paperSize: .letter, margins: .standard)
    public static let letterNarrow = PDFConfiguration(paperSize: .letter, margins: .minimal)
    public static let letterWide = PDFConfiguration(paperSize: .letter, margins: .wide)

    public static let a3 = PDFConfiguration(paperSize: .a3, margins: .standard)
    public static let legal = PDFConfiguration(paperSize: .legal, margins: .standard)

    // Fluent API for modifications
    public func with(margins: EdgeInsets) -> PDFConfiguration {
        PDFConfiguration(paperSize: self.paperSize, margins: margins, baseURL: self.baseURL)
    }

    public func with(paperSize: CGSize) -> PDFConfiguration {
        PDFConfiguration(paperSize: paperSize, margins: self.margins, baseURL: self.baseURL)
    }

    public func with(baseURL: URL?) -> PDFConfiguration {
        PDFConfiguration(paperSize: self.paperSize, margins: self.margins, baseURL: baseURL)
    }

    // Convenient transforms
    public func landscape() -> PDFConfiguration {
        let newSize = CGSize(
            width: max(paperSize.width, paperSize.height),
            height: min(paperSize.width, paperSize.height)
        )
        return with(paperSize: newSize)
    }

    public func portrait() -> PDFConfiguration {
        let newSize = CGSize(
            width: min(paperSize.width, paperSize.height),
            height: max(paperSize.width, paperSize.height)
        )
        return with(paperSize: newSize)
    }

    /// Generates CSS for margins
    func generateMarginCSS() -> String {
        return """
        <style>
        @media print, screen {
            html, body {
                margin: 0;
                padding: 0;
                width: 100%;
                height: 100%;
            }
            body {
                padding-top: \(margins.top)pt !important;
                padding-right: \(margins.right)pt !important;
                padding-bottom: \(margins.bottom)pt !important;
                padding-left: \(margins.left)pt !important;
                box-sizing: border-box !important;
            }
        }
        </style>
        """
    }
}

public struct EdgeInsets: Sendable {
    public let top: CGFloat
    public let left: CGFloat
    public let bottom: CGFloat
    public let right: CGFloat

    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    // Convenience initializers
    public init(all: CGFloat) {
        self.init(top: all, left: all, bottom: all, right: all)
    }

    public init(horizontal: CGFloat, vertical: CGFloat) {
        self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}

extension EdgeInsets {
    // Named presets
    public static let none = EdgeInsets(all: 0)
    public static let minimal = EdgeInsets(all: 18)  // 0.25 inch
    public static let standard = EdgeInsets(all: 36) // 0.5 inch (default)
    public static let comfortable = EdgeInsets(all: 54) // 0.75 inch
    public static let wide = EdgeInsets(all: 72)    // 1 inch

    // Legacy compatibility
    public static let a4 = standard
}

extension CGSize {
    // ISO 216 sizes (in points)
    public static let a3 = CGSize(width: 841.89, height: 1190.55)
    public static let a4 = CGSize(width: 595.28, height: 841.89)
    public static let a5 = CGSize(width: 420.94, height: 595.28)

    // US sizes (in points)
    public static let letter = CGSize(width: 612, height: 792)
    public static let legal = CGSize(width: 612, height: 1008)
    public static let tabloid = CGSize(width: 792, height: 1224)

    // Convenience computed properties
    public var isLandscape: Bool { width > height }
    public var isPortrait: Bool { height >= width }

}
