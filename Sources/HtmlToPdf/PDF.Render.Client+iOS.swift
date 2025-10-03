//
//  PDF.Render.Client+iOS.swift
//  swift-html-to-pdf
//
//  iOS-specific implementation using UIPrintPageRenderer
//

#if canImport(UIKit)
import Dependencies
import DependenciesMacros
import Foundation
import LoggingExtras
import UIKit
import WebKit

extension PDF.Render.Client: DependencyKey {
    public static let liveValue: Self = .iOS
}

extension PDF.Render.Client {
    /// iOS-specific implementation using UIPrintPageRenderer
    public static let iOS = PDF.Render.Client(
        documents: { documents in
            @Dependency(\.pdf.render.configuration) var config

            // Validate configuration against platform capabilities
            try validateConfiguration(config, against: .iOS)

            return try await renderDocumentsInternal(documents, config: config)
        },
        capabilities: {
            .iOS
        }
    )
}

// MARK: - Configuration Validation

/// Validate configuration against platform capabilities
private func validateConfiguration(_ config: PDF.Configuration, against capabilities: PDF.Capabilities) throws {
    let requestedConcurrency = config.concurrency.resolved

    // Check if requested concurrency exceeds platform maximum
    if requestedConcurrency > capabilities.maxConcurrentOperations {
        throw PrintingError.capabilityUnavailable(
            capability: "concurrency=\(requestedConcurrency)",
            platform: "iOS",
            reason: "Platform maximum is \(capabilities.maxConcurrentOperations). Requested \(requestedConcurrency) concurrent operations."
        )
    }
}

// MARK: - Internal Implementation

@MainActor
private func renderToDataWithFormatter(
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

@MainActor
extension PDF.Document {
    func renderInternal(config: PDF.Configuration) async throws -> URL {
        if config.createDirectories {
            try FileManager.default.createDirectory(
                at: self.destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        // Check if HTML contains images - use WebView if so
        if self.html.containsImages() {
            return try await renderWithWebView(config: config)
        } else {
            return try await renderWithPrintFormatter(config: config)
        }
    }

    @MainActor
    private func renderWithPrintFormatter(config: PDF.Configuration) async throws -> URL {
        let printFormatter = UIMarkupTextPrintFormatter(markupText: self.html)
        let data = try await renderToDataWithFormatter(printFormatter, config: config)
        try data.write(to: self.destination)
        return self.destination
    }

    @MainActor
    private func renderWithWebView(config: PDF.Configuration) async throws -> URL {
        @Dependency(\.webViewPool) var webViewPool

        let pool = try await webViewPool.pool

        // Track pool utilization
        await ActiveOperationsTracker.shared.increment()
        defer { Task { await ActiveOperationsTracker.shared.decrement() } }

        return try await pool.withResource(
            timeout: .seconds(config.webViewAcquisitionTimeout.components.seconds)
        ) { resource in
            let webView = resource.webView
            let renderer = DocumentWKRenderer(
                document: self,
                configuration: config
            )

            try await renderer.render(using: webView, documentTimeout: config.documentTimeout)
            return self.destination
        }
    }
}

private func renderDocumentsInternal(
    _ documents: some Sequence<PDF.Document>,
    config: PDF.Configuration
) async throws -> AsyncThrowingStream<PDF.Result, Error> {
    // Materialize sequence for indexing and count operations (before Task to avoid Sendable issues)
    let documentsArray = Array(documents)

    return AsyncThrowingStream<PDF.Result, Error> { continuation in
        Task { @MainActor in
            do {
                @Dependency(\.pdf.render.metrics) var metrics

                let maxConcurrent = config.concurrency ??
                    Swift.min(ProcessInfo.processInfo.activeProcessorCount, 4)

                var completedCount = 0

                try await withThrowingTaskGroup(of: (Int, URL, Int, [CGSize], PDF.PaginationMode, Duration).self) { taskGroup in
                    for (index, document) in documentsArray.prefix(maxConcurrent).enumerated() {
                        taskGroup.addTask {
                            let start = ContinuousClock.now
                            let url = try await document.renderInternal(config: config)
                            let duration = ContinuousClock.now - start
                            // iOS doesn't easily extract page info, default to 1 page with paper size
                            let pageCount = 1
                            let dimensions = [config.paperSize]
                            let mode = config.paginationMode
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

                        // Record metrics for successful PDF generation
                        metrics.recordSuccess(duration: duration, mode: mode)

                        continuation.yield(result)

                        if nextIndex < documentsArray.count {
                            let document = documentsArray[nextIndex]
                            let capturedIndex = nextIndex
                            nextIndex += 1

                            taskGroup.addTask {
                                let start = ContinuousClock.now
                                let url = try await document.renderInternal(config: config)
                                let duration = ContinuousClock.now - start
                                let pageCount = 1
                                let dimensions = [config.paperSize]
                                let mode = config.paginationMode
                                return (capturedIndex, url, pageCount, dimensions, mode, duration)
                            }
                        }
                    }
                }
                continuation.finish()
            } catch {
                @Dependency(\.logger) var logger
                @Dependency(\.pdf.render.metrics) var metrics

                // Record metrics for failed PDF generation
                let printingError = error as? PrintingError
                metrics.recordFailure(error: printingError)

                logger.error("Batch rendering failed", metadata: [
                    "completed_count": "\(completedCount)",
                    "total_count": "\(documentsArray.count)",
                    "error": "\(error)",
                    "error_type": "\(type(of: error))"
                ])
                continuation.finish(throwing: error)
            }
        }
    }
}

// MARK: - WebView Renderer for Images

@MainActor
private class DocumentWKRenderer: NSObject, WKNavigationDelegate {
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
            webView.loadHTMLString(self.document.html, baseURL: self.configuration.baseURL)

            if let timeout = documentTimeout {
                timeoutTask = Task { [weak self] in
                    do {
                        try await Task.sleep(for: timeout)

                        guard let self = self,
                              let continuation = self.continuation else { return }

                        self.continuation = nil
                        let timeoutError = PrintingError.webViewRenderingTimeout(
                            timeoutSeconds: Double(timeout.components.seconds)
                        )
                        continuation.resume(throwing: timeoutError)
                    } catch {
                        if !(error is CancellationError) {
                            @Dependency(\.logger) var logger
                            logger.error("Unexpected error in timeout task", metadata: [
                                "error": "\(error)",
                                "error_type": "\(type(of: error))"
                            ])
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
                let data = try await renderToDataWithFormatter(printFormatter, config: configuration)
                try data.write(to: document.destination)
                continuation.resume(returning: ())
            } catch {
                continuation.resume(throwing: error)
            }

            webView.navigationDelegate = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        Task {
            guard let continuation = self.continuation else { return }
            self.continuation = nil
            self.timeoutTask?.cancel()

            continuation.resume(throwing: PrintingError.webViewNavigationFailed(underlyingError: error))
            webView.navigationDelegate = nil
        }
    }
}

#endif
