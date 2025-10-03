//
//  MetricsTests.swift
//  swift-html-to-pdf
//
//  Tests for metrics functionality
//

import Testing
import Foundation
import Dependencies
import Metrics
import PDFTestSupport
@testable import HtmlToPdf

@Suite("Metrics Tests")
struct MetricsTests {

    @Test("Metrics are available via dependency")
    func metricsAvailableViaDependency() {
        @Dependency(\.pdf.render.metrics) var metrics

        // Verify metrics exist and have correct labels
        #expect(metrics.pdfsGenerated.label == "htmltopdf_pdfs_generated_total")
        #expect(metrics.pdfsFailed.label == "htmltopdf_pdfs_failed_total")
        #expect(metrics.renderDuration.label == "htmltopdf_render_duration_seconds")
        #expect(metrics.poolReplacements.label == "htmltopdf_pool_replacements_total")
        #expect(metrics.poolUtilization.label == "htmltopdf_pool_utilization")
        #expect(metrics.currentThroughput.label == "htmltopdf_throughput_pdfs_per_sec")
    }

    @Test("Metrics convenience methods work without crashing")
    func metricsConvenienceMethods() {
        @Dependency(\.pdf.render.metrics) var metrics

        // Test convenience methods don't crash
        // Without a metrics backend bootstrapped, metrics are no-ops
        // This verifies the API works
        metrics.recordSuccess(duration: .seconds(1))
        metrics.recordFailure()
        metrics.updatePoolUtilization(10)
        metrics.updateThroughput(1000.0)
        metrics.recordPoolReplacement()

        // If we got here without crashing, the test passes
        #expect(Bool(true))
    }

    @Test("Duration conversion works correctly")
    func durationConversion() {
        @Dependency(\.pdf.render.metrics) var metrics

        // Test various duration values
        let durations: [Duration] = [
            .milliseconds(1),
            .milliseconds(100),
            .seconds(1),
            .seconds(5),
        ]

        for duration in durations {
            // Should not crash
            metrics.recordSuccess(duration: duration)
        }

        #expect(Bool(true))
    }

    @Test("Metrics are accessible from PDF render")
    func metricsAccessibleFromRender() {
        @Dependency(\.pdf) var pdf

        // Verify metrics are accessible via render
        let metrics = pdf.render.metrics

        #expect(metrics.pdfsGenerated.label == "htmltopdf_pdfs_generated_total")
    }

    @Test("Test dependency provides metrics")
    func testDependencyProvidesMetrics() {
        @Dependency(\.pdf) var pdf

        // Test value should provide valid metrics
        #expect(pdf.render.metrics.pdfsGenerated.label == "htmltopdf_pdfs_generated_total")
    }

    @Test("Metrics record actual values when backend is bootstrapped")
    func metricsRecordActualValues() async {
        let metricsBackend = TestMetricsBackend.forTest()

        @Dependency(\.pdf.render.metrics) var metrics

        // Record some metrics
        metrics.recordSuccess(duration: .milliseconds(50))
        metrics.recordSuccess(duration: .milliseconds(100))
        metrics.recordFailure()
        metrics.updatePoolUtilization(5)
        metrics.updateThroughput(1500.0)
        metrics.recordPoolReplacement()

        // Verify values were recorded
        let pdfsGenerated = metricsBackend.counter("htmltopdf_pdfs_generated_total")
        #expect(pdfsGenerated?.value == 2, "Should record 2 successful PDFs")

        let pdfsFailed = metricsBackend.counter("htmltopdf_pdfs_failed_total")
        #expect(pdfsFailed?.value == 1, "Should record 1 failed PDF")

        let timer = metricsBackend.timer("htmltopdf_render_duration_seconds")
        #expect(timer?.values.count == 2, "Should record 2 durations")

        let poolUtil = metricsBackend.gauge("htmltopdf_pool_utilization")
        #expect(poolUtil?.value == 5.0, "Should record pool utilization")

        let throughput = metricsBackend.gauge("htmltopdf_throughput_pdfs_per_sec")
        #expect(throughput?.value == 1500.0, "Should record throughput")

        let poolReplacements = metricsBackend.counter("htmltopdf_pool_replacements_total")
        #expect(poolReplacements?.value == 1, "Should record pool replacement")
    }

    @Test("Metrics record success with pagination mode dimension")
    func metricsRecordWithModeDimension() async {
        let metricsBackend = TestMetricsBackend.forTest()

        @Dependency(\.pdf.render.metrics) var metrics

        // Record with different pagination modes
        metrics.recordSuccess(duration: .milliseconds(50), mode: .continuous)
        metrics.recordSuccess(duration: .milliseconds(100), mode: .paginated)
        metrics.recordSuccess(duration: .milliseconds(75), mode: .continuous)

        // Verify dimension tracking
        let byMode = await timersByDimension(
            label: "htmltopdf_render_duration_seconds",
            dimension: "mode",
            in: metricsBackend
        )

        #expect(byMode["continuous"]?.values.count == 2, "Should have 2 continuous mode timings")
        #expect(byMode["paginated"]?.values.count == 1, "Should have 1 paginated mode timing")
    }

    @Test("Metrics record failure with error reason dimension")
    func metricsRecordWithErrorDimension() async {
        let metricsBackend = TestMetricsBackend.forTest()

        @Dependency(\.pdf.render.metrics) var metrics

        // Record failures with different error reasons
        let error1 = PrintingError.invalidHTML("test")
        let error2 = PrintingError.webViewRenderingTimeout(timeoutSeconds: 30)

        metrics.recordFailure(error: error1)
        metrics.recordFailure(error: error2)
        metrics.recordFailure(error: error1)

        // Verify dimension tracking
        let byReason = await countersByDimension(
            label: "htmltopdf_pdfs_failed_total",
            dimension: "reason",
            in: metricsBackend
        )

        #expect(byReason["invalid_html"]?.value == 2, "Should have 2 invalid_html failures")
        #expect(byReason["webview_rendering_timeout"]?.value == 1, "Should have 1 timeout failure")
    }

    @Test("Metrics follow naming conventions")
    func metricsFollowNamingConventions() {
        @Dependency(\.pdf.render.metrics) var metrics

        // All metrics should use snake_case
        let labels = [
            metrics.pdfsGenerated.label,
            metrics.pdfsFailed.label,
            metrics.renderDuration.label,
            metrics.poolReplacements.label,
            metrics.poolUtilization.label,
            metrics.currentThroughput.label
        ]

        for label in labels {
            #expect(label.contains("_"), "Metric label '\(label)' should use snake_case")
            #expect(!label.contains("-"), "Metric label '\(label)' should not use dashes")
            #expect(label == label.lowercased(), "Metric label '\(label)' should be lowercase")
        }

        // Counters should end with _total
        #expect(metrics.pdfsGenerated.label.hasSuffix("_total"), "Counter should end with _total")
        #expect(metrics.pdfsFailed.label.hasSuffix("_total"), "Counter should end with _total")
        #expect(metrics.poolReplacements.label.hasSuffix("_total"), "Counter should end with _total")

        // Timers should end with time unit
        #expect(metrics.renderDuration.label.hasSuffix("_seconds"), "Timer should end with time unit")

        // All metrics should have common prefix
        for label in labels {
            #expect(label.hasPrefix("htmltopdf_"), "All metrics should have 'htmltopdf_' prefix")
        }
    }

    @Test("Test metrics backend percentile calculation")
    func testMetricsBackendPercentiles() async {
        let metricsBackend = TestMetricsBackend.forTest()

        @Dependency(\.pdf.render.metrics) var metrics

        // Record a series of durations (in milliseconds for easier calculation)
        let durations: [Int64] = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
        for ms in durations {
            metrics.recordSuccess(duration: .milliseconds(ms))
        }

        let timer = metricsBackend.timer("htmltopdf_render_duration_seconds")
        #expect(timer?.values.count == 10, "Should have 10 recorded durations")

        // Verify percentiles are reasonable
        let p50 = timer?.p50 ?? 0
        let p95 = timer?.p95 ?? 0
        let p99 = timer?.p99 ?? 0

        #expect(p50 > 0, "p50 should be > 0")
        #expect(p95 >= p50, "p95 should be >= p50")
        #expect(p99 >= p95, "p99 should be >= p95")

        // p50 should be around 50-60ms (0.050-0.060s)
        #expect(p50 >= 0.040 && p50 <= 0.070, "p50 should be around median value")
    }
}
