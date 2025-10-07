//
//  TestMetricsBackend.swift
//  PDFTestSupport
//
//  Test-specific metrics backend for capturing and asserting on metrics
//

import Foundation
import Metrics
import Dependencies

/// Test metrics backend that captures all recorded metrics for testing
///
/// Use this to validate that metrics are actually being recorded during tests:
///
/// ```swift
/// let metricsBackend = TestMetricsBackend()
/// MetricsSystem.bootstrap(metricsBackend)
///
/// // Run your test code that generates metrics
/// try await pdf.render.client.html(html, to: output)
///
/// // Assert on captured metrics
/// #expect(metricsBackend.counters["htmltopdf_pdfs_generated_total"]?.value == 100)
/// #expect(metricsBackend.timers["htmltopdf_render_duration_seconds"]?.p95 < 0.1)
/// ```
public final class TestMetricsBackend: MetricsFactory, @unchecked Sendable {

    // MARK: - Captured Metrics

    private let lock = NSLock()
    private var _counters: [String: TestCounter] = [:]
    private var _meters: [String: TestMeter] = [:]
    private var _timers: [String: TestTimer] = [:]
    private var _recorders: [String: TestRecorder] = [:]

    package var counters: [String: TestCounter] {
        lock.withLock { _counters }
    }

    package var meters: [String: TestMeter] {
        lock.withLock { _meters }
    }

    package var timers: [String: TestTimer] {
        lock.withLock { _timers }
    }

    package var recorders: [String: TestRecorder] {
        lock.withLock { _recorders }
    }

    public init() {}

    // MARK: - MetricsFactory Implementation

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        lock.withLock {
            let key = makeKey(label: label, dimensions: dimensions)
            if let existing = _counters[key] {
                return existing
            }
            let counter = TestCounter(label: label, dimensions: dimensions)
            _counters[key] = counter
            return counter
        }
    }

    public func makeFloatingPointCounter(label: String, dimensions: [(String, String)]) -> FloatingPointCounterHandler {
        lock.withLock {
            let key = makeKey(label: label, dimensions: dimensions)
            if let existing = _counters[key] {
                return existing
            }
            let counter = TestCounter(label: label, dimensions: dimensions)
            _counters[key] = counter
            return counter
        }
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        lock.withLock {
            let key = makeKey(label: label, dimensions: dimensions)
            if let existing = _meters[key] {
                return existing
            }
            let meter = TestMeter(label: label, dimensions: dimensions)
            _meters[key] = meter
            return meter
        }
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        lock.withLock {
            let key = makeKey(label: label, dimensions: dimensions)
            if let existing = _timers[key] {
                return existing
            }
            let timer = TestTimer(label: label, dimensions: dimensions)
            _timers[key] = timer
            return timer
        }
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        lock.withLock {
            let key = makeKey(label: label, dimensions: dimensions)
            if let existing = _recorders[key] {
                return existing
            }
            let recorder = TestRecorder(label: label, dimensions: dimensions)
            _recorders[key] = recorder
            return recorder
        }
    }

    public func destroyCounter(_ handler: CounterHandler) {
        lock.withLock {
            if let testCounter = handler as? TestCounter {
                _counters.removeValue(forKey: testCounter.key)
            }
        }
    }

    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {
        lock.withLock {
            if let testCounter = handler as? TestCounter {
                _counters.removeValue(forKey: testCounter.key)
            }
        }
    }

    public func destroyMeter(_ handler: MeterHandler) {
        lock.withLock {
            if let testMeter = handler as? TestMeter {
                _meters.removeValue(forKey: testMeter.key)
            }
        }
    }

    public func destroyTimer(_ handler: TimerHandler) {
        lock.withLock {
            if let testTimer = handler as? TestTimer {
                _timers.removeValue(forKey: testTimer.key)
            }
        }
    }

    public func destroyRecorder(_ handler: RecorderHandler) {
        lock.withLock {
            if let testRecorder = handler as? TestRecorder {
                _recorders.removeValue(forKey: testRecorder.key)
            }
        }
    }

    // MARK: - Test Utilities

    /// Reset all captured metrics
    public func reset() {
        lock.withLock {
            _counters.removeAll()
            _meters.removeAll()
            _timers.removeAll()
            _recorders.removeAll()
        }
    }

    /// Get counter by label (without dimensions)
    public func counter(_ label: String) -> TestCounter? {
        lock.withLock { _counters[label] }
    }

    /// Get gauge by label (without dimensions)
    /// Note: In swift-metrics, Gauge is implemented as a Recorder
    public func gauge(_ label: String) -> TestRecorder? {
        lock.withLock { _recorders[label] }
    }

    /// Get meter by label (without dimensions)
    public func meter(_ label: String) -> TestMeter? {
        lock.withLock { _meters[label] }
    }

    /// Get timer by label (without dimensions)
    public func timer(_ label: String) -> TestTimer? {
        lock.withLock { _timers[label] }
    }

    /// Get all counters with a specific label (across all dimensions)
    public func counters(withLabel label: String) -> [TestCounter] {
        lock.withLock { _counters.values.filter { $0.label == label } }
    }

    /// Get all timers with a specific label (across all dimensions)
    public func timers(withLabel label: String) -> [TestTimer] {
        lock.withLock { _timers.values.filter { $0.label == label } }
    }

    /// Print summary of all captured metrics
    public func printSummary() {
        lock.withLock {
            print("\n╔══════════════════════════════════════════════════════════╗")
            print("║              TEST METRICS SUMMARY                        ║")
            print("╚══════════════════════════════════════════════════════════╝")

            if !_counters.isEmpty {
                print("\n📊 Counters:")
                for (_, counter) in _counters.sorted(by: { $0.key < $1.key }) {
                    let dims = counter.dimensions.isEmpty ? "" : " (\(formatDimensions(counter.dimensions)))"
                    print("  • \(counter.label)\(dims): \(counter.value)")
                }
            }

            if !_meters.isEmpty {
                print("\n📏 Meters/Gauges:")
                for (_, meter) in _meters.sorted(by: { $0.key < $1.key }) {
                    let dims = meter.dimensions.isEmpty ? "" : " (\(formatDimensions(meter.dimensions)))"
                    print("  • \(meter.label)\(dims): \(meter.value)")
                }
            }

            if !_timers.isEmpty {
                print("\n⏱️  Timers:")
                for (_, timer) in _timers.sorted(by: { $0.key < $1.key }) {
                    let dims = timer.dimensions.isEmpty ? "" : " (\(formatDimensions(timer.dimensions)))"
                    print("  • \(timer.label)\(dims):")
                    print("      count: \(timer.values.count)")
                    if !timer.values.isEmpty {
                        print("      p50: \(String(format: "%.3f", timer.p50 * 1000))ms")
                        print("      p95: \(String(format: "%.3f", timer.p95 * 1000))ms")
                        print("      p99: \(String(format: "%.3f", timer.p99 * 1000))ms")
                    }
                }
            }

            print("\n╚══════════════════════════════════════════════════════════╝\n")
        }
    }

    // MARK: - Private Helpers

    private func makeKey(label: String, dimensions: [(String, String)]) -> String {
        if dimensions.isEmpty {
            return label
        }
        let dimStr = dimensions.sorted(by: { $0.0 < $1.0 })
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: ",")
        return "\(label){\(dimStr)}"
    }

    private func formatDimensions(_ dimensions: [(String, String)]) -> String {
        dimensions.map { "\($0.0)=\($0.1)" }.joined(separator: ", ")
    }
}

// MARK: - Test Metric Handlers

public final class TestCounter: CounterHandler, FloatingPointCounterHandler, @unchecked Sendable {
    public let label: String
    public let dimensions: [(String, String)]
    fileprivate let key: String

    private let lock = NSLock()
    private var _value: Int64 = 0

    package var value: Int64 {
        lock.withLock { _value }
    }

    init(label: String, dimensions: [(String, String)]) {
        self.label = label
        self.dimensions = dimensions
        self.key = dimensions.isEmpty ? label :
            "\(label){\(dimensions.sorted(by: { $0.0 < $1.0 }).map { "\($0.0)=\($0.1)" }.joined(separator: ","))}"
    }

    public func increment(by amount: Int64) {
        lock.withLock {
            _value += amount
        }
    }

    public func increment(by amount: Double) {
        lock.withLock {
            _value += Int64(amount)
        }
    }

    public func reset() {
        lock.withLock {
            _value = 0
        }
    }
}

public final class TestMeter: MeterHandler, @unchecked Sendable {
    public let label: String
    public let dimensions: [(String, String)]
    fileprivate let key: String

    private let lock = NSLock()
    private var _value: Double = 0

    package var value: Double {
        lock.withLock { _value }
    }

    init(label: String, dimensions: [(String, String)]) {
        self.label = label
        self.dimensions = dimensions
        self.key = dimensions.isEmpty ? label :
            "\(label){\(dimensions.sorted(by: { $0.0 < $1.0 }).map { "\($0.0)=\($0.1)" }.joined(separator: ","))}"
    }

    public func set(_ value: Int64) {
        lock.withLock {
            _value = Double(value)
        }
    }

    public func set(_ value: Double) {
        lock.withLock {
            _value = value
        }
    }

    public func increment(by amount: Double) {
        lock.withLock {
            _value += amount
        }
    }

    public func decrement(by amount: Double) {
        lock.withLock {
            _value -= amount
        }
    }
}

public final class TestTimer: TimerHandler, @unchecked Sendable {
    public let label: String
    public let dimensions: [(String, String)]
    fileprivate let key: String

    private let lock = NSLock()
    private var _values: [Int64] = []

    package var values: [Int64] {
        lock.withLock { _values }
    }

    /// Average duration in seconds
    package var average: TimeInterval {
        let vals = values
        guard !vals.isEmpty else { return 0 }
        let sum = vals.reduce(0, +)
        return TimeInterval(sum) / TimeInterval(vals.count) / 1_000_000_000
    }

    /// Minimum duration in seconds
    package var min: TimeInterval {
        guard let minVal = values.min() else { return 0 }
        return TimeInterval(minVal) / 1_000_000_000
    }

    /// Maximum duration in seconds
    package var max: TimeInterval {
        guard let maxVal = values.max() else { return 0 }
        return TimeInterval(maxVal) / 1_000_000_000
    }

    /// 50th percentile (median) in seconds
    package var p50: TimeInterval {
        percentile(0.50)
    }

    /// 95th percentile in seconds
    package var p95: TimeInterval {
        percentile(0.95)
    }

    /// 99th percentile in seconds
    package var p99: TimeInterval {
        percentile(0.99)
    }

    init(label: String, dimensions: [(String, String)]) {
        self.label = label
        self.dimensions = dimensions
        self.key = dimensions.isEmpty ? label :
            "\(label){\(dimensions.sorted(by: { $0.0 < $1.0 }).map { "\($0.0)=\($0.1)" }.joined(separator: ","))}"
    }

    public func recordNanoseconds(_ duration: Int64) {
        lock.withLock {
            _values.append(duration)
        }
    }

    private func percentile(_ p: Double) -> TimeInterval {
        let vals = values.sorted()
        guard !vals.isEmpty else { return 0 }
        let index = Int(Double(vals.count) * p)
        let clampedIndex = Swift.min(index, vals.count - 1)
        return TimeInterval(vals[clampedIndex]) / 1_000_000_000
    }
}

public final class TestRecorder: RecorderHandler, @unchecked Sendable {
    public let label: String
    public let dimensions: [(String, String)]
    fileprivate let key: String

    private let lock = NSLock()
    private var _values: [Double] = []

    package var values: [Double] {
        lock.withLock { _values }
    }

    /// Current value (for gauge-like usage, returns last recorded value)
    package var value: Double {
        lock.withLock { _values.last ?? 0 }
    }

    init(label: String, dimensions: [(String, String)]) {
        self.label = label
        self.dimensions = dimensions
        self.key = dimensions.isEmpty ? label :
            "\(label){\(dimensions.sorted(by: { $0.0 < $1.0 }).map { "\($0.0)=\($0.1)" }.joined(separator: ","))}"
    }

    public func record(_ value: Int64) {
        lock.withLock {
            _values.append(Double(value))
        }
    }

    public func record(_ value: Double) {
        lock.withLock {
            _values.append(value)
        }
    }
}

// MARK: - Direct Usage (for tests that don't use Dependencies)
//
// Note: The `forTest()` method requires `@testable import CoreMetrics` to access
// `bootstrapInternal()`, which is not available in library targets when building
// for release. Tests that need this functionality should implement it locally with:
//
// ```swift
// @testable import CoreMetrics
//
// extension TestMetricsBackend {
//     static let shared: TestMetricsBackend = {
//         let backend = TestMetricsBackend()
//         MetricsSystem.bootstrapInternal(backend)
//         return backend
//     }()
// }
// ```

// MARK: - Note on Test Isolation with Dependencies
//
// TestMetricsBackend is NOT exposed as a standalone dependency key.
// Instead, it's embedded within PDF.Render.Metrics.testValue.
//
// This ensures the same backend instance used for recording metrics
// is the one tests inspect, solving the "separate instances" problem
// that occurs with Swift 6.2+ where testValue is evaluated once globally.
