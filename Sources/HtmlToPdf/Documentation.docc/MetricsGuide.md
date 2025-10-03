# Production Metrics Guide

Export performance metrics from swift-html-to-pdf to your monitoring system.

## Overview

swift-html-to-pdf automatically collects metrics about PDF generation performance, errors, and resource utilization. These metrics integrate with standard monitoring stacks via [swift-metrics](https://github.com/apple/swift-metrics).

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
    .package(url: "https://github.com/MrLotU/SwiftPrometheus", from: "1.0.0")
]
```

### 2. Bootstrap Metrics System

Call once at application startup:

```swift
import Metrics
import Prometheus

// Configure Prometheus backend
let prometheus = PrometheusMetricsFactory()
MetricsSystem.bootstrap(prometheus)
```

### 3. Use Library Normally

Metrics are collected automatically:

```swift
@Dependency(\.pdf) var pdf

// Generate PDFs - metrics auto-recorded
for try await result in try await pdf.render(htmls: invoices, to: dir) {
    // Each success increments htmltopdf_pdfs_generated_total
    // Each duration updates htmltopdf_render_duration_seconds
}
```

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
try await pdf.render(htmls: documents, to: directory)
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

## Testing Metrics

### Verify Metrics in Tests

```swift
import Testing
import Metrics
@testable import HtmlToPdf

@Test("Metrics are collected during rendering")
func metricsCollection() async throws {
    @Dependency(\.pdf) var pdf
    @Dependency(\.pdf.render.metrics) var metrics

    // Verify metrics exist
    #expect(metrics.pdfsGenerated.label == "htmltopdf_pdfs_generated_total")

    // Generate PDF
    let html = "<html><body><h1>Test</h1></body></html>"
    let output = URL.output().appendingPathComponent("test.pdf")
    defer { try? FileManager.default.removeItem(at: output) }

    _ = try await pdf.render(html: html, to: output)

    // Metrics are recorded (without backend, they're no-ops but API works)
}
```

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

1. **Check configuration**
   ```swift
   // Ensure adaptive optimization is working
   $0.pdf.render.configuration.adaptiveThroughputOptimization = true
   ```

2. **Monitor memory usage**
   ```promql
   process_resident_memory_bytes
   ```

3. **Consider increasing pool size**
   ```swift
   $0.pdf.render.configuration.concurrency = 32  // Increase from default 24
   ```

## See Also

- [swift-metrics Documentation](https://github.com/apple/swift-metrics)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Performance Guide](PerformanceGuide.md)
