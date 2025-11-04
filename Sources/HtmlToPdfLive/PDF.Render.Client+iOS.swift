//
//  PDF.Render.Client+iOS.swift
//  swift-html-to-pdf
//
//  iOS-specific implementation using UIPrintPageRenderer
//

#if canImport(UIKit)
    import CoreGraphics
    import Dependencies
    import DependenciesMacros
    import Foundation
    import LoggingExtras
    import UIKit
    import WebKit

    extension PDF.Render: DependencyKey {
        public static let liveValue = PDF.Render(
            client: .iOS,
            configuration: .default,
            metrics: .liveValue
        )
    }

    extension PDF.Render.Client: DependencyKey { public static let liveValue: Self = .iOS }

    extension PDF.Render.Client {
        /// iOS-specific implementation using UIPrintPageRenderer
        public static let iOS = PDF.Render.Client(documents: { documents in
            @Dependency(\.pdf.render.configuration) var config
            return try await renderDocumentsInternal(documents, config: config)
        })
    }

    // MARK: - Internal Implementation

    @MainActor private func renderToDataWithFormatter(
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

    @MainActor extension PDF.Document {
        func renderInternal(config: PDF.Configuration) async throws -> URL {
            let parentDirectory = self.destination.deletingLastPathComponent()

            // Directory validation with thread-safe cache (shared across platforms)
            try directoryCache.ensureDirectory(
                at: parentDirectory,
                createIfNeeded: config.createDirectories
            )

            // Check if HTML contains images by searching for <img tag in bytes
            // Use WebView for images (proper rendering), PrintFormatter for text-only (faster)
            if self.html.containsImageTag() {
                return try await renderWithWebView(config: config)
            } else {
                return try await renderWithPrintFormatter(config: config)
            }
        }

        @MainActor private func renderWithPrintFormatter(
            config: PDF.Configuration
        ) async throws -> URL {
            // Convert bytes to String for UIMarkupTextPrintFormatter (only accepts String)
            let html = String(decoding: self.html, as: UTF8.self)
            let printFormatter = UIMarkupTextPrintFormatter(markupText: html)
            let data = try await renderToDataWithFormatter(printFormatter, config: config)
            try writeAtomically(data, to: self.destination)
            return self.destination
        }

        @MainActor private func renderWithWebView(config: PDF.Configuration) async throws -> URL {
            @Dependency(\.webViewPool) var webViewPool

            let pool = try await webViewPool.pool

            // Track pool utilization
            await ActiveOperationsTracker.shared.increment()
            defer { Task { await ActiveOperationsTracker.shared.decrement() } }

            return try await pool.withResource(
                timeout: .seconds(config.webViewAcquisitionTimeout.components.seconds)
            ) { @Sendable @MainActor resource in
                let webView = resource.webView
                let renderer = DocumentWKRenderer(document: self, configuration: config)

                try await renderer.render(using: webView, documentTimeout: config.documentTimeout)
                return self.destination
            }
        }
    }

    private func renderDocumentsInternal(
        _ documents: some Sequence<PDF.Document>,
        config: PDF.Configuration
    ) async throws -> AsyncThrowingStream<PDF.Render.Result, Error> {
        // Materialize sequence for indexing and count operations (before Task to avoid Sendable issues)
        let documentsArray = Array(documents)

        @Dependency(\.pdf.render.metrics) var metrics
        @Dependency(\.logger) var logger
        let metricsRef = metrics
        let loggerRef = logger

        return AsyncThrowingStream<PDF.Render.Result, Error> { continuation in
            Task {
                var completedCount = 0
                do {

                    let maxConcurrent = config.concurrency.resolved

                    try await withThrowingTaskGroup(
                        of: (Int, URL, Int, [CGSize], PDF.PaginationMode, Duration).self
                    ) { taskGroup in
                        for (index, document) in documentsArray.prefix(maxConcurrent).enumerated() {
                            taskGroup.addTask {
                                let start = ContinuousClock.now
                                let url = try await document.renderInternal(config: config)
                                let duration = ContinuousClock.now - start

                                // Extract actual page count and dimensions from generated PDF
                                let (pageCount, dimensions) = extractPageInfo(
                                    from: url,
                                    fallbackSize: config.paperSize
                                )
                                let mode = config.paginationMode
                                return (index, url, pageCount, dimensions, mode, duration)
                            }
                        }

                        var nextIndex = maxConcurrent

                        for try await (index, url, pageCount, dimensions, mode, duration)
                            in taskGroup
                        {
                            completedCount += 1

                            let result = PDF.Render.Result(
                                url: url,
                                index: index,
                                duration: duration,
                                paginationMode: mode,
                                pageCount: pageCount,
                                pageDimensions: dimensions
                            )

                            // Record metrics for successful PDF generation
                            metricsRef.recordSuccess(duration: duration, mode: mode)

                            continuation.yield(result)

                            if nextIndex < documentsArray.count {
                                let document = documentsArray[nextIndex]
                                let capturedIndex = nextIndex
                                nextIndex += 1

                                taskGroup.addTask {
                                    let start = ContinuousClock.now
                                    let url = try await document.renderInternal(config: config)
                                    let duration = ContinuousClock.now - start

                                    // Extract actual page count and dimensions from generated PDF
                                    let (pageCount, dimensions) = extractPageInfo(
                                        from: url,
                                        fallbackSize: config.paperSize
                                    )
                                    let mode = config.paginationMode
                                    return (
                                        capturedIndex, url, pageCount, dimensions, mode, duration
                                    )
                                }
                            }
                        }
                    }
                    continuation.finish()

                    // Clear directory cache after batch completes
                    directoryCache.clear()
                } catch {
                    // Record metrics for failed PDF generation
                    let printingError = error as? PrintingError
                    metricsRef.recordFailure(error: printingError)

                    loggerRef.error(
                        "Batch rendering failed",
                        metadata: [
                            "completed": "\(completedCount)", "total": "\(documentsArray.count)",
                            "error": "\(error)", "error_type": "\(type(of: error))",
                        ]
                    )
                    continuation.finish(throwing: error)

                    // Clear directory cache on error as well
                    directoryCache.clear()
                }
            }
        }
    }

    /// Extract page count and dimensions from PDF file using Core Graphics (faster than PDFKit)
    /// Thread-safe, can run off main actor. Avoids PDFDocument allocation/caching overhead.
    private func extractPageInfo(
        from url: URL,
        fallbackSize: CGSize
    ) -> (pageCount: Int, dimensions: [CGSize]) {
        guard let provider = CGDataProvider(url: url as CFURL), let pdfDoc = CGPDFDocument(provider)
        else { return (1, [fallbackSize]) }

        let pageCount = pdfDoc.numberOfPages
        var dimensions: [CGSize] = []
        dimensions.reserveCapacity(pageCount)

        for pageIndex in 1...pageCount {
            guard let page = pdfDoc.page(at: pageIndex) else { continue }
            let mediaBox = page.getBoxRect(.mediaBox)
            dimensions.append(mediaBox.size)
        }

        // Fallback if no pages found
        if dimensions.isEmpty { return (1, [fallbackSize]) }

        return (pageCount, dimensions)
    }

    // MARK: - WebView Renderer for Images

    @MainActor private class DocumentWKRenderer: NSObject, WKNavigationDelegate {
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

                // Perform CSS injection asynchronously (may use cache, matching macOS)
                Task {
                    let marginCSS = generateMarginCSS(self.configuration)
                    var htmlToLoad = await self.document.html.injectingCSS(marginCSS)

                    // Inject appearance CSS if needed
                    if let appearanceCSS = self.configuration.appearance.cssInjection {
                        htmlToLoad = await htmlToLoad.injectingCSS(appearanceCSS)
                    }

                    let htmlData = htmlToLoad.toData()

                    webView.load(
                        htmlData,
                        mimeType: "text/html",
                        characterEncodingName: "UTF-8",
                        baseURL: self.configuration.baseURL ?? URL(string: "about:blank")!
                    )
                }

                if let timeout = documentTimeout {
                    timeoutTask = Task { [weak self] in
                        do {
                            try await Task.sleep(for: timeout)

                            guard let self = self, let continuation = self.continuation else {
                                return
                            }

                            self.continuation = nil
                            let timeoutError = PrintingError.webViewRenderingTimeout(
                                timeoutSeconds: Double(timeout.components.seconds)
                            )
                            continuation.resume(throwing: timeoutError)
                        } catch {
                            if !(error is CancellationError) {
                                @Dependency(\.logger) var logger
                                logger.error(
                                    "Unexpected error in timeout task",
                                    metadata: [
                                        "error": "\(error)", "error_type": "\(type(of: error))",
                                    ]
                                )
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
                    let data = try await renderToDataWithFormatter(
                        printFormatter,
                        config: configuration
                    )
                    try writeAtomically(data, to: document.destination)
                    continuation.resume(returning: ())
                } catch { continuation.resume(throwing: error) }

                webView.navigationDelegate = nil
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: any Error
        ) {
            Task {
                guard let continuation = self.continuation else { return }
                self.continuation = nil
                self.timeoutTask?.cancel()

                continuation.resume(
                    throwing: PrintingError.webViewNavigationFailed(underlyingError: error)
                )
                webView.navigationDelegate = nil
            }
        }
    }

    // MARK: - CSS Generation

    private func generateMarginCSS(_ config: PDF.Configuration) -> ContiguousArray<UInt8> {
        // Use pre-computed CSS from configuration to avoid repeated string interpolation
        return config.marginCSSBytes
    }

    // MARK: - Byte-level Content Detection

    extension ContiguousArray where Element == UInt8 {
        /// Check if HTML bytes contain an <img tag (case-insensitive)
        func containsImageTag() -> Bool {
            // Search for "<img" in bytes (case-insensitive)
            // Convert both to lowercase for comparison
            let pattern: [UInt8] = [60, 105, 109, 103]  // "<img" in ASCII
            let patternUppercase: [UInt8] = [60, 73, 77, 71]  // "<IMG" in ASCII

            // Simple sliding window search
            guard self.count >= pattern.count else { return false }

            for i in 0...(self.count - pattern.count) {
                var matches = true
                for j in 0..<pattern.count {
                    let byte = self[i + j]
                    // Check if matches lowercase or uppercase pattern
                    if byte != pattern[j] && byte != patternUppercase[j] {
                        matches = false
                        break
                    }
                }
                if matches { return true }
            }
            return false
        }
    }

#endif
