//
//  swift-html-to-pdf | macOS.swift
//
//
//  Created by Coen ten Thije Boonkkamp on 15/07/2024.
//

#if os(macOS)
import Foundation
import WebKit
import Dependencies

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
    ///   - configuration: The configuration that the PDFs will use.
    ///   - processorCount: In allmost all circumstances you can omit this parameter.
    ///   - createDirectories: If true, the function will call FileManager.default.createDirectory for each document's directory.
    ///
    /// - Throws: `Error` if the function cannot write to the document's fileUrl.
    @MainActor
    public func print(
        configuration: PDFConfiguration,
        printingConfiguration: PrintingConfiguration = .default,
        createDirectories: Bool = true
    ) async throws {
        try await [self].print(
            configuration: configuration,
            printingConfiguration: printingConfiguration,
            createDirectories: createDirectories
        )
    }
}

#if os(macOS)
extension Sequence<Document> {
    /// Prints ``Document``s  to PDFs at the given directory.
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
    ///   - configuration: The configuration that the PDFs will use.
    ///   - printingConfiguration: Configuration for printing behavior and resource management.
    ///   - createDirectories: If true, the function will call FileManager.default.createDirectory for each document's directory.
    ///

    public func print(
        configuration: PDFConfiguration,
        printingConfiguration: PrintingConfiguration = .default,
        createDirectories: Bool = true
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            // First add all tasks to the group
            for document in self {
                taskGroup.addTask {
                    @Dependency(\.webViewPool) var webViewPool
                    let webView = try await webViewPool.acquireWithRetry(8, printingConfiguration.webViewAcquisitionTimeout / 8)
                    do {
                        try await document.print(
                            configuration: configuration,
                            documentTimeout: printingConfiguration.documentTimeout,
                            createDirectories: createDirectories,
                            using: webView
                        )
                    } catch {
                        // Always release the webView even if printing fails
                        await webViewPool.releaseWebView(webView)
                        throw error
                    }
                    await webViewPool.releaseWebView(webView)
                }
            }
            // Then wait for all tasks to complete
            try await taskGroup.waitForAll()
        }
    }
}
#endif

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

extension Document {
    @MainActor
    fileprivate func print(
        configuration: PDFConfiguration,
        documentTimeout: TimeInterval? = nil,
        createDirectories: Bool = true,
        using webView: WKWebView? = nil
    ) async throws {
        // Use provided webView (from pool) or fallback to creating one
        let webView = webView ?? WKWebView(frame: .zero)

        let webViewNavigationDelegate = WebViewNavigationDelegate(
            outputURL: self.fileUrl,
            configuration: configuration
        )

        if createDirectories {
            try FileManager.default.createDirectory(at: self.fileUrl.deletingPathExtension().deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        webView.navigationDelegate = webViewNavigationDelegate

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let handler = ContinuationHandler()

            let timeoutTask: Task<Void, Never>?
            if let timeout = documentTimeout {
                timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    await handler.resumeIfNeeded(continuation, with: .failure(
                        PrintingError.documentTimeout(documentURL: self.fileUrl, timeoutSeconds: timeout)
                    ))
                }
            } else {
                timeoutTask = nil
            }

            let printDelegate = PrintDelegate(
                onFinished: {
                    timeoutTask?.cancel()
                    Task {
                        await handler.resumeIfNeeded(continuation, with: .success(()))
                    }
                },
                onError: { error in
                    timeoutTask?.cancel()
                    Task {
                        await handler.resumeIfNeeded(continuation, with: .failure(error))
                    }
                }
            )
            webViewNavigationDelegate.printDelegate = printDelegate

            // Inject margin CSS
            let marginCSS = configuration.generateMarginCSS()
            let htmlToLoad = self.html.injectingCSS(marginCSS)

            webView.loadHTMLString(htmlToLoad, baseURL: configuration.baseURL)
        }
    }
}


class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private let outputURL: URL
    var printDelegate: PrintDelegate?

    private let configuration: PDFConfiguration

    init(
        outputURL: URL,
        onFinished: (@Sendable () -> Void)? = nil,
        configuration: PDFConfiguration
    ) {
        self.outputURL = outputURL
        self.configuration = configuration
        self.printDelegate = onFinished.map(PrintDelegate.init)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [configuration, outputURL, printDelegate] in
            // Only add a small delay if content might need rendering time
            // Most HTML is ready immediately after didFinish
            webView.frame = .init(origin: .zero, size: configuration.paperSize)

            // Create WKPDFConfiguration
            let pdfConfig = WKPDFConfiguration()

            // Use full paper size, margins handled by CSS
            pdfConfig.rect = CGRect(origin: .zero, size: configuration.paperSize)

            // Export to PDF directly without using NSPrintOperation
            webView.createPDF(configuration: pdfConfig) { [weak webView] result in
                // Clear navigation delegate immediately to prevent further callbacks
                webView?.navigationDelegate = nil

                switch result {
                case .success(let data):
                    do {
                        try data.write(to: outputURL)
                        printDelegate?.onFinished()
                    } catch {
                        printDelegate?.onError?(error) ?? printDelegate?.onFinished()
                    }
                case .failure(let error):
                    printDelegate?.onError?(error) ?? printDelegate?.onFinished()
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


class PrintDelegate: @unchecked Sendable {

    var onFinished: @Sendable () -> Void
    var onError: (@Sendable (Error) -> Void)?

    init(onFinished: @Sendable @escaping () -> Void, onError: (@Sendable (Error) -> Void)? = nil) {
        self.onFinished = onFinished
        self.onError = onError
    }

    convenience init(onFinished: @Sendable @escaping () -> Void) {
        self.init(onFinished: onFinished, onError: nil)
    }

    @objc func printOperationDidRun(_ printOperation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        if success {
            self.onFinished()
        } else {
            let error = PrintingError.printOperationFailed(success: success, underlyingError: nil)
            self.onError?(error) ?? self.onFinished()
        }
    }
}


extension NSEdgeInsets {
    init(
        edgeInsets: EdgeInsets
    ) {
        self = .init(
            top: edgeInsets.top,
            left: edgeInsets.left,
            bottom: edgeInsets.bottom,
            right: edgeInsets.right
        )
    }
}

extension CGSize {
    public static func paperSize() -> CGSize {
        CGSize(width: NSPrintInfo.shared.paperSize.width, height: NSPrintInfo.shared.paperSize.height)
    }
}

extension NSPrintInfo {
    static func pdf(jobSavingURL: URL, configuration: PDFConfiguration) -> NSPrintInfo {
        return NSPrintInfo(
            dictionary: [
                .jobDisposition: NSPrintInfo.JobDisposition.save,
                .jobSavingURL: jobSavingURL,
                .allPages: true,
                .topMargin: configuration.margins.top,
                .bottomMargin: configuration.margins.bottom,
                .leftMargin: configuration.margins.left,
                .rightMargin: configuration.margins.right,
                .paperSize: configuration.paperSize,
                .verticalPagination: NSNumber(value: NSPrintInfo.PaginationMode.automatic.rawValue)
            ]
        )
    }
}

#endif
