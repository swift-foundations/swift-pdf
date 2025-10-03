//
//  PDF.Render.Metrics.swift
//  swift-html-to-pdf
//
//  Metrics for PDF rendering operations
//

import Metrics
import Dependencies
import Foundation

extension PDF.Render {
    /// Metrics for rendering operations
    ///
    /// Provides production observability for PDF rendering through standardized metrics.
    /// Requires `MetricsSystem.bootstrap()` at application startup to export metrics
    /// to backends like Prometheus, StatsD, or OpenTelemetry.
    ///
    /// ## Available Metrics
    ///
    /// **Counters:**
    /// - `htmltopdf_pdfs_generated_total`: Total PDFs successfully generated
    /// - `htmltopdf_pdfs_failed_total`: Total PDF generation failures
    /// - `htmltopdf_pool_replacements_total`: Total resource pool replacements
    ///
    /// **Timers:**
    /// - `htmltopdf_render_duration_seconds`: PDF render duration (automatically provides p50/p95/p99)
    ///
    /// **Gauges:**
    /// - `htmltopdf_pool_utilization`: Current number of active WebViews in pool
    /// - `htmltopdf_throughput_pdfs_per_sec`: Current throughput in PDFs per second
    ///
    /// ## Usage
    ///
    /// Metrics are automatically collected during rendering operations:
    ///
    /// ```swift
    /// import Metrics
    ///
    /// // Bootstrap once at application startup
    /// MetricsSystem.bootstrap(PrometheusMetricsFactory())
    ///
    /// // Use library normally - metrics auto-collected
    /// @Dependency(\.pdf) var pdf
    /// try await pdf.render(htmls: invoices, to: directory)
    /// ```
    ///
    /// ## Direct Access
    ///
    /// You can access metrics directly if needed:
    ///
    /// ```swift
    /// @Dependency(\.pdf.render.metrics) var metrics
    /// print("PDFs generated metric: \(metrics.pdfsGenerated.label)")
    /// ```
    ///
    /// ## Prometheus Example
    ///
    /// ```swift
    /// // In your Vapor/Hummingbird application
    /// app.get("metrics") { req in
    ///     try MetricsSystem.prometheus().collect()
    /// }
    /// ```
    ///
    /// Then query in Prometheus:
    ///
    /// ```promql
    /// # Throughput
    /// rate(htmltopdf_pdfs_generated_total[5m])
    ///
    /// # P95 Latency
    /// histogram_quantile(0.95, rate(htmltopdf_render_duration_seconds_bucket[5m]))
    ///
    /// # Error Rate
    /// rate(htmltopdf_pdfs_failed_total[5m]) / rate(htmltopdf_pdfs_generated_total[5m])
    /// ```
    public struct Metrics: Sendable {

        // MARK: - Counters

        /// Total PDFs successfully generated
        ///
        /// Incremented each time a PDF is successfully rendered.
        /// Use for tracking overall throughput and success rate.
        public let pdfsGenerated: Counter

        /// Total PDF generation failures
        ///
        /// Incremented each time PDF rendering fails.
        /// Use for tracking error rates and alerting.
        public let pdfsFailed: Counter

        /// Total resource pool replacements
        ///
        /// Incremented each time the WebView resource pool is replaced.
        /// Use for tracking adaptive optimization behavior.
        public let poolReplacements: Counter

        // MARK: - Timers

        /// PDF render duration distribution
        ///
        /// Records the duration of each PDF render operation.
        /// Automatically provides p50/p95/p99 latency percentiles.
        public let renderDuration: Timer

        // MARK: - Gauges

        /// Current number of active WebViews in the resource pool
        ///
        /// Tracks the number of WebViews currently being used for rendering operations.
        /// Automatically updated when WebViews are acquired from and released to the pool.
        ///
        /// Use for tracking pool utilization and capacity planning.
        public let poolUtilization: Gauge

        /// Current throughput in PDFs per second
        ///
        /// Updated by the adaptive throughput optimizer.
        /// Use for real-time performance monitoring.
        public let currentThroughput: Gauge

        // MARK: - Initialization

        public init() {
            self.pdfsGenerated = Counter(label: "htmltopdf_pdfs_generated_total")
            self.pdfsFailed = Counter(label: "htmltopdf_pdfs_failed_total")
            self.poolReplacements = Counter(label: "htmltopdf_pool_replacements_total")
            self.renderDuration = Timer(label: "htmltopdf_render_duration_seconds")
            self.poolUtilization = Gauge(label: "htmltopdf_pool_utilization")
            self.currentThroughput = Gauge(label: "htmltopdf_throughput_pdfs_per_sec")
        }

        // MARK: - Convenience Methods

        /// Record a successful PDF generation
        ///
        /// Increments the `pdfsGenerated` counter and records the render duration.
        /// Optionally includes pagination mode as a dimension for segmented analysis.
        ///
        /// - Parameters:
        ///   - duration: Time taken to render the PDF
        ///   - mode: Optional pagination mode for dimensional tracking
        public func recordSuccess(duration: Duration, mode: PDF.PaginationMode? = nil) {
            pdfsGenerated.increment()

            // Convert Duration to nanoseconds for Timer
            let nanoseconds = duration.components.seconds * 1_000_000_000 +
                            duration.components.attoseconds / 1_000_000_000

            // Use dimensions if mode is provided for segmented metrics
            if let mode = mode {
                Timer(
                    label: "htmltopdf_render_duration_seconds",
                    dimensions: [("mode", mode.metricsLabel)]
                ).recordNanoseconds(nanoseconds)
            } else {
                renderDuration.recordNanoseconds(nanoseconds)
            }
        }

        /// Record a failed PDF generation
        ///
        /// Increments the `pdfsFailed` counter.
        /// Optionally includes error reason as a dimension for segmented analysis.
        ///
        /// - Parameter error: Optional error for dimensional tracking
        public func recordFailure(error: PrintingError? = nil) {
            if let error = error {
                Counter(
                    label: "htmltopdf_pdfs_failed_total",
                    dimensions: [("reason", error.metricsReason)]
                ).increment()
            } else {
                pdfsFailed.increment()
            }
        }

        /// Update the pool utilization gauge
        ///
        /// Called automatically when WebViews are acquired from or released to the pool.
        /// You can also call this manually if implementing custom pooling logic.
        ///
        /// - Parameter count: Current number of active WebViews
        public func updatePoolUtilization(_ count: Int) {
            poolUtilization.record(count)
        }

        /// Update the throughput gauge
        ///
        /// - Parameter pdfsPerSecond: Current rendering throughput
        public func updateThroughput(_ pdfsPerSecond: Double) {
            currentThroughput.record(pdfsPerSecond)
        }

        /// Record a pool replacement event
        ///
        /// Increments the `poolReplacements` counter.
        /// Called when the adaptive optimizer triggers a pool refresh.
        public func recordPoolReplacement() {
            poolReplacements.increment()
        }
    }
}

// MARK: - Dependency Registration

extension PDF.Render.Metrics: DependencyKey {
    public static let liveValue = PDF.Render.Metrics()
    public static let testValue = PDF.Render.Metrics()
}

// Note: Metrics are accessed via `pdf.render.metrics`, not as a standalone dependency.
// The dependency key registration is used internally by the PDF.Render type.
