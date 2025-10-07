//
//  MetricsTests.swift
//  swift-html-to-pdf
//
//  Tests for metrics functionality
//

import Testing
import Foundation
import Dependencies
import PDFTestSupport
@testable import HtmlToPdfLive

@Suite("Metrics Tests", .dependency(\.pdf.render.metrics, .recording))
struct MetricsTests {

    @Test("Metrics are available via dependency")
    func metricsAvailableViaDependency() {
        @Dependency(\.pdf.render.metrics) var metrics
        @Dependency(\.metricsStorage) var storage

        // Verify metrics closures exist and can be called
        metrics.incrementPDFsGenerated()
        metrics.incrementPDFsFailed()
        metrics.incrementPoolReplacements()
        metrics.recordRenderDuration(.seconds(1), nil)
        metrics.updatePoolUtilization(10)
        metrics.updateThroughput(1000.0)
        metrics.recordPoolReplacement()

        // Verify storage captured the metrics
        #expect(storage.pdfsGenerated == 1)
        #expect(storage.pdfsFailed == 1)
        #expect(storage.poolReplacements == 2)
        #expect(storage.poolUtilization == 10)
        #expect(storage.currentThroughput == 1000.0)
    }

    @Test("Metrics record actual values")
    func metricsRecordActualValues() {
        @Dependency(\.pdf.render.metrics) var metrics
        @Dependency(\.metricsStorage) var storage

        // Record some metrics
        metrics.recordSuccess(duration: .milliseconds(50))
        metrics.recordSuccess(duration: .milliseconds(100))
        metrics.recordFailure()
        metrics.updatePoolUtilization(5)
        metrics.updateThroughput(1500.0)
        metrics.recordPoolReplacement()

        // Verify all values recorded
        #expect(storage.pdfsGenerated == 2)
        #expect(storage.pdfsFailed == 1)
        #expect(storage.poolReplacements == 1)
        #expect(storage.renderDurations.count == 2)
        #expect(storage.poolUtilization == 5)
        #expect(storage.currentThroughput == 1500.0)
    }

    @Test("Metrics p95 calculation")
    func metricsP95Calculation() {
        @Dependency(\.pdf.render.metrics) var metrics
        @Dependency(\.metricsStorage) var storage

        // Record a series of durations
        for ms in [10, 20, 30, 40, 50, 60, 70, 80, 90, 100] {
            metrics.recordSuccess(duration: .milliseconds(Int64(ms)))
        }

        #expect(storage.renderDurations.count == 10)
        #expect(storage.p95Duration != nil)
    }
}
