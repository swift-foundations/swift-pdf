//
//  Utils.swift
//  HtmlToPdfTests
//
//  Test utilities and fixtures for HtmlToPdf tests
//
//  Note: General-purpose test utilities have been moved to PDFTestSupport/TestUtilities.swift
//  This file contains HtmlToPdf-specific helpers (HTML fixtures, progress tracking, etc.)
//

import Foundation
import HtmlToPdfLive
import Testing
import PDFTestSupport
import Metrics

// MARK: - Test Errors

enum TestError: Error {
    case failedToCreateLogFile
    case pdfNotFound(URL)
}

extension String {
    static let html = """
    <html>
        <body>
            <h1>Hello, World! Hello, World! Hello, World! Hello, World! Hello, World! Hello, World! Hello, World! Hello, World!</h1>
        </body>
    </html>
    """

    static let html2 = """
    <html>
        <body>
            <h1>Hello, World!</h1>
            <h2>Hello, World! subheader</h2>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
        </body>
    </html>
    """

}

// MARK: - Test Progress Tracking

/// Legacy progress tracker - DEPRECATED: Use MetricsProgressTracker instead
///
/// This tracker manually calculates metrics instead of using the metrics system.
/// Prefer MetricsProgressTracker which reads from the actual metrics being recorded.
@available(*, deprecated, message: "Use MetricsProgressTracker instead")
actor ProgressTracker {
    var completed = 0
    var lastReportedAt = Date()
    var lastReportedCompleted = 0
    let reportInterval: TimeInterval
    let totalCount: Int
    private let metricsBackend: TestMetricsBackend?
    private let logHandler: (@Sendable (String, Logger.Metadata) -> Void)?

    init(
        totalCount: Int,
        reportInterval: TimeInterval = 5.0,
        metricsBackend: TestMetricsBackend? = nil,
        logHandler: (@Sendable (String, Logger.Metadata) -> Void)? = nil
    ) {
        self.totalCount = totalCount
        self.reportInterval = reportInterval
        self.metricsBackend = metricsBackend
        self.logHandler = logHandler
    }

    func recordCompletion() async -> Int {
        completed += 1

        // If metrics backend provided, use it for tracking
        if let metricsBackend = metricsBackend {
            let counter = metricsBackend.counter("htmltopdf_pdfs_generated_total")
            let throughput = metricsBackend.gauge("htmltopdf_throughput_pdfs_per_sec")?.value ?? 0

            let now = Date()
            if now.timeIntervalSince(lastReportedAt) >= reportInterval {
                let progress = Double(completed) / Double(totalCount) * 100
                let metadata: Logger.Metadata = [
                    "completed": "\(completed)",
                    "total": "\(totalCount)",
                    "progress_pct": "\(String(format: "%.1f", progress))",
                    "throughput": "\(String(format: "%.0f", throughput))",  // PDFs per second
                    "counter_total": "\(counter?.value ?? 0)"
                ]
                if let logHandler = logHandler {
                    logHandler("PDF generation progress", metadata)
                } else {
                    print("Progress: \(completed)/\(totalCount) (\(String(format: "%.1f", progress))%) - Throughput: \(String(format: "%.0f", throughput)) PDFs/sec - Total: \(counter?.value ?? 0)")
                }
                lastReportedAt = now
                lastReportedCompleted = completed
            }
        } else {
            // Fallback to manual calculation
            let now = Date()
            if now.timeIntervalSince(lastReportedAt) >= reportInterval {
                let interval = now.timeIntervalSince(lastReportedAt)
                let delta = completed - lastReportedCompleted
                let rate = Double(delta) / interval
                let metadata: Logger.Metadata = [
                    "completed": "\(completed)",
                    "total": "\(totalCount)",
                    "throughput": "\(String(format: "%.0f", rate))"  // PDFs per second
                ]
                if let logHandler = logHandler {
                    logHandler("PDF generation progress", metadata)
                } else {
                    print("Progress: \(completed)/\(totalCount) PDFs (\(String(format: "%.1f", Double(completed)/1000.0))k) - Rate: \(String(format: "%.0f", rate)) PDFs/sec")
                }
                lastReportedAt = now
                lastReportedCompleted = completed
            }
        }

        return completed
    }
}

/// Metrics-based progress tracker - recommended for new tests
///
/// Automatically retrieves the TestMetricsBackend from MetricsSystem.
///
/// Example:
/// ```swift
/// // In .dependencies block:
/// let backend = TestMetricsBackend()
/// MetricsSystem.bootstrapInternal(backend)
///
/// // In test:
/// let tracker = MetricsProgressTracker(
///     totalCount: 10_000,
///     logHandler: { message, metadata in logger.info(message, metadata: metadata) }
/// )
/// await tracker.start()
///
/// // Your test code...
/// for try await result in stream {
///     // Metrics are automatically recorded by the library
/// }
///
/// await tracker.stop()
/// await tracker.printSummary()
/// ```
public actor MetricsProgressTracker {
    private let totalCount: Int
    private let reportInterval: Duration
    private var displayTask: Task<Void, Never>?
    private let startTime: Date
    private let logHandler: (@Sendable (String, Logger.Metadata) -> Void)?

    public init(
        totalCount: Int,
        reportInterval: Duration = .seconds(5),
        logHandler: (@Sendable (String, Logger.Metadata) -> Void)? = nil
    ) {
        self.totalCount = totalCount
        self.reportInterval = reportInterval
        self.startTime = Date()
        self.logHandler = logHandler
    }

    public func start() {
        displayTask = Task {
            while !Task.isCancelled {
                await printProgress()
                try? await Task.sleep(for: reportInterval)
            }
        }
    }

    public func stop() {
        displayTask?.cancel()
        displayTask = nil
    }

    private func printProgress() async {
        // Query metrics directly from TestMetricsBackend via MetricsSystem
        guard let backend = MetricsSystem.factory as? TestMetricsBackend else {
            if let logHandler = logHandler {
                logHandler("Metrics not available - TestMetricsBackend not bootstrapped", [:])
            }
            return
        }

        let pdfsGenerated = Int(backend.counter("htmltopdf_pdfs_generated_total")?.value ?? 0)
        let poolUtil = Int(backend.gauge("htmltopdf_pool_utilization")?.value ?? 0)

        // Get ALL timers with this label (across all dimensions/modes) and combine their values
        let allTimers = backend.timers(withLabel: "htmltopdf_render_duration_seconds")
        let allDurations = allTimers.flatMap { $0.values }
        let p95 = allDurations.isEmpty ? 0 : {
            let sorted = allDurations.sorted()
            let index = Int(Double(sorted.count) * 0.95)
            let clampedIndex = min(index, sorted.count - 1)
            return TimeInterval(sorted[clampedIndex]) / 1_000_000  // Convert nanoseconds to milliseconds
        }()

        // Calculate throughput based on elapsed time and PDFs generated
        let elapsed = Date().timeIntervalSince(startTime)
        let throughput = elapsed > 0 ? Double(pdfsGenerated) / elapsed : 0

        let progress = Double(pdfsGenerated) / Double(totalCount) * 100
        let eta = pdfsGenerated > 0 ? (elapsed / Double(pdfsGenerated)) * Double(totalCount - pdfsGenerated) : 0

        let metadata: Logger.Metadata = [
            "completed": "\(pdfsGenerated)",
            "total": "\(totalCount)",
            "progress_pct": "\(String(format: "%.1f", progress))",
            "throughput": "\(String(format: "%.0f", throughput))",
            "pool_utilization": "\(poolUtil)",
            "p95_ms": "\(String(format: "%.1f", p95))",
            "eta_seconds": "\(String(format: "%.0f", eta))"
        ]

        if let logHandler = logHandler {
            logHandler("PDF generation progress", metadata)
        } else {
            print("Progress: \(pdfsGenerated)/\(totalCount) (\(String(format: "%.1f", progress))%) | " +
                  "Throughput: \(String(format: "%.0f", throughput))/sec | " +
                  "Pool: \(poolUtil) | " +
                  "p95: \(String(format: "%.1f", p95))ms | " +
                  "ETA: \(String(format: "%.0f", eta))s")
        }
    }

    public func printSummary() async {
        await printProgress()
        // Get backend for detailed summary formatting
        if let backend = MetricsSystem.factory as? TestMetricsBackend {
            let summary = await formatMetricsSummary(backend)
            if let logHandler = logHandler {
                logHandler("Test summary", ["summary": "\(summary)"])
            } else {
                print("\n" + summary)
            }
        }
    }
}

