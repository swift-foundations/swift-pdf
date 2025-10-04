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

/// Legacy progress tracker - prefer using TestMetricsBackend + LiveMetricsDisplay for new tests
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
/// Example:
/// ```swift
/// let metricsBackend = TestMetricsBackend()
/// MetricsSystem.bootstrap(metricsBackend)
///
/// let tracker = MetricsProgressTracker(
///     totalCount: 10_000,
///     metricsBackend: metricsBackend
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
    private let metricsBackend: TestMetricsBackend
    private let reportInterval: Duration
    private var displayTask: Task<Void, Never>?
    private let startTime: Date

    public init(
        totalCount: Int,
        metricsBackend: TestMetricsBackend,
        reportInterval: Duration = .seconds(5)
    ) {
        self.totalCount = totalCount
        self.metricsBackend = metricsBackend
        self.reportInterval = reportInterval
        self.startTime = Date()
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
        let pdfsGenerated = metricsBackend.counter("htmltopdf_pdfs_generated_total")?.value ?? 0
        let throughput = metricsBackend.gauge("htmltopdf_throughput_pdfs_per_sec")?.value ?? 0
        let poolUtil = metricsBackend.gauge("htmltopdf_pool_utilization")?.value ?? 0
        let timer = metricsBackend.timer("htmltopdf_render_duration_seconds")
        let p95 = (timer?.p95 ?? 0) * 1000

        let progress = Double(pdfsGenerated) / Double(totalCount) * 100
        let elapsed = Date().timeIntervalSince(startTime)
        let eta = Int64(pdfsGenerated) > 0 ? (elapsed / Double(pdfsGenerated)) * Double(totalCount - Int(pdfsGenerated)) : 0

        print("Progress: \(pdfsGenerated)/\(totalCount) (\(String(format: "%.1f", progress))%) | " +
              "Throughput: \(String(format: "%.0f", throughput))/sec | " +
              "Pool: \(Int(poolUtil)) | " +
              "p95: \(String(format: "%.1f", p95))ms | " +
              "ETA: \(String(format: "%.0f", eta))s")
    }

    public func printSummary() async {
        await printProgress()
        let summary = await formatMetricsSummary(metricsBackend)
        print("\n" + summary)
    }
}

