//
//  swift-html-to-pdf | iOS.swift
//
//
//  Created by Coen ten Thije Boonkkamp on 15/07/2024.
//

#if canImport(UIKit)

import Foundation
import UIKit
import WebKit
import Dependencies

extension Sequence<Document> {
    /// Prints ``Document``s to PDFs with the given configuration.
    ///
    /// ## Example
    /// ```swift
    /// let documents = [
    ///     Document(...),
    ///     Document(...),
    ///     ...
    /// ]
    /// try await documents.print(configuration: .a4)
    /// ```
    ///
    /// - Parameters:
    ///   - configuration: The configuration that the PDFs will use.
    ///   - printingConfiguration: Configuration for printing behavior and resource management.
    ///   - createDirectories: If true, the function will call FileManager.default.createDirectory for each document's directory.
    ///
    @MainActor
    public func print(
        configuration: PDFConfiguration,
        printingConfiguration: PrintingConfiguration = .default,
        createDirectories: Bool = true
    ) async throws {
        let documents = Array(self)
        let maxConcurrent = printingConfiguration.maxConcurrentOperations ??
            Swift.min(ProcessInfo.processInfo.activeProcessorCount, 8)

        var completedCount = 0

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            // Add initial batch of tasks up to maxConcurrent
            for document in documents.prefix(maxConcurrent) {
                taskGroup.addTask {
                    try await document.print(
                        configuration: configuration,
                        printingConfiguration: printingConfiguration,
                        createDirectories: createDirectories
                    )
                }
            }

            var nextIndex = maxConcurrent

            // Process results and add new tasks as others complete
            for try await _ in taskGroup {
                completedCount += 1
                printingConfiguration.progressHandler?(completedCount, documents.count)

                // Add next document if any remain
                if nextIndex < documents.count {
                    let document = documents[nextIndex]
                    nextIndex += 1

                    taskGroup.addTask {
                        try await document.print(
                            configuration: configuration,
                            printingConfiguration: printingConfiguration,
                            createDirectories: createDirectories
                        )
                    }
                }
            }
        }
    }
}

extension Document {

    /// Prints a ``Document`` to PDF with the given configuration.
    ///
    /// This function is more convenient when you have a directory and just want to title the PDF and save it to the directory.
    ///
    /// ## Example
    /// ```swift
    /// try await Document.init(...)
    ///     .print(configuration: .a4)
    /// ```
    ///
    /// - Parameters:
    ///   - configuration: The configuration of the PDF document.
    ///
    /// - Throws: `Error` if the function cannot write to the document's fileUrl.
    @MainActor
    public func print(
        configuration: PDFConfiguration,
        printingConfiguration: PrintingConfiguration = .default,
        createDirectories: Bool = true
    ) async throws {

        if html.containsImages() {
            try await DocumentWKRenderer(
                document: self,
                configuration: configuration,
                createDirectories: createDirectories
            ).print(
                documentTimeout: printingConfiguration.documentTimeout,
                webViewAcquisitionTimeout: printingConfiguration.webViewAcquisitionTimeout
            )

        } else {
            try await print(
                configuration: configuration,
                createDirectories: createDirectories,
                printFormatter: UIMarkupTextPrintFormatter(markupText: self.html)
            )
        }
    }
}

extension String {
    /// Determines if the HTML string contains any `<img>` tags.
    /// - Returns: A boolean indicating whether the HTML contains images.
    func containsImages() -> Bool {
        // Use NSRegularExpression for iOS compatibility
        let pattern = "(?i)<img\\s+[^>]*src\\s*=\\s*[\"']([^\"']*?)[\"'][^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}

extension Error {
    /// Determines if the error is a cancellation error
    var isCancellationError: Bool {
        (self as? CancellationError) != nil
    }
}

extension Document {
    
    /// Internal method to print the document using a custom UIPrintFormatter.
    /// - Parameters:
    ///   - configuration: The PDF configuration for printing.
    ///   - createDirectories: Flag to create directories if they don't exist. Default is `true`.
    ///   - printFormatter: The formatter used for printing the document content.
    @MainActor
    internal func print(
        configuration: PDFConfiguration,
        createDirectories: Bool = true,
        printFormatter: UIPrintFormatter
    ) async throws {
        if createDirectories {
            try FileManager.default.createDirectory(at: self.fileUrl.deletingPathExtension().deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)

        let paperRect = CGRect(origin: .zero, size: configuration.paperSize)
        renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: configuration.printableRect), forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))

        let bounds = UIGraphicsGetPDFContextBounds()

        (0..<renderer.numberOfPages).forEach { index in
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: index, in: bounds)
        }

        UIGraphicsEndPDFContext()

        try pdfData.write(to: self.fileUrl)
    }
}

private class DocumentWKRenderer: NSObject, WKNavigationDelegate {
    private var document: Document
    private var configuration: PDFConfiguration
    private var createDirectories: Bool

    private var continuation: CheckedContinuation<Void, Error>?
    private weak var webView: WKWebView?
    private var timeoutTask: Task<Void, Error>?

    init(
        document: Document,
        configuration: PDFConfiguration,
        createDirectories: Bool
    ) {
        self.document = document
        self.configuration = configuration
        self.createDirectories = createDirectories
        super.init()
    }

    deinit {
        // Cancel timeout task
        timeoutTask?.cancel()

        // Resume continuation with error if still pending
        if let continuation = continuation {
            self.continuation = nil
            continuation.resume(throwing: CancellationError())
        }
    }
    
    @MainActor
    public func print(documentTimeout: TimeInterval? = nil, webViewAcquisitionTimeout: TimeInterval = 300) async throws {
        @Dependency(\.webViewPool) var webViewPool
        let webView = try await webViewPool.acquireWithRetry(8, webViewAcquisitionTimeout / 8)
        webView.navigationDelegate = self
        
        do {
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.webView = webView
                webView.loadHTMLString(self.document.html, baseURL: self.configuration.baseURL)
                
                if let timeout = documentTimeout {
                    timeoutTask = Task { [weak self] in
                        do {
                            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))

                            // Check if continuation still exists (not already completed)
                            guard let self = self,
                                  let continuation = self.continuation else { return }

                            self.continuation = nil
                            let timeoutError = PrintingError.webViewRenderingTimeout(timeoutSeconds: timeout)
                            continuation.resume(throwing: timeoutError)
                            await self.cleanup(webView: webView)
                        } catch {
                            // Task was cancelled, which is expected behavior
                            if !error.isCancellationError {
                                Swift.print("[DocumentWKRenderer] Unexpected error in timeout task: \(error)")
                            }
                        }
                    }
                } else {
                    timeoutTask = nil
                }
            }
        } catch {
            // If an error occurs, make sure to release the webView
            await cleanup(webView: webView)
            throw error
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task {
            // Prevent double-resume by clearing continuation atomically
            guard let continuation = self.continuation else { return }
            self.continuation = nil
            self.timeoutTask?.cancel()

            do {
                try await document.print(
                    configuration: configuration,
                    createDirectories: createDirectories,
                    printFormatter: webView.viewPrintFormatter()
                )
                continuation.resume(returning: ())
            } catch {
                continuation.resume(throwing: error)
            }
            await cleanup(webView: webView)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        Task {
            // Prevent double-resume by clearing continuation atomically
            guard let continuation = self.continuation else { return }
            self.continuation = nil
            self.timeoutTask?.cancel()

            continuation.resume(throwing: PrintingError.webViewNavigationFailed(underlyingError: error))
            await cleanup(webView: webView)
        }
    }
    
    @MainActor
    private func cleanup(webView: WKWebView) async {
        @Dependency(\.webViewPool) var webViewPool
        webView.navigationDelegate = nil
        await webViewPool.releaseWebView(webView)
    }
}

extension PDFConfiguration {
    public static func a4(margins: EdgeInsets) -> PDFConfiguration {
        return .init(
            margins: margins,
            paperSize: .a4()
        )
    }
}

extension CGSize {
    public static func paperSize() -> CGSize {
        CGSize(width: 595.22, height: 841.85)
    }
}

extension UIEdgeInsets {
    init(
        edgeInsets: EdgeInsets
    ) {
        self = .init(
            top: .init(edgeInsets.top),
            left: .init(edgeInsets.left),
            bottom: .init(edgeInsets.bottom),
            right: .init(edgeInsets.right)
        )
    }
}

#endif
