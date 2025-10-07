# swift-html-to-pdf

[![CI](https://github.com/coenttb/swift-html-to-pdf/actions/workflows/ci.yml/badge.svg)](https://github.com/coenttb/swift-html-to-pdf/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20iOS-blue.svg)](https://github.com/coenttb/swift-html-to-pdf)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

**The fastest HTML to PDF library for Swift**

⚡ **1,939 PDFs/sec** • 💾 **35 MB memory (4-24 workers)** • 🎯 **Type-safe** • 🧪 **Swift 6**

---

## Why

Every other solution makes you choose: **fast** *or* **safe** *or* **easy**.

This library gives you all three.

```swift
@Dependency(\.pdf) var pdf
try await pdf.render(html: "<h1>Invoice #1234</h1>", to: fileURL)
```

**One line. Zero configuration. Production-ready.**

---

## The Numbers

### Performance

**Continuous Mode** (single-page, maximum speed):

| Batch Size | Throughput      | Avg Latency | Memory |
|------------|-----------------|-------------|--------|
| 100        | 1,772/sec       | 0.56ms      | 146 MB |
| 1,000      | **1,939/sec**   | 0.52ms      | 146 MB |
| 10,000     | 1,814/sec       | 0.55ms      | 148 MB |

**Paginated Mode** (multi-page, print-ready):

| Batch Size | Throughput      | Avg Latency | Memory |
|------------|-----------------|-------------|--------|
| 100        | 142/sec         | 7.05ms      | 102 MB |
| 1,000      | **677/sec**     | 1.48ms      | 110 MB |
| 10,000     | 485/sec         | 2.06ms      | 137 MB |

*Test environment: macOS 26.0, Apple Silicon M1 (8 cores), 24 GB RAM, Swift 6.2*

### Memory Efficiency

Memory usage **doesn't scale** with concurrency:

| Concurrency | Steady-State | Peak  | Expected  |
|-------------|--------------|-------|-----------|
| 4 workers   | 34 MB        | 34 MB | 400 MB    |
| 8 workers   | 34 MB        | 35 MB | 800 MB    |
| 16 workers  | 35 MB        | 35 MB | 1,600 MB  |
| 24 workers  | 35 MB        | 35 MB | 2,400 MB  |

**Why?** Shared WebKit infrastructure. Memory determined by pool overhead, not worker count.

*Measured empirically with 50+ PDF warmup, sustained rendering workload. See `WebViewMemoryTests.swift` for methodology.*

**Memory stays constant during extended batches:**
- 500 PDFs with 8 concurrent: Peak 98 MB, range 74 MB (includes startup), steady-state variance <5 MB
- No leaks. No accumulation. Constant memory regardless of batch size.

---

## Quick Start

### HTML String → PDF

```swift
import HtmlToPdf
import Dependencies

@Dependency(\.pdf) var pdf

// To file
try await pdf.render(html: "<h1>Invoice #1234</h1>", to: fileURL)

// To data (in-memory)
let pdfData = try await pdf.render(html: "<h1>Receipt</h1>")

// Batch processing
let html = invoices.map { "<html><body>\($0.html)</body></html>" }
for try await result in try await pdf.render(html: html, to: directory) {
    print("Generated \(result.url)")
}
```

**That's it.** No setup. No configuration.

### Type-Safe HTML (Optional)

For compile-time safety, enable the HTML trait to use [swift-html](https://github.com/coenttb/swift-html):

**Package.swift:**
```swift
dependencies: [
    .package(
        url: "https://github.com/coenttb/swift-html-to-pdf.git",
        from: "1.0.0",
        traits: ["HTML"]  // ← Enable HTML trait
    )
]
```

**Usage:**
```swift
import HtmlToPdf

struct Invoice: HTMLDocument {
    let number: Int
    let total: Decimal

    var head: some HTML {
        title { "Invoice #\(number)" }
    }

    var body: some HTML {
        h1 { "Invoice #\(number)" }
        p { "Total: $\(total)" }
    }
}

@Dependency(\.pdf) var pdf
try await pdf.render(html: Invoice(number: 1234, total: 99.99), to: fileURL)
```

**Invalid HTML?** Won't compile. **Type safety** all the way down.

---

## Why It's Different

### 1. Streaming Results

Process PDFs as they're generated. Don't wait for the batch to finish.

```swift
for try await result in try await pdf.render(html: html, to: directory) {
    // This PDF is ready NOW
    try await uploadToS3(result.url)        // Upload immediately
    try await db.markComplete(result.index) // Update database
}
```

**Benefits:** Lower latency, constant memory, real-time progress.

### 2. WebView Resource Pooling

- Pre-warmed WKWebView instances (instant availability)
- Automatic lifecycle management
- FIFO fairness under load
- Optimal concurrency: 1x CPU count (8 WebViews on 8-core Mac)
- Powered by [swift-resource-pool](https://github.com/coenttb/swift-resource-pool)

### 3. Swift 6 Strict Concurrency

- Full type safety in concurrent code
- Sendable guarantees throughout
- Actor-isolated state management
- No data races possible

---

## Installation

### Swift Package Manager

Add to your `Package.swift`:

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

**Optional: Enable type-safe HTML DSL**

To use the [swift-html](https://github.com/coenttb/swift-html) integration, enable the HTML trait:

```swift
dependencies: [
    .package(
        url: "https://github.com/coenttb/swift-html-to-pdf.git",
        from: "1.0.0",
        traits: ["HTML"]  // ← Enable HTML trait
    )
]
```

### Requirements

- **Swift 6.0+**
- **macOS 14.0+** or **iOS 17.0+**
- **Xcode 16.0+**

---

## Configuration

Need to customize? Full configuration available:

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

**Common configurations:**

- **Paper sizes:** `.a4`, `.letter`, `.legal`, `.a3`, `.a5`, or custom `CGSize`
- **Margins:** `.none`, `.minimal`, `.standard`, `.comfortable`, `.wide`, or custom `EdgeInsets`
- **Pagination:** `.continuous` (fast), `.paginated` (print-ready), `.automatic`
- **Concurrency:** `.automatic` (1x CPU), `.fixed(n)`, or specific count

See [Configuration Guide](Sources/HtmlToPdf/Documentation.docc/ConfigurationGuide.md) for all options.

---

## Production Metrics

Export metrics to Prometheus, StatsD, or other monitoring systems via [swift-metrics](https://github.com/apple/swift-metrics):

```swift
import Metrics
import Prometheus

// Bootstrap once at startup
MetricsSystem.bootstrap(PrometheusMetricsFactory())

// Use library normally - metrics automatically collected
@Dependency(\.pdf) var pdf
try await pdf.render(html: invoices, to: directory)
```

**Available Metrics:**

- `htmltopdf_pdfs_generated_total` - Counter
- `htmltopdf_pdfs_failed_total` - Counter (with `reason` dimension)
- `htmltopdf_render_duration_seconds` - Timer (with `mode` dimension; p50/p95/p99)
- `htmltopdf_pool_replacements_total` - Counter
- `htmltopdf_pool_utilization` - Gauge
- `htmltopdf_throughput_pdfs_per_sec` - Gauge

---

## Documentation

- **[Getting Started Guide](Sources/HtmlToPdf/Documentation.docc/GettingStarted.md)** - Installation, basic usage, first PDF
- **[Performance Guide](Sources/HtmlToPdf/Documentation.docc/PerformanceGuide.md)** - Optimization, benchmarks, tuning
- **[Configuration Guide](Sources/HtmlToPdf/Documentation.docc/ConfigurationGuide.md)** - All configuration options
- **[API Documentation](https://coenttb.github.io/swift-html-to-pdf/)** - Full DocC documentation

Generate docs locally:

```bash
swift package generate-documentation --open
```

---

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

---

## Platform Support

| Platform    | Status           | Notes                                      |
|-------------|------------------|--------------------------------------------|
| **macOS**   | ✅ Full support  | Optimal performance, 8 concurrent workers (8-core) |
| **iOS**     | ✅ Full support  | 8 concurrent workers, mobile-optimized     |
| **Linux**   | 🚧 Coming soon   | Architecture ready, needs WebKit renderer  |
| **Windows** | 🚧 Possible      | Pending WebKit integration                 |

---

## Contributing

Contributions welcome! Please:

1. **Add tests** - We have 95%+ coverage
2. **Follow conventions** - Swift 6, strict concurrency, no force-unwraps
3. **Update docs** - DocC comments + README updates

**Areas for contribution:**
- Linux support (implement WebKit renderer)
- Performance improvements
- Documentation and examples
- Bug reports with reproduction steps

---

## Related Projects

Part of the [coenttb Swift ecosystem](https://github.com/coenttb), and optionally integrates with [swift-html](https://github.com/coenttb/swift-html) - Type-safe HTML & CSS DSL.

Built on [Point-Free](https://www.pointfree.co)'s [swift-dependencies](https://github.com/pointfreeco/swift-dependencies), and integrates with [swift-metrics](https://github.com/apple/swift-metrics). 
---

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- **Point-Free** for swift-dependencies and HTML DSL foundations
- **Apple** for WKWebView and Swift 6
- **The Swift Community** for feedback and contributions

---

**Questions?**

- **Issues:** [GitHub Issues](https://github.com/coenttb/swift-html-to-pdf/issues)
- **Discussions:** [GitHub Discussions](https://github.com/coenttb/swift-html-to-pdf/discussions)
- **Email:** [coen@coenttb.com](mailto:coen@coenttb.com)

---

**Made with ❤️ by [Coen ten Thije Boonkkamp](https://coenttb.com)**

⚡ **Fast** • 💾 **Efficient** • 🎯 **Type-Safe** • 🧪 **Production-Ready**
