//
//  PDF.Render.Metrics+TestSupport.swift
//  PDFTestSupport
//
//  Test implementation with in-memory storage for parallel test execution
//
//  ## Architecture
//
//  This module provides metrics testing infrastructure that works with Swift Testing's
//  parallel execution model. Unlike swift-metrics' TestMetricsBackend (which uses
//  global `MetricsSystem.bootstrap()` that can only be called once per process),
//  this uses the dependency system for per-test isolation.
//
//  ## Pattern
//
//  - **Write interface**: `PDF.Render.Metrics` (write-only, follows swift-metrics philosophy)
//  - **Read interface**: `\.metricsStorage` dependency (test observation point)
//  - **Isolation**: Each test gets its own storage via dependency system
//

import Dependencies
import Foundation
import HtmlToPdfTypes

// MARK: - Metrics Storage Dependency

extension DependencyValues {
    /// Test metrics storage for verifying recorded metrics
    ///
    /// This provides the read interface for metrics testing. Metrics are written
    /// via `PDF.Render.Metrics.recording` and read via this storage.
    ///
    /// Each test gets an isolated storage instance through `testValue`'s computed property.
    public var metricsStorage: TestMetricsStorage {
        get { self[MetricsStorageKey.self] }
        set { self[MetricsStorageKey.self] = newValue }
    }
}

private enum MetricsStorageKey: DependencyKey {
    static let liveValue = TestMetricsStorage()
    // Create new instance per test to ensure isolation in parallel execution
    static var testValue: TestMetricsStorage { TestMetricsStorage() }
}

// MARK: - Recording Metrics Client

extension PDF.Render.Metrics {
    /// Recording metrics client for testing with parallel execution support
    ///
    /// This Spy intercepts metrics calls and stores them in `\.metricsStorage` for verification.
    /// Unlike `TestMetricsBackend` (which requires global `MetricsSystem.bootstrap()`), this
    /// uses the dependency system for proper test isolation in parallel execution.
    ///
    /// ## Why Not TestMetricsBackend?
    ///
    /// swift-metrics' `TestMetricsBackend` requires calling `MetricsSystem.bootstrap()` once
    /// per process. With Swift Testing's parallel execution, this creates race conditions and
    /// bootstrap errors. Our dependency-based approach gives each test isolated storage.
    ///
    /// ## Recommended Usage (Per-Test Isolation)
    ///
    /// Use `withDependencies` to ensure each test has isolated storage:
    ///
    /// ```swift
    /// @Test
    /// func myTest() async {
    ///     await withDependencies {
    ///         $0.pdf.render.metrics = .recording
    ///     } operation: {
    ///         @Dependency(\.pdf.render.metrics) var metrics  // Write interface
    ///         @Dependency(\.metricsStorage) var storage      // Read interface
    ///
    ///         metrics.recordSuccess(duration: .seconds(1))
    ///         #expect(storage.pdfsGenerated == 1)
    ///     }
    /// }
    /// ```
    ///
    /// ## Architecture: CQRS Separation
    ///
    /// - **Command (Write)**: `\.pdf.render.metrics` - What your code uses to emit metrics
    /// - **Query (Read)**: `\.metricsStorage` - What your test uses to verify metrics
    ///
    /// This separation follows CQRS and swift-metrics philosophy (metrics are write-only,
    /// querying happens in separate infrastructure).
    public static var recording: Self {
        Self(
            incrementPDFsGenerated: {
                @Dependency(\.metricsStorage) var storage
                storage.pdfsGenerated += 1
            },
            incrementPDFsFailed: {
                @Dependency(\.metricsStorage) var storage
                storage.pdfsFailed += 1
            },
            incrementPoolReplacements: {
                @Dependency(\.metricsStorage) var storage
                storage.poolReplacements += 1
            },
            recordRenderDuration: { duration, mode in
                @Dependency(\.metricsStorage) var storage
                storage.renderDurations.append((duration, mode))
            },
            updatePoolUtilization: { count in
                @Dependency(\.metricsStorage) var storage
                storage.poolUtilization = count
            },
            updateThroughput: { throughput in
                @Dependency(\.metricsStorage) var storage
                storage.currentThroughput = throughput
            },
            recordPoolAcquisitionTime: { _ in },
            recordWebViewRenderTime: { _ in },
            recordCSSInjectionTime: { _ in },
            recordDataConversionTime: { _ in }
        )
    }
}

// MARK: - Test Storage

/// In-memory storage for test metrics
///
/// Access via `\.metricsStorage` dependency when using `PDF.Render.Metrics.recording`.
/// Each test gets an isolated storage instance through the dependency system.
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
