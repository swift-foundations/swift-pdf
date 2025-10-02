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

extension PDF.Client: DependencyKey {
    public static let liveValue: Self = .macOS
}

extension PDF.Client {
    /// macOS-specific implementation using WKWebView and NSPrintOperation
    public static let macOS = PDF.Client(
        render: { html, destination in
            @Dependency(\.pdfConfiguration) var config
            let document = PDF.Document(htmlString: html, destination: destination)
            return try await document.renderInternal(config: config)
        },

        renderWithTitle: { html, title, directory in
            @Dependency(\.pdfConfiguration) var config
            let document = PDF.Document(htmlString: html, title: title, in: directory)
            return try await document.renderInternal(config: config)
        },

        renderToData: { html in
            @Dependency(\.pdfConfiguration) var config
            let htmlBytes = ContiguousArray(html.utf8)
            return try await renderHTMLToData(htmlBytes, config: config)
        },

        renderDocument: { document in
            @Dependency(\.pdfConfiguration) var config
            return try await document.renderInternal(config: config)
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
            // Set rect explicitly to control page size (CSS @page is not supported by WKWebView)
            // This ensures the PDF pages match the configured paper size
            pdfConfig.rect = CGRect(origin: .zero, size: config.paperSize)

            webView.createPDF(configuration: pdfConfig) { result in
                continuation.resume(with: result)
            }
        }
    }
}

@MainActor
extension PDF.Document {
    func renderInternal(config: PDF.Configuration) async throws -> URL {
        @Dependency(\.webViewPool) var webViewPool
        let pool = try await webViewPool.pool
        return try await renderWithPool(pool, config: config)
    }

    func renderWithPool(_ pool: ResourcePool<WKWebViewResource>, config: PDF.Configuration) async throws -> URL {
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
            try await document.renderWithWebView(
                resource.webView,
                config: config
            )
            return destination
        }
    }

    @MainActor
    private func renderWithWebView(
        _ webView: WKWebView,
        config: PDF.Configuration
    ) async throws {
        let delegate = WebViewNavigationDelegate(
            outputURL: self.destination,
            configuration: config
        )

        webView.navigationDelegate = delegate

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let handler = ContinuationHandler()

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

                try await withThrowingTaskGroup(of: (Int, URL, Duration).self) { taskGroup in
                    for (index, document) in documents.prefix(maxConcurrent).enumerated() {
                        taskGroup.addTask {
                            let start = ContinuousClock.now
                            let url = try await document.renderWithPool(pool, config: config)
                            let duration = ContinuousClock.now - start
                            return (index, url, duration)
                        }
                    }

                    var nextIndex = maxConcurrent

                    for try await (index, url, duration) in taskGroup {
                        completedCount += 1

                        let result = PDF.Result(
                            url: url,
                            index: index,
                            duration: duration
                        )
                        continuation.yield(result)

                        if nextIndex < documents.count {
                            let document = documents[nextIndex]
                            let capturedIndex = nextIndex
                            nextIndex += 1

                            taskGroup.addTask {
                                let start = ContinuousClock.now
                                let url = try await document.renderWithPool(pool, config: config)
                                let duration = ContinuousClock.now - start
                                return (capturedIndex, url, duration)
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
    // Note: WKWebView does NOT support CSS @page size directive
    // Page size is controlled via WKPDFConfiguration.rect instead
    // We only use CSS for body margins to create content padding

    let css = """
    <style>
    @media print, screen {
        html, body {
            margin: 0;
            padding: 0;
            width: 100%;
            height: auto;
        }

        body {
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
            // Set frame to paper size for proper layout
            webView.frame = CGRect(origin: .zero, size: configuration.paperSize)

            let pdfConfig = WKPDFConfiguration()
            // Set rect explicitly to control page size (CSS @page is not supported by WKWebView)
            // This ensures the PDF pages match the configured paper size
            pdfConfig.rect = CGRect(origin: .zero, size: configuration.paperSize)

            webView.createPDF(configuration: pdfConfig) { [weak webView] result in
                webView?.navigationDelegate = nil

                switch result {
                case .success(let data):
                    do {
                        try data.write(to: self.outputURL)
                        self.printDelegate?.onFinished()
                    } catch {
                        self.printDelegate?.onError?(error) ?? self.printDelegate?.onFinished()
                    }
                case .failure(let error):
                    self.printDelegate?.onError?(error) ?? self.printDelegate?.onFinished()
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
    var onFinished: @Sendable () -> Void
    var onError: (@Sendable (Error) -> Void)?

    init(onFinished: @Sendable @escaping () -> Void, onError: (@Sendable (Error) -> Void)? = nil) {
        self.onFinished = onFinished
        self.onError = onError
    }
}

#endif
