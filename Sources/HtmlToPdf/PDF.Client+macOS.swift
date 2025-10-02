//
//  PDF.Client+macOS.swift
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

extension PDF.Client: DependencyKey {
    public static let liveValue: Self = .macOS
}

extension PDF.Client {
    /// macOS-specific implementation using WKWebView and NSPrintOperation
    public static let macOS = PDF.Client(
        render: { html, destination in
            @Dependency(\.pdfConfiguration) var config
            let document = PDF.Document(htmlString: html, destination: destination)
            let (url, _, _, _) = try await document.renderInternal(config: config)
            return url
        },

        renderWithTitle: { html, title, directory in
            @Dependency(\.pdfConfiguration) var config
            let document = PDF.Document(htmlString: html, title: title, in: directory)
            let (url, _, _, _) = try await document.renderInternal(config: config)
            return url
        },

        renderToData: { html in
            @Dependency(\.pdfConfiguration) var config
            let htmlBytes = ContiguousArray(html.utf8)
            return try await renderHTMLToData(htmlBytes, config: config)
        },

        renderDocument: { document in
            @Dependency(\.pdfConfiguration) var config
            let (url, _, _, _) = try await document.renderInternal(config: config)
            return url
        },

        renderBatch: { htmls, directory in
            @Dependency(\.pdfConfiguration) var config

            let documents = htmls.enumerated().map { index, html in
                let filename = config.namingStrategy.filename(for: index)
                return PDF.Document(htmlString: html, title: filename, in: directory)
            }

            return try await renderDocumentsInternal(documents, config: config)
        },

        renderDocuments: { documents in
            @Dependency(\.pdfConfiguration) var config
            return try await renderDocumentsInternal(documents, config: config)
        },

        renderBatchSync: { htmls, directory in
            @Dependency(\.pdfConfiguration) var config

            let documents = htmls.enumerated().map { index, html in
                let filename = config.namingStrategy.filename(for: index)
                return PDF.Document(htmlString: html, title: filename, in: directory)
            }

            let stream = try await renderDocumentsInternal(documents, config: config)

            var urls: [URL] = []
            for try await result in stream {
                urls.append(result.url)
            }
            return urls
        },

        capabilities: {
            .macOS
        }
    )
}

// MARK: - Internal Implementation

@MainActor
private func renderHTMLToData(
    _ htmlBytes: ContiguousArray<UInt8>,
    config: PDF.Configuration
) async throws -> Data {
    let webView = WKWebView(frame: .zero)

    return try await withCheckedThrowingContinuation { continuation in
        let marginCSS = generateMarginCSS(config)
        let htmlToLoad = htmlBytes.injectingCSS(marginCSS)
        let htmlData = htmlToLoad.toData()

        webView.load(
            htmlData,
            mimeType: "text/html",
            characterEncodingName: "UTF-8",
            baseURL: config.baseURL ?? URL(string: "about:blank")!
        )

        // Wait for load completion (simplified - production would need proper delegate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Set frame to paper size for proper layout
            webView.frame = CGRect(origin: .zero, size: config.paperSize)

            let pdfConfig = WKPDFConfiguration()
            // Use nil to allow multi-page pagination
            // The webView.frame determines the layout width, enabling natural page breaks
            pdfConfig.rect = nil

            webView.createPDF(configuration: pdfConfig) { result in
                continuation.resume(with: result)
            }
        }
    }
}

@MainActor
extension PDF.Document {
    func renderInternal(config: PDF.Configuration) async throws -> (url: URL, pageCount: Int, dimensions: [CGSize], mode: PDF.PaginationMode) {
        @Dependency(\.webViewPool) var webViewPool
        let pool = try await webViewPool.pool
        return try await renderWithPool(pool, config: config)
    }

    func renderWithPool(
        _ pool: ResourcePool<WKWebViewResource>,
        config: PDF.Configuration
    ) async throws -> (url: URL, pageCount: Int, dimensions: [CGSize], mode: PDF.PaginationMode) {
        if config.createDirectories {
            try FileManager.default.createDirectory(
                at: self.destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

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

            let marginCSS = generateMarginCSS(config)
            let htmlToLoad = self.html.injectingCSS(marginCSS)
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

private func renderDocumentsInternal(
    _ documents: [PDF.Document],
    config: PDF.Configuration
) async throws -> AsyncThrowingStream<PDF.Result, Error> {
    AsyncThrowingStream<PDF.Result, Error> { continuation in
        Task { @MainActor in
            do {
                // Get the pool ONCE at the beginning, not for every document
                @Dependency(\.webViewPool) var webViewPool
                let pool = try await webViewPool.pool

                let maxConcurrent = config.concurrency ??
                    Swift.min(ProcessInfo.processInfo.activeProcessorCount, 8)

                var completedCount = 0

                try await withThrowingTaskGroup(of: (Int, URL, Int, [CGSize], PDF.PaginationMode, Duration).self) { taskGroup in
                    for (index, document) in documents.prefix(maxConcurrent).enumerated() {
                        taskGroup.addTask {
                            let start = ContinuousClock.now
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

                        if nextIndex < documents.count {
                            let document = documents[nextIndex]
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
            } catch {
                continuation.finish(throwing: error)
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

    let css = """
    <style>
    @media print, screen {
        html {
            margin: 0;
            padding: 0;
        }
        body {
            margin: 0;
            padding: \(config.margins.top)pt \(config.margins.right)pt \(config.margins.bottom)pt \(config.margins.left)pt;
            box-sizing: border-box;
        }
    }
    </style>
    """
    return ContiguousArray(css.utf8)
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
                do {
                    try data.write(to: self.outputURL)

                    // Extract page information
                    let (pageCount, dimensions) = self.extractPageInfo(from: data)
                    let mode = self.configuration.paginationMode

                    self.printDelegate?.onFinished(pageCount, dimensions, mode)
                } catch {
                    self.printDelegate?.onError?(PrintingError.pdfGenerationFailed(underlyingError: error))
                        ?? self.printDelegate?.onFinished(0, [], self.configuration.paginationMode)
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

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo

        // Configure paper size and margins
        printInfo.paperSize = configuration.paperSize
        printInfo.topMargin = configuration.margins.top
        printInfo.leftMargin = configuration.margins.left
        printInfo.bottomMargin = configuration.margins.bottom
        printInfo.rightMargin = configuration.margins.right

        // Set to save mode (no UI)
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = self.outputURL

        // Create print operation from WebView
        let printOperation = webView.printOperation(with: printInfo)

        // CRITICAL: Set frame to paper size - WebKit layouts based on this
        printOperation.view?.frame = NSRect(origin: .zero, size: configuration.paperSize)

        // Run WITHOUT showing UI
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false

        // Run asynchronously on a background thread to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak webView] in
            guard let self = self else { return }

            // Run the print operation
            let success = printOperation.run()

            DispatchQueue.main.async {
                webView?.navigationDelegate = nil

                if success && FileManager.default.fileExists(atPath: self.outputURL.path) {
                    // Extract page information from generated PDF
                    do {
                        let data = try Data(contentsOf: self.outputURL)
                        let (pageCount, dimensions) = self.extractPageInfo(from: data)
                        let mode = self.configuration.paginationMode

                        self.printDelegate?.onFinished(pageCount, dimensions, mode)
                    } catch {
                        // Fallback if we can't read the PDF
                        self.printDelegate?.onFinished(0, [], self.configuration.paginationMode)
                    }
                } else {
                    let error = NSError(domain: "PDFGeneration", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "PDF file was not created"])
                    self.printDelegate?.onError?(PrintingError.pdfGenerationFailed(underlyingError: error))
                        ?? self.printDelegate?.onFinished(0, [], self.configuration.paginationMode)
                }
            }
        }
    }

    private func extractPageInfo(from pdfData: Data) -> (pageCount: Int, dimensions: [CGSize]) {
        guard let pdfDoc = PDFDocument(data: pdfData) else {
            return (0, [])
        }

        let pageCount = pdfDoc.pageCount
        let dimensions = (0..<pageCount).compactMap { index -> CGSize? in
            pdfDoc.page(at: index)?.bounds(for: .mediaBox).size
        }

        return (pageCount, dimensions)
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
