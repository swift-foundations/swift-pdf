# Production Metrics Guide

Monitor PDF generation performance, errors, and resource utilization in production.

## Overview

swift-html-to-pdf automatically collects comprehensive metrics during PDF generation. In production, these metrics integrate with your monitoring stack via [swift-metrics](https://github.com/apple/swift-metrics), enabling dashboards, alerts, and performance analysis.

**Key Features:**
- 📊 **Zero-configuration** - Metrics collected automatically during PDF generation
- 🔌 **Pluggable backends** - Works with Prometheus, StatsD, Datadog, CloudWatch, and more
- 🧪 **Test-friendly** - In-memory metrics for tests, production backends for deployment
- 📈 **Rich dimensions** - Track performance by pagination mode, error type, and more
- ⚡ **Low overhead** - Minimal performance impact (<0.02%)

## Quick Reference

```swift
// 1. Bootstrap at app startup
MetricsSystem.bootstrap(PrometheusMetricsFactory())

// 2. Use library normally - metrics auto-collected
@Dependency(\.pdf) var pdf
try await pdf.render(html: documents, to: directory)

// 3. Expose metrics endpoint
app.get("metrics") { _ in try MetricsSystem.prometheus().collect() }

// 4. Query in Prometheus
rate(htmltopdf_pdfs_generated_total[5m])  // Throughput
histogram_quantile(0.95, rate(htmltopdf_render_duration_seconds_bucket[5m]))  // P95 latency
```

## Available Metrics

| Metric | Type | Description | Dimensions |
|--------|------|-------------|------------|
| `htmltopdf_pdfs_generated_total` | Counter | Total PDFs successfully generated | - |
| `htmltopdf_pdfs_failed_total` | Counter | Total PDF generation failures | `reason` (error type) |
| `htmltopdf_render_duration_seconds` | Timer | PDF render duration distribution | `mode` (pagination mode) |
| `htmltopdf_pool_replacements_total` | Counter | Resource pool replacement events | - |
| `htmltopdf_pool_utilization` | Gauge | Active WebViews currently in use | - |
| `htmltopdf_throughput_pdfs_per_sec` | Gauge | Current rendering throughput | - |

## Metric Dimensions

Some metrics include dimensions (labels) for segmented analysis:

### Pagination Mode Dimension

The `htmltopdf_render_duration_seconds` timer includes a `mode` dimension to track performance by pagination strategy:

**Dimension values:**
- `continuous` - Single tall page
- `paginated` - Multi-page layout
- `automatic_content_length` - Auto-detection based on content length
- `automatic_html_structure` - Auto-detection based on HTML structure
- `automatic_prefer_speed` - Auto-detection preferring speed
- `automatic_prefer_print_ready` - Auto-detection preferring print quality

**Example Prometheus query:**
```promql
# Compare p95 latency by pagination mode
histogram_quantile(0.95,
  rate(htmltopdf_render_duration_seconds_bucket[5m])
) by (mode)
```

### Error Reason Dimension

The `htmltopdf_pdfs_failed_total` counter includes a `reason` dimension to identify failure types:

**Dimension values:**
- `invalid_html` - Malformed HTML content
- `invalid_file_path` - File path not accessible
- `directory_creation_failed` - Cannot create output directory
- `webview_loading_failed` - WebView failed to load HTML
- `webview_navigation_failed` - WebView navigation error
- `webview_rendering_timeout` - Rendering exceeded timeout
- `webview_pool_exhausted` - No available WebViews
- `webview_acquisition_timeout` - Pool acquisition timeout
- `webview_pool_initialization_failed` - Pool setup failed
- `pdf_generation_failed` - PDF creation error
- `print_operation_failed` - Print operation error
- `document_timeout` - Document processing timeout
- `batch_timeout` - Batch processing timeout
- `cancelled` - Operation cancelled
- `no_result_produced` - No output generated
- `capability_unavailable` - Platform capability missing

**Example Prometheus query:**
```promql
# Top 5 failure reasons
topk(5,
  sum by (reason) (
    rate(htmltopdf_pdfs_failed_total[5m])
  )
)
```

## Quick Start

### 1. Add Metrics Backend

Add a metrics backend to your `Package.swift`:

```swift
dependencies: [
    // Prometheus (recommended)
    .package(url: "https://github.com/MrLotU/SwiftPrometheus", from: "1.0.0"),

    // Or StatsD
    .package(url: "https://github.com/apple/swift-statsd-client", from: "1.0.0"),

    // Or CloudWatch
    .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime", from: "1.0.0")
]
```

### 2. Bootstrap Metrics System

**Call once at application startup** - before any PDF generation:

```swift
import Metrics
import Prometheus

@main
struct MyApp {
    static func main() async throws {
        // Bootstrap metrics FIRST
        MetricsSystem.bootstrap(PrometheusMetricsFactory())

        // Then start your application
        try await runServer()
    }
}
```

> **Important:** `MetricsSystem.bootstrap()` must be called exactly once, before any PDF generation. The library will automatically use your configured backend.

### 3. Use Library Normally

Metrics are collected automatically - no code changes needed:

```swift
@Dependency(\.pdf) var pdf

// Generate PDFs - metrics auto-recorded
for try await result in try await pdf.render(html: invoices, to: directory) {
    // ✅ htmltopdf_pdfs_generated_total incremented
    // ✅ htmltopdf_render_duration_seconds recorded
    // ✅ htmltopdf_pool_utilization updated
}
```

### 4. Expose Metrics Endpoint (Prometheus)

Create an endpoint that exports metrics:

```swift
// Vapor
app.get("metrics") { req -> String in
    try MetricsSystem.prometheus().collect()
}

// Hummingbird
router.get("/metrics") { _, _ -> String in
    try MetricsSystem.prometheus().collect()
}
```

That's it! Metrics are now being collected and exported.

## Integration Examples

### Example 1: Prometheus + Vapor

```swift
import Vapor
import Metrics
import Prometheus

// Configure Prometheus at app startup
public func configure(_ app: Application) async throws {
    // Bootstrap metrics
    let prometheus = PrometheusMetricsFactory()
    MetricsSystem.bootstrap(prometheus)

    // Expose metrics endpoint
    app.get("metrics") { req -> String in
        try MetricsSystem.prometheus().collect()
    }

    // Your routes
    app.post("generate-pdf") { req async throws -> Response in
        let html = try req.content.decode(HTMLRequest.self)

        @Dependency(\.pdf) var pdf
        let pdfData = try await pdf.render(html: html.content)

        return Response(
            status: .ok,
            headers: ["Content-Type": "application/pdf"],
            body: .init(data: pdfData)
        )
    }
}
```

**Configure Prometheus scraping:**

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'pdf-service'
    scrape_interval: 15s
    static_configs:
      - targets: ['localhost:8080']
```

### Example 2: Prometheus + Hummingbird

```swift
import Hummingbird
import Metrics
import Prometheus

@main
struct App {
    static func main() async throws {
        // Bootstrap metrics
        MetricsSystem.bootstrap(PrometheusMetricsFactory())

        let router = Router()

        // Metrics endpoint
        router.get("/metrics") { _, _ -> String in
            try MetricsSystem.prometheus().collect()
        }

        // PDF generation endpoint
        router.post("/pdf") { request, context async throws -> Response in
            @Dependency(\.pdf) var pdf

            let html = try await request.body.collect(upTo: .max)
            let htmlString = String(buffer: html)

            let pdfData = try await pdf.render(html: htmlString)

            return Response(
                status: .ok,
                headers: [.contentType: "application/pdf"],
                body: .init(data: pdfData)
            )
        }

        let app = Application(router: router)
        try await app.runService()
    }
}
```

### Example 3: StatsD + Datadog

```swift
import Metrics
import StatsdClient

// Configure StatsD client
let statsd = try StatsdClient(
    host: "localhost",
    port: 8125,
    prefix: "myapp"
)

// Bootstrap with StatsD backend
MetricsSystem.bootstrap(StatsdMetricsFactory(client: statsd))

// Use library normally - metrics forwarded to Datadog
@Dependency(\.pdf) var pdf
try await pdf.render(html: documents, to: directory)
```

## Grafana Dashboards

### Example Dashboard Queries

**PDF Generation Throughput**
```promql
rate(htmltopdf_pdfs_generated_total[5m])
```

**P50/P95/P99 Render Duration**
```promql
histogram_quantile(0.50, rate(htmltopdf_render_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(htmltopdf_render_duration_seconds_bucket[5m]))
histogram_quantile(0.99, rate(htmltopdf_render_duration_seconds_bucket[5m]))
```

**Error Rate Percentage**
```promql
(
  rate(htmltopdf_pdfs_failed_total[5m])
  /
  (rate(htmltopdf_pdfs_generated_total[5m]) + rate(htmltopdf_pdfs_failed_total[5m]))
) * 100
```

**Pool Utilization**
```promql
htmltopdf_pool_utilization
```

**Current Throughput**
```promql
htmltopdf_throughput_pdfs_per_sec
```

**Pool Replacements Over Time**
```promql
rate(htmltopdf_pool_replacements_total[1h])
```

### Sample Dashboard JSON

```json
{
  "dashboard": {
    "title": "PDF Generation Metrics",
    "panels": [
      {
        "title": "PDF Throughput",
        "targets": [
          {
            "expr": "rate(htmltopdf_pdfs_generated_total[5m])"
          }
        ]
      },
      {
        "title": "P95 Latency",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(htmltopdf_render_duration_seconds_bucket[5m]))"
          }
        ]
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "(rate(htmltopdf_pdfs_failed_total[5m]) / (rate(htmltopdf_pdfs_generated_total[5m]) + rate(htmltopdf_pdfs_failed_total[5m]))) * 100"
          }
        ]
      },
      {
        "title": "Pool Utilization",
        "targets": [
          {
            "expr": "htmltopdf_pool_utilization"
          }
        ]
      }
    ]
  }
}
```

## Alerting Rules

### Prometheus Alert Examples

```yaml
# prometheus-alerts.yml
groups:
  - name: pdf_generation
    rules:
      # High error rate
      - alert: HighPDFErrorRate
        expr: |
          (
            rate(htmltopdf_pdfs_failed_total[5m])
            /
            (rate(htmltopdf_pdfs_generated_total[5m]) + rate(htmltopdf_pdfs_failed_total[5m]))
          ) > 0.01
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "PDF generation error rate above 1%"
          description: "Error rate is {{ $value | humanizePercentage }}"

      # High latency
      - alert: HighPDFLatency
        expr: |
          histogram_quantile(0.95, rate(htmltopdf_render_duration_seconds_bucket[5m])) > 0.1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "P95 PDF render latency above 100ms"
          description: "P95 latency is {{ $value }}s"

      # Low throughput
      - alert: LowPDFThroughput
        expr: |
          rate(htmltopdf_pdfs_generated_total[5m]) < 100
        for: 15m
        labels:
          severity: info
        annotations:
          summary: "PDF generation throughput below 100/sec"
          description: "Current throughput is {{ $value | humanize }} PDFs/sec"

      # Frequent pool replacements
      - alert: FrequentPoolReplacements
        expr: |
          rate(htmltopdf_pool_replacements_total[1h]) > 0.1
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "Pool replacements happening too frequently"
          description: "Pool is being replaced {{ $value | humanize }} times per hour (potential memory issues)"
```

## Monitoring Best Practices

### 1. Set Appropriate Alert Thresholds

Adjust thresholds based on your workload:

```yaml
# For high-volume services (>1000 PDFs/sec)
- alert: HighLatency
  expr: histogram_quantile(0.95, rate(htmltopdf_render_duration_seconds_bucket[5m])) > 0.050  # 50ms

# For standard services (100-1000 PDFs/sec)
- alert: HighLatency
  expr: histogram_quantile(0.95, rate(htmltopdf_render_duration_seconds_bucket[5m])) > 0.100  # 100ms

# For low-volume services (<100 PDFs/sec)
- alert: HighLatency
  expr: histogram_quantile(0.95, rate(htmltopdf_render_duration_seconds_bucket[5m])) > 0.200  # 200ms
```

### 2. Monitor Pool Health

Track pool replacements to detect memory issues:

```promql
# Normal: <0.05 replacements/hour (once per 20+ hours)
# Warning: >0.1 replacements/hour (multiple per hour)
rate(htmltopdf_pool_replacements_total[1h])
```

### 3. Correlate with System Metrics

Combine with system metrics for full picture:

```promql
# Memory usage vs PDF generation
rate(htmltopdf_pdfs_generated_total[5m]) / process_resident_memory_bytes

# CPU usage vs throughput
rate(htmltopdf_pdfs_generated_total[5m]) / process_cpu_seconds_total
```

### 4. Track SLAs

Define and monitor service level objectives:

```swift
// SLO: 99% of requests complete within 100ms
// SLI: P99 latency
histogram_quantile(0.99, rate(htmltopdf_render_duration_seconds_bucket[5m])) < 0.100

// SLO: Error rate below 0.1%
// SLI: Error rate
(rate(htmltopdf_pdfs_failed_total[5m]) / rate(htmltopdf_pdfs_generated_total[5m])) < 0.001
```

## Testing with Metrics

The library uses a **dual implementation** strategy for testing:

- **Production**: Metrics delegate to swift-metrics (Prometheus, StatsD, etc.)
- **Tests**: Metrics use in-memory storage with zero configuration

### Test Pattern

Tests automatically use in-memory metrics - no `MetricsSystem.bootstrap()` needed:

```swift
import Testing
import Dependencies
import PDFTestSupport
@testable import HtmlToPdf

@Test("Metrics are collected during PDF generation")
func metricsCollection() async throws {
    // Create test metrics with in-memory storage
    let (testMetrics, storage) = makeTestMetrics()

    try await withDependencies {
        $0.pdf.render.metrics = testMetrics
    } operation: {
        @Dependency(\.pdf) var pdf

        // Generate PDF
        let html = "<html><body><h1>Test</h1></body></html>"
        _ = try await pdf.render(html: html, to: URL.output())

        // Assert on captured metrics
        #expect(storage.pdfsGenerated == 1)
        #expect(storage.renderDurations.count == 1)
        #expect(storage.pdfsFailed == 0)
    }
}
```

### Available Test Assertions

The `TestMetricsStorage` class provides access to all captured metrics:

```swift
let (metrics, storage) = makeTestMetrics()

// Counters
storage.pdfsGenerated        // Int64
storage.pdfsFailed           // Int64
storage.poolReplacements     // Int64

// Timers
storage.renderDurations      // [(Duration, PaginationMode?)]
storage.p95Duration          // Duration? (computed)

// Gauges
storage.poolUtilization      // Int
storage.currentThroughput    // Double

// Reset between operations
storage.reset()
```

### Why Two Implementations?

The dual implementation solves a fundamental incompatibility:

- **swift-metrics** uses global singleton state (perfect for production)
- **swift-dependencies** uses task-local state (perfect for test isolation)

By using closures that delegate to different backends, we get:
- ✅ Production integration with standard metrics systems
- ✅ Perfect test isolation with zero configuration
- ✅ Same API for both contexts

### Architecture Note

The metrics system follows the `@DependencyClient` pattern:

```swift
@DependencyClient
public struct Metrics {
    var incrementPDFsGenerated: () -> Void
    var recordRenderDuration: (Duration, PaginationMode?) -> Void
    // ... closure-based operations
}

// Production: closures call swift-metrics Counter/Timer/Gauge
extension Metrics: DependencyKey {
    static var liveValue: Self {
        let counter = Counter(label: "htmltopdf_pdfs_generated_total")
        return Self(incrementPDFsGenerated: { counter.increment() })
    }
}

// Tests: closures update in-memory storage
func makeTestMetrics() -> (Metrics, TestMetricsStorage) {
    let storage = TestMetricsStorage()
    return (Metrics(incrementPDFsGenerated: { storage.pdfsGenerated += 1 }), storage)
}
```

This architecture ensures production gets real metrics backends while tests get automatic isolation.

## Troubleshooting

### Metrics Not Appearing

1. **Verify bootstrap was called**
   ```swift
   // Must be called before any PDF generation
   MetricsSystem.bootstrap(PrometheusMetricsFactory())
   ```

2. **Check endpoint is accessible**
   ```bash
   curl http://localhost:8080/metrics
   ```

3. **Verify Prometheus scraping**
   ```bash
   # Check Prometheus targets
   curl http://localhost:9090/api/v1/targets
   ```

### High Pool Replacement Rate

If you see frequent pool replacements:

1. **Monitor memory usage**
   ```promql
   process_resident_memory_bytes
   ```

2. **Check system resource pressure**
   - Monitor CPU utilization
   - Check available memory

3. **Consider increasing pool size if needed**
   ```swift
   $0.pdf.render.configuration.concurrency = 32  // Increase from default 24
   ```

## Performance Impact

Metrics collection has **minimal overhead**:

- **Counter increments**: ~10-20 nanoseconds per operation
- **Timer recordings**: ~50-100 nanoseconds per measurement
- **Gauge updates**: ~10-20 nanoseconds per update

For a typical PDF generation:
- **Metrics overhead**: <0.001ms (negligible)
- **PDF generation time**: 2-5ms (typical)
- **Impact**: <0.02% performance cost

The metrics system is designed to be **always-on** in production with no performance concerns.

## Advanced Configuration

### Custom Metric Labels

You can access the metrics dependency directly for custom tracking:

```swift
@Dependency(\.pdf.render.metrics) var metrics

// Record custom success metrics
let startTime = Date()
try await generatePDF()
let duration = Date().timeIntervalSince(startTime)
metrics.recordSuccess(duration: .seconds(duration), mode: .paginated)

// Record custom failures
do {
    try await generatePDF()
} catch let error as PrintingError {
    metrics.recordFailure(error: error)
    throw error
}
```

### Disable Metrics (Not Recommended)

If you need to disable metrics entirely, provide a no-op implementation:

```swift
@Dependency(\.pdf.render.metrics) var metrics = PDF.Render.Metrics(
    incrementPDFsGenerated: {},
    incrementPDFsFailed: {},
    incrementPoolReplacements: {},
    recordRenderDuration: { _, _ in },
    updatePoolUtilization: { _ in },
    updateThroughput: { _ in }
)
```

However, metrics have such low overhead that disabling them provides no meaningful benefit.

## Migration from v0.x

If upgrading from an earlier version:

**Before (v0.x - if metrics existed):**
```swift
// Manual metrics tracking
let counter = Counter(label: "pdfs_generated")
counter.increment()
```

**After (v1.0+):**
```swift
// Automatic metrics tracking - no code changes needed!
@Dependency(\.pdf) var pdf
try await pdf.render(html: documents, to: directory)
// Metrics automatically recorded
```

## FAQ

### Do I need to call MetricsSystem.bootstrap() in tests?

**No.** Tests automatically use in-memory metrics. Only production applications need to bootstrap the metrics system.

### Can I use multiple metrics backends?

**Yes.** swift-metrics supports multiplexing to multiple backends:

```swift
import Metrics

let prometheus = PrometheusMetricsFactory()
let statsd = StatsdMetricsFactory()
let multiplexer = MultiplexMetricsFactory([prometheus, statsd])

MetricsSystem.bootstrap(multiplexer)
```

### What happens if I don't bootstrap MetricsSystem?

The library will use swift-metrics' default no-op handler. Metrics calls succeed but do nothing. No errors occur, metrics are just not exported.

### How do I verify metrics are being collected?

1. Generate some PDFs in your application
2. Access your metrics endpoint: `curl http://localhost:8080/metrics`
3. Look for metrics with the `htmltopdf_` prefix
4. Check Prometheus UI if using Prometheus

### Can I customize metric labels?

The metric labels are fixed to ensure consistency. However, you can add custom dimensions when recording failures (the error type is automatically added as a `reason` dimension).

## See Also

- [swift-metrics Documentation](https://github.com/apple/swift-metrics) - Understand the underlying metrics framework
- [Prometheus Documentation](https://prometheus.io/docs/) - Configure Prometheus scraping and querying
- [Grafana Documentation](https://grafana.com/docs/) - Build dashboards and alerts
- [Performance Guide](PerformanceGuide.md) - Optimize PDF generation performance
