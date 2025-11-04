//
//  PDF.Render.Client+macOS.swift
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
    @preconcurrency import AppKit
    import CoreGraphics
    import LoggingExtras

    extension PDF.Render: DependencyKey {
        public static let liveValue = PDF.Render(
            client: .macOS,
            configuration: .default,
            metrics: .liveValue
        )
    }

    // MARK: - Directory Cache
    // DirectoryCache is now in DirectoryCache.swift (shared across platforms)

    // MARK: - NSPrintInfo Cache

    /// Pre-configured NSPrintInfo cache to avoid repeated setup overhead
    ///
    /// Thread Safety: This type is `@unchecked Sendable` because:
    /// - It is isolated to the MainActor, preventing concurrent access
    /// - The cache dictionary is only accessed from the main actor
    /// - NSPrintOperation internally copies NSPrintInfo, so shared references are safe
    @MainActor private final class PrintInfoCache: @unchecked Sendable {
        private var cache: [String: NSPrintInfo] = [:]

        func get(for config: PDF.Configuration) -> NSPrintInfo {
            let key = cacheKey(for: config)

            if let cached = cache[key] {
                // NSPrintOperation copies NSPrintInfo internally, so no need to copy here
                return cached
            }

            // Create and cache new print info
            let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo.shared
            printInfo.paperSize = config.paperSize
            printInfo.topMargin = config.margins.top
            printInfo.leftMargin = config.margins.left
            printInfo.bottomMargin = config.margins.bottom
            printInfo.rightMargin = config.margins.right
            printInfo.jobDisposition = .save

            cache[key] = printInfo
            // NSPrintOperation copies NSPrintInfo internally, so no need to copy here
            return printInfo
        }

        private func cacheKey(for config: PDF.Configuration) -> String {
            // Create cache key from relevant print properties
            "\(config.paperSize.width)x\(config.paperSize.height)_\(config.margins.top)_\(config.margins.left)_\(config.margins.bottom)_\(config.margins.right)"
        }
    }

    /// Shared print info cache accessor
    @MainActor private func getPrintInfoCache() -> PrintInfoCache {
        struct Static { @MainActor static let cache: PrintInfoCache = { PrintInfoCache() }() }
        return Static.cache
    }

    // MARK: - Client Implementation

    extension PDF.Render.Client {
        /// macOS-specific implementation using WKWebView and NSPrintOperation
        public static let macOS = PDF.Render.Client(documents: { documents in
            @Dependency(\.pdf.render.configuration) var config
            return try await renderDocumentsInternal(documents, config: config)
        })
    }

    // MARK: - Internal Implementation

    extension PDF.Document {
        @MainActor func renderInternal(
            config: PDF.Configuration
        ) async throws -> (url: URL, pageCount: Int, dimensions: [CGSize], mode: PDF.PaginationMode)
        {
            @Dependency(\.webViewPool) var webViewPool
            let pool = try await webViewPool.pool
            return try await renderWithPool(pool, config: config)
        }

        func renderWithPool(
            _ pool: ResourcePool<WKWebViewResource>,
            config: PDF.Configuration
        ) async throws -> (url: URL, pageCount: Int, dimensions: [CGSize], mode: PDF.PaginationMode)
        {
            let parentDirectory = self.destination.deletingLastPathComponent()

            // Directory validation with synchronous lock-based cache (low overhead)
            try directoryCache.ensureDirectory(
                at: parentDirectory,
                createIfNeeded: config.createDirectories
            )

            let destination = self.destination
            let html = self.html

            // Track pool utilization
            await ActiveOperationsTracker.shared.increment()
            defer { Task { await ActiveOperationsTracker.shared.decrement() } }

            let poolStart = ContinuousClock.now
            return try await pool.withResource(
                timeout: .seconds(config.webViewAcquisitionTimeout.components.seconds)
            ) { @Sendable resource in
                let poolTime = ContinuousClock.now - poolStart

                // Record pool acquisition time
                @Dependency(\.pdf.render.metrics) var metrics
                metrics.recordPoolAcquisitionTime(poolTime)

                // Pre-compute CSS injection OFF the MainActor to reduce contention
                let cssStart = ContinuousClock.now
                let marginCSS = generateMarginCSS(config)
                var htmlWithCSS = await html.injectingCSS(marginCSS)

                // Inject appearance CSS if needed
                if let appearanceCSS = config.appearance.cssInjection {
                    htmlWithCSS = await htmlWithCSS.injectingCSS(appearanceCSS)
                }

                let dataStart = ContinuousClock.now
                let htmlData = htmlWithCSS.toData()
                let cssAndDataTime = ContinuousClock.now - cssStart
                let dataTime = ContinuousClock.now - dataStart

                // Record CSS and data conversion time (done off MainActor)
                metrics.recordCSSInjectionTime(cssAndDataTime - dataTime)
                metrics.recordDataConversionTime(dataTime)

                let renderStart = ContinuousClock.now
                let document = PDF.Document(html: html, destination: destination)
                let (pageCount, dimensions, mode) = try await document.renderWithWebView(
                    resource.webView,
                    config: config,
                    preComputedHTML: htmlData
                )
                let renderTime = ContinuousClock.now - renderStart

                // Record WebView render time (now excludes CSS injection - only WebKit + file I/O)
                metrics.recordWebViewRenderTime(renderTime)

                return (destination, pageCount, dimensions, mode)
            }
        }

        @MainActor private func renderWithWebView(
            _ webView: WKWebView,
            config: PDF.Configuration,
            preComputedHTML: Data? = nil
        ) async throws -> (pageCount: Int, dimensions: [CGSize], mode: PDF.PaginationMode) {
            let delegate = WebViewNavigationDelegate(
                outputURL: self.destination,
                configuration: config
            )

            webView.navigationDelegate = delegate

            return try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<(Int, [CGSize], PDF.PaginationMode), Error>) in
                let handler = PageInfoContinuationHandler()

                let timeoutTask: Task<Void, Never>?
                if let timeout = config.documentTimeout {
                    timeoutTask = Task {
                        try? await Task.sleep(for: timeout)
                        await handler.resumeIfNeeded(
                            continuation,
                            with: .failure(
                                PrintingError.documentTimeout(
                                    documentURL: self.destination,
                                    timeoutSeconds: Double(timeout.components.seconds)
                                )
                            )
                        )
                    }
                } else {
                    timeoutTask = nil
                }

                let printDelegate = PrintDelegate(
                    onFinished: { pageCount, dimensions, mode in
                        timeoutTask?.cancel()
                        Task {
                            await handler.resumeIfNeeded(
                                continuation,
                                with: .success((pageCount, dimensions, mode))
                            )
                        }
                    },
                    onError: { error in
                        timeoutTask?.cancel()
                        Task { await handler.resumeIfNeeded(continuation, with: .failure(error)) }
                    }
                )
                delegate.printDelegate = printDelegate

                // Load HTML - using pre-computed if available (fast path) or compute now (legacy path)
                if let preComputedHTML = preComputedHTML {
                    // Fast path: Pre-computed HTML (CSS already injected off MainActor)
                    webView.load(
                        preComputedHTML,
                        mimeType: "text/html",
                        characterEncodingName: "UTF-8",
                        baseURL: config.baseURL ?? URL(string: "about:blank")!
                    )
                } else {
                    // Legacy path: CSS injection on MainActor (slower)
                    Task {
                        let cssStart = ContinuousClock.now
                        let marginCSS = generateMarginCSS(config)
                        var htmlToLoad = await self.html.injectingCSS(marginCSS)

                        // Inject appearance CSS if needed
                        if let appearanceCSS = config.appearance.cssInjection {
                            htmlToLoad = await htmlToLoad.injectingCSS(appearanceCSS)
                        }
                        let cssTime = ContinuousClock.now - cssStart

                        let dataStart = ContinuousClock.now
                        let htmlData = htmlToLoad.toData()
                        let dataTime = ContinuousClock.now - dataStart

                        // Record timing metrics
                        @Dependency(\.pdf.render.metrics) var metrics
                        metrics.recordCSSInjectionTime(cssTime)
                        metrics.recordDataConversionTime(dataTime)

                        let _ = await MainActor.run {
                            webView.load(
                                htmlData,
                                mimeType: "text/html",
                                characterEncodingName: "UTF-8",
                                baseURL: config.baseURL ?? URL(string: "about:blank")!
                            )
                        }
                    }
                }
            }
        }
    }

    private func renderDocumentsInternal(
        _ documents: some Sequence<PDF.Document>,
        config: PDF.Configuration
    ) async throws -> AsyncThrowingStream<PDF.Render.Result, Error> {
        // Materialize sequence for indexing and count operations (before Task to avoid Sendable issues)
        let documentsArray = Array(documents)

        // Get the pool ONCE at the beginning, not for every document
        // Pool access doesn't require main actor
        @Dependency(\.webViewPool) var webViewPool
        @Dependency(\.pdf.render.metrics) var metrics
        @Dependency(\.logger) var logger

        let pool = try await webViewPool.pool
        let maxConcurrent = config.concurrency.resolved

        // Capture a reference to the dependencies
        let metricsRef = metrics
        let loggerRef = logger

        return AsyncThrowingStream<PDF.Render.Result, Error> { continuation in
            Task {
                var completedCount = 0
                do {
                    try await withThrowingTaskGroup(
                        of: (Int, URL, Int, [CGSize], PDF.PaginationMode, Duration).self
                    ) { taskGroup in
                        for (index, document) in documentsArray.prefix(maxConcurrent).enumerated() {
                            taskGroup.addTask {
                                let start = ContinuousClock.now
                                // renderWithPool handles main actor isolation internally for WebView operations
                                let (url, pageCount, dimensions, mode) =
                                    try await document.renderWithPool(pool, config: config)
                                let duration = ContinuousClock.now - start
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
                                    let (url, pageCount, dimensions, mode) =
                                        try await document.renderWithPool(pool, config: config)
                                    let duration = ContinuousClock.now - start
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

    private func generateMarginCSS(_ config: PDF.Configuration) -> ContiguousArray<UInt8> {
        // Margin handling differs based on pagination mode:
        // - Paginated mode: Margins handled by NSPrintInfo
        // - Continuous mode: Margins applied via CSS padding
        //
        // Since we don't know the mode yet (determined after loading),
        // we apply CSS padding and NSPrintInfo will override when used
        //
        // Use pre-computed CSS from configuration to avoid repeated string interpolation
        return config.marginCSSBytes
    }

    // MARK: - Supporting Classes (from existing implementation)

    private actor ContinuationHandler {
        private var hasResumed = false

        func resumeIfNeeded(
            _ continuation: CheckedContinuation<Void, Error>,
            with result: Result<Void, Error>
        ) {
            guard !hasResumed else { return }
            hasResumed = true

            switch result {
            case .success: continuation.resume()
            case .failure(let error): continuation.resume(throwing: error)
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
            case .success(let value): continuation.resume(returning: value)
            case .failure(let error): continuation.resume(throwing: error)
            }
        }
    }

    /// Extract page info from PDF data using Core Graphics (faster than PDFKit)
    /// Thread-safe, can run off main actor. Avoids PDFDocument allocation/caching overhead.
    private func extractPageInfoFromData(_ pdfData: Data) -> (pageCount: Int, dimensions: [CGSize])
    {
        guard let provider = CGDataProvider(data: pdfData as CFData),
            let pdfDoc = CGPDFDocument(provider)
        else { return (0, []) }

        let pageCount = pdfDoc.numberOfPages
        var dimensions: [CGSize] = []
        dimensions.reserveCapacity(pageCount)

        for pageIndex in 1...pageCount {
            guard let page = pdfDoc.page(at: pageIndex) else { continue }
            let mediaBox = page.getBoxRect(.mediaBox)
            dimensions.append(mediaBox.size)
        }

        return (pageCount, dimensions)
    }

    private class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
        private let outputURL: URL
        var printDelegate: PrintDelegate?
        private let configuration: PDF.Configuration

        init(outputURL: URL, configuration: PDF.Configuration) {
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
                    case .webView: renderWithWebViewCreatePDF(webView, strategy: strategy)
                    case .printOperation: renderWithNSPrintOperation(webView, strategy: strategy)
                    }
                } catch {
                    printDelegate?.onError?(
                        PrintingError.pdfGenerationFailed(underlyingError: error)
                    )
                }
            }
        }

        @MainActor private func chooseRenderingStrategy(
            webView: WKWebView,
            config: PDF.Configuration
        ) async throws -> PDF.InternalRenderingMethod {

            switch config.paginationMode {
            case .paginated: return .printOperation

            case .continuous: return .webView

            case .automatic(let heuristic):
                switch heuristic {
                case .contentLength(let threshold):
                    // Measure content height
                    let height =
                        try await webView.evaluateJavaScript(
                            "document.documentElement.scrollHeight"
                        ) as? CGFloat ?? 0

                    let pageHeight =
                        config.paperSize.height - (config.margins.top + config.margins.bottom)
                    let estimatedPages = height / pageHeight

                    return estimatedPages > threshold ? .printOperation : .webView

                case .htmlStructure:
                    // Check for print CSS indicators
                    let hasPrintCSS =
                        try await webView.evaluateJavaScript(
                            "!!document.querySelector('style[media*=\"print\"]')"
                        ) as? Bool ?? false

                    let hasPageBreaks =
                        try await webView.evaluateJavaScript(
                            "!!document.querySelector('[style*=\"page-break\"]')"
                        ) as? Bool ?? false

                    return (hasPrintCSS || hasPageBreaks) ? .printOperation : .webView

                case .preferSpeed: return .webView

                case .preferPrintReady: return .printOperation
                }
            }
        }

        private func renderWithWebViewCreatePDF(
            _ webView: WKWebView,
            strategy: PDF.InternalRenderingMethod
        ) {
            // Fast approach using WKWebView.createPDF
            // Creates continuous single-page PDFs

            // Set frame to paper size for proper layout
            webView.frame = CGRect(origin: .zero, size: configuration.paperSize)

            let pdfConfig = WKPDFConfiguration()
            pdfConfig.rect = nil  // Allow content to flow naturally

            webView.createPDF(configuration: pdfConfig) { [weak self] result in
                guard let self = self else { return }

                webView.navigationDelegate = nil

                switch result {
                case .success(let data):
                    // Move file I/O and page extraction off main actor to reduce contention
                    Task.detached(priority: .userInitiated) {
                        [
                            outputURL = self.outputURL,
                            paginationMode = self.configuration.paginationMode
                        ] in
                        do {
                            // Write atomically to prevent partial PDFs
                            try writeAtomically(data, to: outputURL)

                            // Extract page info (PDFDocument is thread-safe)
                            let (pageCount, dimensions) = extractPageInfoFromData(data)

                            // Resume on main actor only for callback
                            await MainActor.run {
                                self.printDelegate?.onFinished(
                                    pageCount,
                                    dimensions,
                                    paginationMode
                                )
                            }
                        } catch {
                            await MainActor.run {
                                self.printDelegate?.onError?(
                                    PrintingError.pdfGenerationFailed(underlyingError: error)
                                ) ?? self.printDelegate?.onFinished(0, [], paginationMode)
                            }
                        }
                    }
                case .failure(let error):
                    self.printDelegate?.onError?(
                        PrintingError.pdfGenerationFailed(underlyingError: error)
                    ) ?? self.printDelegate?.onFinished(0, [], self.configuration.paginationMode)
                }
            }
        }

        private func renderWithNSPrintOperation(
            _ webView: WKWebView,
            strategy: PDF.InternalRenderingMethod
        ) {
            // Slower but accurate approach using NSPrintOperation
            // Guarantees correct page dimensions for multi-page PDFs

            // Use cached print info to avoid repeated setup overhead
            let printInfo = getPrintInfoCache().get(for: configuration)

            // Set output URL (not cached since it's unique per document)
            printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = self.outputURL

            // Create print operation from WebView
            let printOperation = webView.printOperation(with: printInfo)

            // CRITICAL: Set frame to paper size - WebKit layouts based on this
            printOperation.view?.frame = NSRect(origin: .zero, size: configuration.paperSize)

            // Run WITHOUT showing UI
            printOperation.showsPrintPanel = false
            printOperation.showsProgressPanel = false

            // Run asynchronously on a background thread to avoid blocking main thread
            DispatchQueue.global(qos: .userInitiated).async {
                [
                    weak self, weak webView, paperSize = configuration.paperSize,
                    mode = configuration.paginationMode
                ] in
                guard let self = self else { return }

                let success = printOperation.run()

                DispatchQueue.main.async {
                    webView?.navigationDelegate = nil

                    if success && FileManager.default.fileExists(atPath: self.outputURL.path) {
                        // Use paper size from configuration - all pages have same dimensions
                        let pageCount = printOperation.currentPage
                        let dimensions = Array(repeating: paperSize, count: max(1, pageCount))
                        self.printDelegate?.onFinished(pageCount, dimensions, mode)
                    } else {
                        let error = NSError(
                            domain: "PDFGeneration",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "PDF file was not created"]
                        )
                        self.printDelegate?.onError?(
                            PrintingError.pdfGenerationFailed(underlyingError: error)
                        ) ?? self.printDelegate?.onFinished(0, [], mode)
                    }
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) { printDelegate?.onError?(PrintingError.webViewNavigationFailed(underlyingError: error)) }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) { printDelegate?.onError?(PrintingError.webViewLoadingFailed(underlyingError: error)) }
    }

    /// Delegate for handling print operation completion and errors
    ///
    /// Thread Safety: This type is `@unchecked Sendable` because:
    /// - All stored properties are `@Sendable` closures
    /// - The closures are immutable after initialization
    /// - Callbacks are invoked from WebKit's navigation delegate which properly handles thread safety
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
