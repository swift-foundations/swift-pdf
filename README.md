# swift-html-to-pdf

[![CI](https://github.com/coenttb/swift-html-to-pdf/workflows/CI/badge.svg)](https://github.com/coenttb/swift-html-to-pdf/actions/workflows/ci.yml)
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Convert HTML to PDF on Apple platforms using WKWebView. Processes 1,939 PDFs/sec continuous mode with 35 MB steady-state memory. Swift 6 strict concurrency with actor-based resource pooling.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
- [Performance](#performance)
- [Architecture](#architecture)
- [Monitoring](#monitoring)
- [Documentation](#documentation)
- [Testing](#testing)
- [Test Support](#test-support)
- [Platform Support](#platform-support)
- [Related Packages](#related-packages)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Overview

swift-html-to-pdf provides HTML to PDF conversion with actor-based resource pooling, streaming results, and Swift 6 strict concurrency. Built on WKWebView for native rendering quality and performance.

## Features

- Streaming PDF generation with AsyncStream for progressive results
- WebView resource pooling with automatic lifecycle management
- Swift 6 strict concurrency with Sendable guarantees
- Optional type-safe HTML DSL integration via swift-html
- Swift Metrics integration for production monitoring
- Performance: 1,939 PDFs/sec continuous mode, 677 PDFs/sec paginated mode
- Memory efficiency: 35 MB steady-state with 4-24 workers
- Support for both continuous and paginated rendering modes

## Installation

Add swift-html-to-pdf to your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-html-to-pdf.git", from: "1.0.0")
]
```

Add to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "HtmlToPdf", package: "swift-html-to-pdf")
    ]
)
```

### Optional: Type-Safe HTML DSL

To use the swift-html integration, enable the HTML trait:

```swift
dependencies: [
    .package(
        url: "https://github.com/coenttb/swift-html-to-pdf.git",
        from: "1.0.0",
        traits: ["HTML"]
    )
]
```

### Requirements

- Swift 6.2+
- macOS 13.0+ or iOS 16.0+
- Xcode 26.0+

**Note:** Swift 6.2 is required due to compiler bugs in Swift 6.0 and 6.1 that cause crashes during compilation (both in release mode and during macro expansion in debug mode). These issues are resolved in Swift 6.2.

## Quick Start

### HTML String to PDF

```swift
import HtmlToPdf
import Dependencies

@Dependency(\.pdf) var pdf

// Render to file
try await pdf.render(html: "<h1>Invoice #1234</h1>", to: fileURL)

// Render to data (in-memory)
let pdfData = try await pdf.render(html: "<h1>Receipt</h1>")

// Batch processing with streaming results
let html = invoices.map { "<html><body>\($0.html)</body></html>" }
for try await result in try await pdf.render(html: html, to: directory) {
    print("Generated \(result.url)")
}
```

### Type-Safe HTML (with HTML trait enabled)

```swift
import HtmlToPdf

struct Invoice: HTML {
    let number: Int
    let total: Decimal

    var body: some HTML {
        h1 { "Invoice #\(number)" }
        p { "Total: $\(total)" }
    }
}

@Dependency(\.pdf) var pdf
try await pdf.render(html: Invoice(number: 1234, total: 99.99), to: fileURL)
```

Or use inline HTML:

```swift
import HtmlToPdf

let invoice = HTMLDocument {
    h1 { "Invoice #1234" }
    p { "Total: $99.99" }
}

@Dependency(\.pdf) var pdf
try await pdf.render(html: invoice, to: fileURL)
```

## Usage Examples

### Streaming Results

Process PDFs as they are generated:

```swift
for try await result in try await pdf.render(html: html, to: directory) {
    // PDF is ready immediately
    try await uploadToS3(result.url)
    try await db.markComplete(result.index)
}
```

Benefits: lower latency, constant memory usage, real-time progress tracking.

### Configuration

Customize paper size, margins, pagination, and concurrency:

```swift
try await withDependencies {
    $0.pdf.render.configuration.paperSize = .letter
    $0.pdf.render.configuration.margins = .wide
    $0.pdf.render.configuration.paginationMode = .paginated
    $0.pdf.render.configuration.concurrency = .automatic
} operation: {
    try await pdf.render(html: html, to: fileURL)
}
```

Available options:
- Paper sizes: .a4, .letter, .legal, .a3, .a5, or custom CGSize
- Margins: .none, .minimal, .standard, .comfortable, .wide, or custom EdgeInsets
- Pagination: .continuous (fast), .paginated (print-ready), .automatic
- Concurrency: .automatic (1x CPU), .fixed(n), or specific count

See [Configuration Guide](Sources/HtmlToPdf/Documentation.docc/ConfigurationGuide.md) for details.

## Performance

### Benchmarks

Continuous mode (single-page, maximum speed):

| Batch Size | Throughput    | Avg Latency | Memory |
|------------|---------------|-------------|--------|
| 100        | 1,772/sec     | 0.56ms      | 146 MB |
| 1,000      | 1,939/sec     | 0.52ms      | 146 MB |
| 10,000     | 1,814/sec     | 0.55ms      | 148 MB |

Paginated mode (multi-page, print-ready):

| Batch Size | Throughput    | Avg Latency | Memory |
|------------|---------------|-------------|--------|
| 100        | 142/sec       | 7.05ms      | 102 MB |
| 1,000      | 677/sec       | 1.48ms      | 110 MB |
| 10,000     | 485/sec       | 2.06ms      | 137 MB |

Test environment: macOS 26.0, Apple Silicon M1 (8 cores), 24 GB RAM, Swift 6.2

### Memory Usage

Memory usage remains constant across concurrency levels:

| Concurrency | Steady-State | Peak  | Expected  |
|-------------|--------------|-------|-----------|
| 4 workers   | 34 MB        | 34 MB | 400 MB    |
| 8 workers   | 34 MB        | 35 MB | 800 MB    |
| 16 workers  | 35 MB        | 35 MB | 1,600 MB  |
| 24 workers  | 35 MB        | 35 MB | 2,400 MB  |

Shared WebKit infrastructure provides memory efficiency. Memory determined by pool overhead, not worker count.

Measured with 50+ PDF warmup and sustained rendering workload. See `WebViewMemoryTests.swift` for methodology.

## Architecture

### WebView Resource Pooling

- Pre-warmed WKWebView instances for immediate availability
- Automatic lifecycle management
- FIFO fairness under load
- Optimal concurrency: 1x CPU count (8 WebViews on 8-core Mac)
- Powered by [swift-resource-pool](https://github.com/coenttb/swift-resource-pool)

### Swift 6 Concurrency

- Full type safety in concurrent code
- Sendable guarantees throughout
- Actor-isolated state management
- No data races possible

## Monitoring

Export metrics to Prometheus, StatsD, or other systems via [swift-metrics](https://github.com/apple/swift-metrics):

```swift
import Metrics
import Prometheus

// Bootstrap once at startup
MetricsSystem.bootstrap(PrometheusMetricsFactory())

// Use library normally - metrics automatically collected
@Dependency(\.pdf) var pdf
try await pdf.render(html: invoices, to: directory)
```

Available metrics:
- `htmltopdf_pdfs_generated_total` - Counter
- `htmltopdf_pdfs_failed_total` - Counter (with reason dimension)
- `htmltopdf_render_duration_seconds` - Timer (with mode dimension; p50/p95/p99)
- `htmltopdf_pool_replacements_total` - Counter
- `htmltopdf_pool_utilization` - Gauge
- `htmltopdf_throughput_pdfs_per_sec` - Gauge

## Documentation

- [Getting Started Guide](Sources/HtmlToPdf/Documentation.docc/GettingStarted.md) - Installation, basic usage, first PDF
- [Performance Guide](Sources/HtmlToPdf/Documentation.docc/PerformanceGuide.md) - Optimization, benchmarks, tuning
- [Configuration Guide](Sources/HtmlToPdf/Documentation.docc/ConfigurationGuide.md) - All configuration options
- [API Documentation](https://coenttb.github.io/swift-html-to-pdf/) - Full DocC documentation

Generate docs locally:

```bash
swift package generate-documentation --open
```

## Testing

```bash
# All tests
swift test

# Performance benchmarks
swift test --filter PerformanceBenchmarks

# Memory analysis
swift test --filter WebViewMemoryTests

# Stress tests (10K-1M PDFs)
swift test --filter StressTests
```

## Test Support

The `PDFTestSupport` module provides test utilities for applications using swift-html-to-pdf:

```swift
dependencies: [
    .product(name: "PDFTestSupport", package: "swift-html-to-pdf")
]
```

Features:
- HTML test fixtures (minimal, simple, rich formatting, unicode)
- Temporary directory management with automatic cleanup
- Metrics testing backends
- PDF output verification helpers
- Platform-specific test renderers

Example usage:

```swift
import PDFTestSupport
import Testing

@Test func generateTestPDF() async throws {
    try await withTemporaryDirectory { dir in
        let html = TestHTML.richFormatting
        try await pdf.render(html: html, to: dir.appendingPathComponent("test.pdf"))
    }
}
```

See test files for additional examples.

## Platform Support

| Platform    | Status           | Notes                                      |
|-------------|------------------|--------------------------------------------|
| macOS       | Full support     | Optimal performance, 8 concurrent workers (8-core) |
| iOS         | Full support     | 8 concurrent workers, mobile-optimized     |
| Linux       | Planned          | Architecture ready, needs WebKit renderer  |
| Windows     | Possible         | Pending WebKit integration                 |

## Related Packages

### Dependencies

- [swift-html](https://github.com/coenttb/swift-html): The Swift library for domain-accurate and type-safe HTML & CSS.
- [swift-logging-extras](https://github.com/coenttb/swift-logging-extras): A Swift package for integrating swift-logging with swift-dependencies.
- [swift-resource-pool](https://github.com/coenttb/swift-resource-pool): A Swift package for actor-based resource pooling.

### Used By

- [swift-document-templates](https://github.com/coenttb/swift-document-templates): A Swift package for data-driven business document creation.

### Third-Party Dependencies

- [pointfreeco/swift-dependencies](https://github.com/pointfreeco/swift-dependencies): A dependency management library for controlling dependencies in Swift.
- [apple/swift-metrics](https://github.com/apple/swift-metrics): A Metrics API package for Swift.

## Contributing

Contributions welcome. Please:

1. Add tests - 95%+ coverage maintained
2. Follow conventions - Swift 6, strict concurrency, no force-unwraps
3. Update docs - DocC comments and README updates

Areas for contribution:
- Linux support (implement WebKit renderer)
- Performance improvements
- Documentation and examples
- Bug reports with reproduction steps

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.

## Acknowledgments

- Point-Free for swift-dependencies and HTML DSL foundations
- Apple for WKWebView and Swift 6
- The Swift Community for feedback and contributions
