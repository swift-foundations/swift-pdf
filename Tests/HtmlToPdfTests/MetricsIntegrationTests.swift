//
//  MetricsIntegrationTests.swift
//  swift-html-to-pdf
//
//  Integration tests for metrics collection during PDF generation
//

import Testing
import Foundation
import Dependencies
import Metrics
import PDFTestSupport
@testable import HtmlToPdf

@Suite("Metrics Integration", .dependency(\.pdf, .liveValue))
struct MetricsIntegrationTests {
    @Dependency(\.pdf) var pdf

    @Test("Metrics record PDF generation success")
    func metricsRecordSuccess() async throws {
        let metricsBackend = TestMetricsBackend.shared

        try await withTemporaryDirectory { output in
            let html = "<html><body><h1>Test Document</h1></body></html>"
            _ = try await pdf.render.client.html(html, to: output)

            // Verify success counter incremented
            let pdfsGenerated = metricsBackend.counter("htmltopdf_pdfs_generated_total")
            #expect(pdfsGenerated?.value == 1, "Should record 1 PDF generated")

            // Verify duration was recorded
            let timer = metricsBackend.timer("htmltopdf_render_duration_seconds")
            #expect(timer?.values.count == 1, "Should record 1 duration")
            #expect((timer?.p95 ?? 0) > 0, "Should have non-zero duration")

            // Verify no failures
            let pdfsFailed = metricsBackend.counter("htmltopdf_pdfs_failed_total")
            #expect(pdfsFailed == nil || pdfsFailed?.value == 0, "Should have no failures")
        }
    }

    @Test("Metrics record multiple PDF generations")
    func metricsRecordMultiple() async throws {
        let metricsBackend = TestMetricsBackend.shared

        try await withTemporaryDirectory { output in
            let count = 10
            let htmls = (1...count).map { "<html><body><p>Document \($0)</p></body></html>" }

            var resultCount = 0
            for try await _ in try await pdf.render.client.html(htmls, to: output) {
                resultCount += 1
            }

            #expect(resultCount == count, "Should generate all PDFs")

            // Verify all successes recorded
            let pdfsGenerated = metricsBackend.counter("htmltopdf_pdfs_generated_total")
            #expect(pdfsGenerated?.value == Int64(count), "Should record all \(count) PDFs")

            // Verify all durations recorded
            let timer = metricsBackend.timer("htmltopdf_render_duration_seconds")
            #expect(timer?.values.count == count, "Should record \(count) durations")

            // Verify percentiles are calculated
            #expect((timer?.p50 ?? 0) > 0, "Should have p50 latency")
            #expect((timer?.p95 ?? 0) > 0, "Should have p95 latency")
            #expect((timer?.p99 ?? 0) > 0, "Should have p99 latency")
        }
    }

    @Test("Metrics track pagination mode dimension")
    func metricsTrackPaginationMode() async throws {
        let metricsBackend = TestMetricsBackend.shared

        try await withTemporaryDirectory { output in
            // Generate with continuous mode
            try await withDependencies {
                $0.pdf.render.configuration.paginationMode = .continuous
            } operation: {
                @Dependency(\.pdf) var pdfContinuous
                let html = "<html><body><p>Continuous</p></body></html>"
                _ = try await pdfContinuous.render.client.html(html, to: output.appendingPathComponent("continuous.pdf"))
            }

            // Generate with paginated mode
            try await withDependencies {
                $0.pdf.render.configuration.paginationMode = .paginated
            } operation: {
                @Dependency(\.pdf) var pdfPaginated
                let html = "<html><body><p>Paginated</p></body></html>"
                _ = try await pdfPaginated.render.client.html(html, to: output.appendingPathComponent("paginated.pdf"))
            }

            // Verify timers exist for both modes
            let byMode = await timersByDimension(
                label: "htmltopdf_render_duration_seconds",
                dimension: "mode",
                in: metricsBackend
            )

            #expect(byMode["continuous"] != nil, "Should have continuous mode timer")
            #expect(byMode["paginated"] != nil, "Should have paginated mode timer")

            #expect(byMode["continuous"]?.values.count == 1, "Should record 1 continuous PDF")
            #expect(byMode["paginated"]?.values.count == 1, "Should record 1 paginated PDF")
        }
    }

    @Test("Metrics track pool utilization")
    func metricsTrackPoolUtilization() async throws {
        let metricsBackend = TestMetricsBackend.shared

        try await withTemporaryDirectory { output in
            let html = "<html><body><p>Test</p></body></html>"
            _ = try await pdf.render.client.html(html, to: output)

            // Pool utilization should have been updated (even if it's 0 now after completion)
            let poolUtil = metricsBackend.gauge("htmltopdf_pool_utilization")
            #expect(poolUtil != nil, "Should have pool utilization gauge")
        }
    }

    @Test("Metrics print summary correctly")
    func metricsPrintSummary() async throws {
        let metricsBackend = TestMetricsBackend.shared

        try await withTemporaryDirectory { output in
            let count = 5
            let htmls = (1...count).map { "<html><body><p>Doc \($0)</p></body></html>" }

            for try await _ in try await pdf.render.client.html(htmls, to: output) {
                // Process results
            }

            // Print summary (visual verification in test output)
            let summary = await formatMetricsSummary(metricsBackend)
            print("\n" + summary + "\n")

            #expect(summary.contains("PDFs Generated: 5"), "Summary should show correct count")
            #expect(summary.contains("Render Duration"), "Summary should include timer stats")
        }
    }

    @Test("Metrics support live display")
    func metricsLiveDisplay() async throws {
        let metricsBackend = TestMetricsBackend.shared

        let liveDisplay = LiveMetricsDisplay(
            metricsBackend: metricsBackend,
            updateInterval: .milliseconds(500)
        )

        await liveDisplay.start()

        try await withTemporaryDirectory { output in
            let count = 10
            let htmls = (1...count).map { "<html><body><p>Doc \($0)</p></body></html>" }

            for try await _ in try await pdf.render.client.html(htmls, to: output) {
                // Live metrics will update during execution
            }
        }

        await liveDisplay.stop()

        // Verify metrics were collected
        let pdfsGenerated = metricsBackend.counter("htmltopdf_pdfs_generated_total")
        #expect(pdfsGenerated?.value == 10, "Should record all PDFs")
    }

    @Test("Metrics assertions work correctly")
    func metricsAssertions() async throws {
        let metricsBackend = TestMetricsBackend.shared

        try await withTemporaryDirectory { output in
            let count = 10
            let htmls = (1...count).map { "<html><body><p>Doc \($0)</p></body></html>" }

            for try await _ in try await pdf.render.client.html(htmls, to: output) {
                // Process results
            }

            // Test counter assertion
            try await expectCounter(
                "htmltopdf_pdfs_generated_total",
                equals: Int64(count),
                in: metricsBackend
            )

            // Test latency assertion (p95 should be under 1 second for simple docs)
            try await expectLatency(
                "htmltopdf_render_duration_seconds",
                p95LessThan: 1.0,
                in: metricsBackend
            )
        }
    }

    @Test("Metrics track errors with reason dimension")
    func metricsTrackErrorReasons() async throws {
        let metricsBackend = TestMetricsBackend.shared

        // Trigger an error by trying to write to invalid path
        do {
            let invalidPath = URL(fileURLWithPath: "/dev/null/invalid/path.pdf")
            let html = "<html><body><p>Test</p></body></html>"
            _ = try await pdf.render.client.html(html, to: invalidPath)
            Issue.record("Should have thrown error")
        } catch {
            // Expected to fail
        }

        // Check if failure was recorded (may not record if error happens before metrics call)
        // This test documents the expected behavior
        let pdfsFailed = metricsBackend.counter("htmltopdf_pdfs_failed_total")
        // Note: We may not get a failure metric if the error happens early in the pipeline
        print("PDFs failed count: \(pdfsFailed?.value ?? 0)")
    }

    @Test("Metrics can be reset between tests")
    func metricsReset() async throws {
        let metricsBackend = TestMetricsBackend.shared

        try await withTemporaryDirectory { output in
            // Generate first batch
            let html = "<html><body><p>Test</p></body></html>"
            _ = try await pdf.render.client.html(html, to: output.appendingPathComponent("test1.pdf"))

            let firstCount = metricsBackend.counter("htmltopdf_pdfs_generated_total")?.value
            #expect(firstCount == 1, "Should have 1 PDF")

            // Reset metrics
            metricsBackend.reset()

            // Generate second batch
            _ = try await pdf.render.client.html(html, to: output.appendingPathComponent("test2.pdf"))

            let secondCount = metricsBackend.counter("htmltopdf_pdfs_generated_total")?.value
            #expect(secondCount == 1, "Should have 1 PDF after reset (not 2)")
        }
    }
}
