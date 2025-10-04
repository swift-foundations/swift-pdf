//
//  PDF.Render.Metrics+TestSupport.swift
//  PDFTestSupport
//
//  Test implementation with in-memory storage
//

import Dependencies
import Foundation
@testable import HtmlToPdfTypes

/// Create test metrics with storage for assertions
public func makeTestMetrics() -> (metrics: PDF.Render.Metrics, storage: TestMetricsStorage) {
    let storage = TestMetricsStorage()

    let metrics = PDF.Render.Metrics(
        incrementPDFsGenerated: { storage.pdfsGenerated += 1 },
        incrementPDFsFailed: { storage.pdfsFailed += 1 },
        incrementPoolReplacements: { storage.poolReplacements += 1 },
        recordRenderDuration: { duration, mode in
            storage.renderDurations.append((duration, mode))
        },
        updatePoolUtilization: { count in storage.poolUtilization = count },
        updateThroughput: { throughput in storage.currentThroughput = throughput },
        recordPoolAcquisitionTime: { _ in },
        recordWebViewRenderTime: { _ in },
        recordCSSInjectionTime: { _ in },
        recordDataConversionTime: { _ in },
        getCurrentPDFCount: { Int(storage.pdfsGenerated) },
        getCurrentThroughput: { storage.currentThroughput },
        getCurrentPoolUtilization: { storage.poolUtilization },
        getP95RenderTime: {
            guard let p95 = storage.p95Duration else { return 0 }
            return Double(p95.components.seconds) + Double(p95.components.attoseconds) / 1_000_000_000_000_000_000
        }
    )

    return (metrics, storage)
}

/// In-memory storage for test metrics
public final class TestMetricsStorage: @unchecked Sendable {
    private let lock = NSLock()

    private var _pdfsGenerated: Int64 = 0
    private var _pdfsFailed: Int64 = 0
    private var _poolReplacements: Int64 = 0
    private var _renderDurations: [(Duration, PDF.PaginationMode?)] = []
    private var _poolUtilization: Int = 0
    private var _currentThroughput: Double = 0

    public init() {}

    public var pdfsGenerated: Int64 {
        get { lock.withLock { _pdfsGenerated } }
        set { lock.withLock { _pdfsGenerated = newValue } }
    }

    public var pdfsFailed: Int64 {
        get { lock.withLock { _pdfsFailed } }
        set { lock.withLock { _pdfsFailed = newValue } }
    }

    public var poolReplacements: Int64 {
        get { lock.withLock { _poolReplacements } }
        set { lock.withLock { _poolReplacements = newValue } }
    }

    public var renderDurations: [(Duration, PDF.PaginationMode?)] {
        get { lock.withLock { _renderDurations } }
        set { lock.withLock { _renderDurations = newValue } }
    }

    public var poolUtilization: Int {
        get { lock.withLock { _poolUtilization } }
        set { lock.withLock { _poolUtilization = newValue } }
    }

    public var currentThroughput: Double {
        get { lock.withLock { _currentThroughput } }
        set { lock.withLock { _currentThroughput = newValue } }
    }

    // Computed properties
    public var p95Duration: Duration? {
        let durations = renderDurations.map { $0.0 }.sorted()
        guard !durations.isEmpty else { return nil }
        let index = Int(Double(durations.count) * 0.95)
        return durations[min(index, durations.count - 1)]
    }

    public func reset() {
        lock.withLock {
            _pdfsGenerated = 0
            _pdfsFailed = 0
            _poolReplacements = 0
            _renderDurations = []
            _poolUtilization = 0
            _currentThroughput = 0
        }
    }
}
