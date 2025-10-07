//
//  MetricsIntegrationTests.swift
//  swift-html-to-pdf
//
//  Integration tests for metrics collection during PDF generation
//

import Testing
import Foundation
import Dependencies
import PDFTestSupport
@testable import HtmlToPdfLive

@Suite("Metrics Integration", .dependency(\.pdf.render.metrics, .recording))
struct MetricsIntegrationTests {

    @Test("Metrics record counter increments")
    func metricsRecordIncrements() {
        @Dependency(\.pdf.render.metrics) var metrics
        @Dependency(\.metricsStorage) var storage

        // Verify metrics use the test storage
        metrics.incrementPDFsGenerated()

        #expect(storage.pdfsGenerated == 1, "Storage should capture increment")
    }

    @Test("Metrics record PDF generation success")
    func metricsRecordSuccess() async throws {
        @Dependency(\.pdf) var pdf
        @Dependency(\.metricsStorage) var storage

        try await withTemporaryDirectory { output in
            let html = "<html><body><h1>Test Document</h1></body></html>"
            _ = try await pdf.render.client.html(html, to: output.appendingPathComponent("test.pdf"))

            // Assert on storage directly
            #expect(storage.pdfsGenerated == 1)
            #expect(storage.renderDurations.count == 1)
            #expect(storage.pdfsFailed == 0)
        }
    }

    @Test("Metrics record multiple PDF generations")
    func metricsRecordMultiple() async throws {
        @Dependency(\.pdf) var pdf
        @Dependency(\.metricsStorage) var storage

        try await withTemporaryDirectory { output in
            let count = 10
            let html = (1...count).map { "<html><body><p>Document \($0)</p></body></html>" }

            var resultCount = 0
            for try await _ in try await pdf.render.client.html(html, to: output) {
                resultCount += 1
            }

            #expect(resultCount == count)
            #expect(storage.pdfsGenerated == Int64(count))
            #expect(storage.renderDurations.count == count)

            // Verify p95 calculation
            #expect(storage.p95Duration != nil)
        }
    }

    @Test("Metrics track pagination mode dimension")
    func metricsTrackPaginationMode() async throws {
        @Dependency(\.metricsStorage) var storage

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

            // Verify both modes were recorded
            let continuousDurations = storage.renderDurations.filter { $0.1 == .continuous }
            let paginatedDurations = storage.renderDurations.filter { $0.1 == .paginated }

            #expect(continuousDurations.count == 1)
            #expect(paginatedDurations.count == 1)
        }
    }

    @Test("Metrics track pool utilization")
    func metricsTrackPoolUtilization() async throws {
        @Dependency(\.pdf) var pdf
        @Dependency(\.metricsStorage) var storage

        try await withTemporaryDirectory { output in
            let html = "<html><body><p>Test</p></body></html>"
            _ = try await pdf.render.client.html(html, to: output.appendingPathComponent("test.pdf"))

            // Pool utilization should have been updated
            #expect(storage.poolUtilization >= 0)
        }
    }

    @Test("Metrics can be reset between operations")
    func metricsReset() async throws {
        @Dependency(\.pdf) var pdf
        @Dependency(\.metricsStorage) var storage

        try await withTemporaryDirectory { output in
            // Generate first batch
            let html = "<html><body><p>Test</p></body></html>"
            _ = try await pdf.render.client.html(html, to: output.appendingPathComponent("test1.pdf"))

            let firstCount = storage.pdfsGenerated
            #expect(firstCount == 1)

            // Reset metrics
            storage.reset()

            // Generate second batch
            _ = try await pdf.render.client.html(html, to: output.appendingPathComponent("test2.pdf"))

            let secondCount = storage.pdfsGenerated
            #expect(secondCount == 1, "Should have 1 PDF after reset (not 2)")
        }
    }
}
