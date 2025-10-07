//
//  PDF.Render.Metrics+TestSupport.swift
//  PDFTestSupport
//
//  Test implementation with in-memory storage
//

import Dependencies
import Foundation
@testable import HtmlToPdfTypes

// MARK: - Metrics Storage Dependency

extension DependencyValues {
    /// Test metrics storage for verifying recorded metrics
    ///
    /// Used with `PDF.Render.Metrics.recording` to capture metrics during tests.
    public var metricsStorage: TestMetricsStorage {
        get { self[MetricsStorageKey.self] }
        set { self[MetricsStorageKey.self] = newValue }
    }
}

private enum MetricsStorageKey: DependencyKey {
    static let liveValue = TestMetricsStorage()
    // Create new instance per test to ensure isolation
    static var testValue: TestMetricsStorage { TestMetricsStorage() }
}

// MARK: - Recording Metrics

extension PDF.Render.Metrics {
    /// Recording metrics client for testing
    ///
    /// Writes all metrics calls to the `\.metricsStorage` dependency, allowing
    /// tests to verify metrics behavior.
    ///
    /// ## Recommended Usage (Test-Level Isolation)
    ///
    /// Use `withDependencies` to ensure each test has isolated storage:
    ///
    /// ```swift
    /// @Test
    /// func myTest() async {
    ///     await withDependencies {
    ///         $0.pdf.render.metrics = .recording
    ///     } operation: {
    ///         @Dependency(\.pdf.render.metrics) var metrics
    ///         @Dependency(\.metricsStorage) var storage
    ///
    ///         metrics.recordSuccess(duration: .seconds(1))
    ///         #expect(storage.pdfsGenerated == 1)
    ///     }
    /// }
    /// ```
    ///
    /// ## Suite-Level Configuration
    ///
    /// For shared metrics across all tests in a suite:
    ///
    /// ```swift
    /// @Suite(.dependency(\.pdf.render.metrics, .recording))
    /// struct MyTests {
    ///     @Test
    ///     func myTest() async {
    ///         @Dependency(\.pdf.render.metrics) var metrics
    ///         @Dependency(\.metricsStorage) var storage
    ///
    ///         metrics.incrementPDFsGenerated()
    ///         #expect(storage.pdfsGenerated >= 1)  // May see other tests' metrics
    ///     }
    /// }
    /// ```
    ///
    /// **Note**: When using suite-level traits with concurrent tests, storage may
    /// be shared. Use `withDependencies` in each test for complete isolation.
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

/// Create test metrics with storage for assertions
///
/// **Deprecated**: Use `PDF.Render.Metrics.recording` with `\.metricsStorage` dependency instead.
///
/// ```swift
/// // Old:
/// let (metrics, storage) = makeTestMetrics()
///
/// // New:
/// @Dependency(\.metricsStorage) var storage
/// await withDependencies {
///     $0.pdf.render.metrics = .recording
/// } operation: {
///     // test code
/// }
/// ```
@available(*, deprecated, message: "Use PDF.Render.Metrics.recording with \\.metricsStorage dependency")
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
        recordDataConversionTime: { _ in }
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
