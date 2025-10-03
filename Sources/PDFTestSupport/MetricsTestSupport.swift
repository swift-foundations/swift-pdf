//
//  MetricsTestSupport.swift
//  PDFTestSupport
//
//  Utilities for testing with metrics
//

import Foundation
import Metrics

// MARK: - Live Metrics Display

/// Display live metrics during long-running tests
///
/// Example:
/// ```swift
/// let display = LiveMetricsDisplay(metricsBackend: backend)
/// await display.start()
/// // ... run your test ...
/// await display.stop()
/// ```
public actor LiveMetricsDisplay {
    private let metricsBackend: TestMetricsBackend
    private let updateInterval: Duration
    private var displayTask: Task<Void, Never>?
    private var isRunning = false

    public init(
        metricsBackend: TestMetricsBackend,
        updateInterval: Duration = .seconds(2)
    ) {
        self.metricsBackend = metricsBackend
        self.updateInterval = updateInterval
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        displayTask = Task {
            while !Task.isCancelled {
                await printCurrentMetrics()
                try? await Task.sleep(for: updateInterval)
            }
        }
    }

    public func stop() {
        isRunning = false
        displayTask?.cancel()
        displayTask = nil
    }

    private func printCurrentMetrics() async {
        let pdfsGenerated = metricsBackend.counter("htmltopdf_pdfs_generated_total")?.value ?? 0
        let pdfsFailed = metricsBackend.counter("htmltopdf_pdfs_failed_total")?.value ?? 0
        let poolUtil = metricsBackend.gauge("htmltopdf_pool_utilization")?.value ?? 0
        let throughput = metricsBackend.gauge("htmltopdf_throughput_pdfs_per_sec")?.value ?? 0

        let timer = metricsBackend.timer("htmltopdf_render_duration_seconds")
        let p95 = (timer?.p95 ?? 0) * 1000 // Convert to ms

        print("📊 Live Metrics | PDFs: \(pdfsGenerated) | Failed: \(pdfsFailed) | Pool: \(Int(poolUtil)) | Throughput: \(String(format: "%.0f", throughput))/sec | p95: \(String(format: "%.1f", p95))ms")
    }
}

// MARK: - Metrics Assertions

/// Assert that a counter has a specific value
///
/// Example:
/// ```swift
/// try await expectCounter(
///     "htmltopdf_pdfs_generated_total",
///     equals: 100,
///     in: metricsBackend
/// )
/// ```
public func expectCounter(
    _ label: String,
    equals expectedValue: Int64,
    in backend: TestMetricsBackend,
    file: StaticString = #file,
    line: UInt = #line
) async throws {
    let counter = backend.counter(label)
    guard let counter = counter else {
        throw MetricsTestError.metricNotFound(label: label)
    }
    let actualValue = counter.value
    guard actualValue == expectedValue else {
        throw MetricsTestError.valueMismatch(
            label: label,
            expected: "\(expectedValue)",
            actual: "\(actualValue)"
        )
    }
}

/// Assert that a timer's p95 latency is below a threshold
///
/// Example:
/// ```swift
/// try await expectLatency(
///     "htmltopdf_render_duration_seconds",
///     p95LessThan: 0.1, // 100ms
///     in: metricsBackend
/// )
/// ```
public func expectLatency(
    _ label: String,
    p95LessThan threshold: TimeInterval,
    in backend: TestMetricsBackend,
    file: StaticString = #file,
    line: UInt = #line
) async throws {
    let timer = backend.timer(label)
    guard let timer = timer else {
        throw MetricsTestError.metricNotFound(label: label)
    }
    let p95 = timer.p95
    guard p95 < threshold else {
        throw MetricsTestError.thresholdExceeded(
            label: label,
            metric: "p95 latency",
            threshold: "\(threshold)s",
            actual: "\(p95)s"
        )
    }
}

/// Assert that throughput exceeds a minimum threshold
///
/// Example:
/// ```swift
/// try await expectThroughput(
///     greaterThan: 1000.0,
///     pdfsGenerated: 10_000,
///     duration: 10.0,
///     in: metricsBackend
/// )
/// ```
public func expectThroughput(
    greaterThan threshold: Double,
    pdfsGenerated: Int64,
    duration: TimeInterval,
    in backend: TestMetricsBackend,
    file: StaticString = #file,
    line: UInt = #line
) async throws {
    let throughput = Double(pdfsGenerated) / duration
    guard throughput > threshold else {
        throw MetricsTestError.thresholdExceeded(
            label: "throughput",
            metric: "PDFs/sec",
            threshold: "\(threshold)",
            actual: "\(throughput)"
        )
    }
}

// MARK: - Metrics Comparison

/// Compare metrics against a baseline to detect regressions
///
/// Example:
/// ```swift
/// let comparison = await compareMetrics(
///     current: currentBackend,
///     baseline: baselineValues,
///     tolerance: 0.10 // 10% regression allowed
/// )
/// if comparison.hasRegressions {
///     print(comparison.summary())
/// }
/// ```
public struct MetricsComparison: Sendable {
    public let currentP95Latency: TimeInterval
    public let baselineP95Latency: TimeInterval
    public let currentThroughput: Double
    public let baselineThroughput: Double
    public let tolerance: Double

    public init(
        currentP95Latency: TimeInterval,
        baselineP95Latency: TimeInterval,
        currentThroughput: Double,
        baselineThroughput: Double,
        tolerance: Double
    ) {
        self.currentP95Latency = currentP95Latency
        self.baselineP95Latency = baselineP95Latency
        self.currentThroughput = currentThroughput
        self.baselineThroughput = baselineThroughput
        self.tolerance = tolerance
    }

    public var latencyRegression: Double {
        (currentP95Latency - baselineP95Latency) / baselineP95Latency
    }

    public var throughputRegression: Double {
        (baselineThroughput - currentThroughput) / baselineThroughput
    }

    public var hasRegressions: Bool {
        latencyRegression > tolerance || throughputRegression > tolerance
    }

    public func summary() -> String {
        var lines = ["Performance Comparison:"]
        lines.append("  p95 Latency: \(String(format: "%.2f", currentP95Latency * 1000))ms (baseline: \(String(format: "%.2f", baselineP95Latency * 1000))ms)")
        if latencyRegression > tolerance {
            lines.append("    ⚠️  REGRESSION: +\(String(format: "%.1f", latencyRegression * 100))% (tolerance: \(String(format: "%.1f", tolerance * 100))%)")
        }
        lines.append("  Throughput: \(String(format: "%.0f", currentThroughput)) PDFs/sec (baseline: \(String(format: "%.0f", baselineThroughput)) PDFs/sec)")
        if throughputRegression > tolerance {
            lines.append("    ⚠️  REGRESSION: -\(String(format: "%.1f", throughputRegression * 100))% (tolerance: \(String(format: "%.1f", tolerance * 100))%)")
        }
        return lines.joined(separator: "\n")
    }
}

public func compareMetrics(
    current: TestMetricsBackend,
    baselineP95Latency: TimeInterval,
    baselineThroughput: Double,
    tolerance: Double = 0.10
) async -> MetricsComparison {
    let timer = current.timer("htmltopdf_render_duration_seconds")
    let currentP95 = timer?.p95 ?? 0

    let pdfsGenerated = current.counter("htmltopdf_pdfs_generated_total")?.value ?? 0
    let timer2 = current.timer("htmltopdf_render_duration_seconds")
    let totalDuration = (timer2?.values.reduce(0, +) ?? 0)
    let currentThroughput = totalDuration > 0 ? Double(pdfsGenerated) / (TimeInterval(totalDuration) / 1_000_000_000) : 0

    return MetricsComparison(
        currentP95Latency: currentP95,
        baselineP95Latency: baselineP95Latency,
        currentThroughput: currentThroughput,
        baselineThroughput: baselineThroughput,
        tolerance: tolerance
    )
}

// MARK: - Metrics Summary Formatting

/// Format metrics for pretty-printing in tests
public func formatMetricsSummary(_ backend: TestMetricsBackend) async -> String {
    var lines = ["╔══════════════════════════════════════════════════════════╗"]
    lines.append("║              TEST METRICS SUMMARY                        ║")
    lines.append("╚══════════════════════════════════════════════════════════╝")

    let pdfsGenerated = backend.counter("htmltopdf_pdfs_generated_total")?.value ?? 0
    let pdfsFailed = backend.counter("htmltopdf_pdfs_failed_total")?.value ?? 0
    let poolReplacements = backend.counter("htmltopdf_pool_replacements_total")?.value ?? 0

    lines.append("\n📊 Counters:")
    lines.append("  • PDFs Generated: \(pdfsGenerated)")
    lines.append("  • PDFs Failed: \(pdfsFailed)")
    lines.append("  • Pool Replacements: \(poolReplacements)")

    let poolUtil = backend.gauge("htmltopdf_pool_utilization")?.value ?? 0
    let throughput = backend.gauge("htmltopdf_throughput_pdfs_per_sec")?.value ?? 0

    lines.append("\n📏 Gauges:")
    lines.append("  • Pool Utilization: \(Int(poolUtil))")
    lines.append("  • Throughput: \(String(format: "%.0f", throughput)) PDFs/sec")

    if let timer = backend.timer("htmltopdf_render_duration_seconds") {
        lines.append("\n⏱️  Render Duration:")
        lines.append("  • Count: \(timer.values.count)")
        lines.append("  • Average: \(String(format: "%.2f", timer.average * 1000))ms")
        lines.append("  • p50: \(String(format: "%.2f", timer.p50 * 1000))ms")
        lines.append("  • p95: \(String(format: "%.2f", timer.p95 * 1000))ms")
        lines.append("  • p99: \(String(format: "%.2f", timer.p99 * 1000))ms")
    }

    lines.append("\n╚══════════════════════════════════════════════════════════╝")
    return lines.joined(separator: "\n")
}

// MARK: - Dimension Helpers

/// Get metrics grouped by dimension
///
/// Example:
/// ```swift
/// let byMode = await metricsByDimension(
///     label: "htmltopdf_render_duration_seconds",
///     dimension: "mode",
///     in: backend
/// )
/// // Returns: ["continuous": TestTimer, "paginated": TestTimer]
/// ```
public func timersByDimension(
    label: String,
    dimension: String,
    in backend: TestMetricsBackend
) async -> [String: TestTimer] {
    let timers = backend.timers(withLabel: label)
    var result: [String: TestTimer] = [:]

    for timer in timers {
        if let value = timer.dimensions.first(where: { $0.0 == dimension })?.1 {
            result[value] = timer
        }
    }

    return result
}

/// Get counters grouped by dimension
public func countersByDimension(
    label: String,
    dimension: String,
    in backend: TestMetricsBackend
) async -> [String: TestCounter] {
    let counters = backend.counters(withLabel: label)
    var result: [String: TestCounter] = [:]

    for counter in counters {
        if let value = counter.dimensions.first(where: { $0.0 == dimension })?.1 {
            result[value] = counter
        }
    }

    return result
}

// MARK: - Error Types

public enum MetricsTestError: Error, CustomStringConvertible {
    case metricNotFound(label: String)
    case valueMismatch(label: String, expected: String, actual: String)
    case thresholdExceeded(label: String, metric: String, threshold: String, actual: String)

    public var description: String {
        switch self {
        case .metricNotFound(let label):
            return "Metric not found: \(label)"
        case .valueMismatch(let label, let expected, let actual):
            return "Metric '\(label)' value mismatch - expected: \(expected), actual: \(actual)"
        case .thresholdExceeded(let label, let metric, let threshold, let actual):
            return "Metric '\(label)' \(metric) exceeded threshold - threshold: \(threshold), actual: \(actual)"
        }
    }
}
