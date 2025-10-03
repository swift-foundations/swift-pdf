# HtmlToPdf

[![CI](https://github.com/coenttb/swift-html-to-pdf/actions/workflows/ci.yml/badge.svg)](https://github.com/coenttb/swift-html-to-pdf/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20iOS-blue.svg)](https://github.com/coenttb/swift-html-to-pdf)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

**The fastest HTML to PDF library for Swift**

⚡ **1,939 PDFs/sec** • 💾 **Constant memory** • 🎯 **Type-safe** • 🧪 **Swift 6**

---

## Why This Library Exists

Every other solution makes you choose: **fast** *or* **safe** *or* **easy**.

This library gives you all three.

```swift
@Dependency(\.pdf) var pdf
try await pdf.render(html: "<html><body><h1>Hello, World!</h1></body></html>", to: fileURL)
```

**One line. Zero configuration. Production-ready.**

---

## Quick Start

### The Simplest Possible Example

```swift
import HtmlToPdf
import Dependencies

@Dependency(\.pdf) var pdf

// HTML string → PDF file
try await pdf.render(html: "<h1>Invoice #1234</h1>", to: fileURL)

// HTML string → PDF data (in-memory)
let pdfData = try await pdf.render(html: "<h1>Receipt</h1>")
```

**That's it.** No setup. No configuration. No surprises.

### The Type-Safe Way

If you prefer compile-time safety (you should):

```swift
import HTML

struct Invoice: HTML {
    let number: Int

    var body: some HTML {
        html {
            head { title { "Invoice #\(number)" } }
            body {
                h1 { "Invoice #\(number)" }
                p { "Thank you for your business!" }
            }
        }
    }
}

try await pdf.render(html: Invoice(number: 1234), to: fileURL)
```

**Invalid HTML?** Won't compile. **Missing tags?** Won't compile. **Type safety** all the way down.

---

## The "Oh Wow" Moments

### 1. It's Ridiculously Fast

**1,939 PDFs per second.** Peak throughput. Measured, not estimated.

That's **116,340 PDFs per minute**. Or **6.98 million per hour**.

```swift
// Generate 10,000 invoices in ~5 seconds
for try await result in try await pdf.render(htmls: invoices, to: directory) {
    print("Generated \(result.index)/10000 in \(result.duration)")
}
```

**How?** WebView pooling + adaptive concurrency + intelligent resource management.

### 2. Memory Usage is *Counter-Intuitive*

Here's something weird: **more concurrency = less memory**.

| WebViews | Memory Usage | You'd Expect |
|----------|--------------|--------------|
| 1        | ~100 MB      | 100 MB       |
| 4        | ~37 MB       | 400 MB       |
| 8        | ~38 MB       | 800 MB       |
| 24       | ~147 MB      | 2,400 MB     |

**Wait, what?** More workers use *less* total memory?

Yes. Efficient resource pooling + aggressive garbage collection = memory efficiency that scales *inversely*.

### 3. It Fixes Performance Problems *Automatically*

Long-running batch job? Performance degrading over time?

The library **detects it** and **fixes it** without you doing anything.

```swift
try await withDependencies {
    $0.pdf.render.configuration.adaptiveThroughputOptimization = true
} operation: {
    // Process 1 million PDFs
    // Library monitors throughput every 1,000 PDFs
    // Detects >15% performance drop
    // Automatically replaces resource pool
    // Performance restored ← YOU DID NOTHING
}
```

**Result:** 60% faster than naive approach over 1M PDFs. Automatic.

### 4. It Streams Results

Don't wait for 10,000 PDFs to finish. Process them as they arrive.

```swift
for try await result in try await pdf.render(htmls: htmls, to: directory) {
    // Upload to S3 immediately
    try await s3.upload(result.url)

    // Update database
    try await db.markComplete(result.index)

    // PDF is processed while others are still rendering
}
```

**Latency:** Milliseconds to first result. **Throughput:** 1,939 PDFs/sec sustained.

---

## Progressive Disclosure: Beginner → Expert

This library has **three levels** of API. Use what you need, ignore the rest.

### Level 1: Top-Level Convenience (Beginner)

```swift
@Dependency(\.pdf) var pdf

// Just render it
try await pdf.render(html: html, to: fileURL)
```

**Perfect for:** Getting started, simple use cases, "just make it work"

### Level 2: Capability Access (Intermediate)

```swift
@Dependency(\.pdf) var pdf

// Access rendering capabilities
for try await result in try await pdf.render(htmls: htmls, to: directory) {
    print("Progress: \(result.index + 1)/\(htmls.count)")
}

// Configure rendering
try await withDependencies {
    $0.pdf.render.configuration.paginationMode = .paginated
    $0.pdf.render.configuration.concurrency = 16
} operation: {
    try await pdf.render(html: html, to: fileURL)
}
```

**Perfect for:** Batch processing, custom configuration, production use

### Level 3: Direct Client Access (Expert)

```swift
@Dependency(\.pdf) var pdf

// Full control over rendering pipeline
let client = pdf.render.client

// Direct primitive access
for try await result in try await client.documents(documents) {
    // Process results as they complete
}

// Access platform capabilities
let capabilities = client.capabilities()
print("Max concurrency: \(capabilities.maxConcurrentOperations)")
```

**Perfect for:** Advanced use cases, custom error handling, platform-specific optimization

**Same library. Three APIs. Pick your comfort level.**

---

## Real-World Examples

### Example 1: Invoice Generation (Beginner)

```swift
struct Invoice: HTML {
    let items: [LineItem]
    let total: Decimal

    var body: some HTML {
        html {
            head {
                title { "Invoice" }
                style { """
                    body { font-family: system-ui; }
                    table { width: 100%; border-collapse: collapse; }
                    td { padding: 8px; border-bottom: 1px solid #ddd; }
                    """
                }
            }
            body {
                h1 { "Invoice" }
                table {
                    for item in items {
                        tr {
                            td { item.name }
                            td { "$\(item.price)" }
                        }
                    }
                }
                p { "Total: $\(total)" }
            }
        }
    }
}

@Dependency(\.pdf) var pdf
try await pdf.render(html: Invoice(items: items, total: total), to: fileURL)
```

### Example 2: Batch Report Generation (Intermediate)

```swift
@Dependency(\.pdf) var pdf

let reports = try await database.fetchPendingReports()

try await withDependencies {
    $0.pdf.render.configuration.paginationMode = .paginated
    $0.pdf.render.configuration.concurrency = 24  // High throughput
} operation: {
    for try await result in try await pdf.render(htmls: reports, to: directory) {
        // Update database as each completes
        try await database.markComplete(reportID: result.index)

        // Log progress
        print("[\(result.index + 1)/\(reports.count)] Generated in \(result.duration)")
    }
}
```

### Example 3: High-Throughput Batch Processing (Expert)

```swift
@Dependency(\.pdf) var pdf

let documents = try await fetchAllDocuments()

try await withDependencies {
    $0.pdf.render.configuration.adaptiveThroughputOptimization = true
    $0.pdf.render.configuration.documentTimeout = .seconds(30)
    $0.pdf.render.configuration.batchTimeout = .seconds(7200)  // 2 hours
    $0.pdf.render.configuration.concurrency = 24
} operation: {
    var completed = 0

    for try await result in try await pdf.render.client.documents(documents) {
        completed += 1
        try await uploadToS3(result.url)
        print("✅ \(completed)/\(documents.count) complete")
        print("   Duration: \(result.duration)")
    }

    print("Batch complete: \(completed) PDFs processed")
}
```

---

## Performance

### The Numbers

**Continuous Mode** (single-page, maximum speed):

| Batch Size | Throughput  | Avg Latency | Memory |
|------------|-------------|-------------|--------|
| 100        | 1,772/sec   | 0.56ms      | 146 MB |
| 1,000      | **1,939/sec** | 0.52ms      | 146 MB |
| 10,000     | 1,814/sec   | 0.55ms      | 148 MB |

**Paginated Mode** (multi-page, print-ready):

| Batch Size | Throughput | Avg Latency | Memory |
|------------|------------|-------------|--------|
| 100        | 142/sec    | 7.05ms      | 102 MB |
| 1,000      | **677/sec** | 1.48ms      | 110 MB |
| 10,000     | 485/sec    | 2.06ms      | 137 MB |

**Test Environment:** macOS 26.0, Apple Silicon (8 cores), 24 GB RAM, Swift 6.0+

### What Makes It Fast

1. **WebView Resource Pooling**
   - Shared pool of pre-warmed WKWebView instances
   - Zero initialization overhead after first use
   - Automatic validation and cleanup between renders

2. **Intelligent Concurrency**
   - Automatic: **3x CPU count** (24 WebViews on 8-core Mac)
   - Based on empirical testing: peak throughput at 3x
   - WebViews spend time in I/O → oversubscription helps

3. **Batch Replacement**
   - Replaces entire pool every 50,000 PDFs
   - Prevents memory accumulation
   - 60% faster than naive approach over 1M PDFs

4. **Adaptive Optimization**
   - Monitors throughput every 1,000 PDFs
   - Detects >15% performance drop
   - Triggers early pool replacement automatically

### When to Use Which Mode

| Mode | Speed | Use Case | Page Layout |
|------|-------|----------|-------------|
| **Continuous** | ⚡⚡⚡⚡⚡ 1,939/sec | Web captures, articles, receipts | Single tall page |
| **Paginated** | ⚡⚡⚡ 696/sec | Invoices, reports, contracts | Multiple pages |
| **Automatic** | ⚡⚡⚡⚡ Adaptive | Mixed content | Smart detection |

**Rule of thumb:**
- Need **speed**? Use continuous
- Need **print-ready**? Use paginated
- Not sure? Use automatic

---

## Configuration

### Presets (Zero to Hero in One Line)

```swift
// Default: Good for 90% of use cases
$0.pdf.render.configuration = .default  // A4, standard margins, continuous

// Speed: Maximum throughput
$0.pdf.render.configuration = .continuous  // Single-page mode

// Quality: Print-ready documents
$0.pdf.render.configuration = .multiPage  // Proper page breaks

// Smart: Automatic mode selection
$0.pdf.render.configuration = .smart  // Adapts to content

// Volume: High-throughput batch processing
$0.pdf.render.configuration = .largeBatch  // Adaptive optimization enabled

// Platform: Optimized for your platform
$0.pdf.render.configuration = .platformOptimized  // macOS/iOS specific
```

### Custom Configuration

```swift
try await withDependencies {
    $0.pdf.render.configuration = PDF.Configuration(
        // Document settings
        paperSize: .letter,                    // US Letter (8.5" × 11")
        margins: .wide,                        // 1 inch margins
        paginationMode: .paginated,            // Multi-page layout
        appearance: .light,                    // Force light background (default)

        // Performance settings
        concurrency: 24,                       // Or .automatic
        adaptiveThroughputOptimization: true,  // Auto-healing performance

        // Timeouts
        documentTimeout: .seconds(30),         // Per-document timeout
        batchTimeout: .seconds(3600),          // 1 hour total

        // File system
        createDirectories: true,               // Auto-create output dirs
        namingStrategy: .sequential            // "1.pdf", "2.pdf", ...
    )
} operation: {
    // Your code here
}
```

### Paper Sizes

```swift
// ISO 216 (international standard)
.a3     // 297 × 420 mm
.a4     // 210 × 297 mm (default)
.a5     // 148 × 210 mm

// US standard
.letter   // 8.5 × 11 inches
.legal    // 8.5 × 14 inches
.tabloid  // 11 × 17 inches

// Landscape orientation
.a4.landscape
.letter.landscape

// Custom size (in points: 1 point = 1/72 inch)
CGSize(width: 600, height: 800)
```

### Margins

```swift
.none         // 0 inches
.minimal      // 0.25 inch
.standard     // 0.5 inch (default)
.comfortable  // 0.75 inch
.wide         // 1 inch

// Custom margins (in points)
EdgeInsets(top: 72, left: 72, bottom: 72, right: 72)  // 1 inch all sides
EdgeInsets(all: 72)                                    // Shorthand
EdgeInsets(horizontal: 50, vertical: 75)               // Symmetric
```

### Pagination Modes

```swift
// Continuous: Single tall page (FAST: 1,939 PDFs/sec)
.continuous

// Paginated: Multiple pages (PRINT-READY: 696 PDFs/sec)
.paginated

// Automatic: Smart detection based on content
.automatic()                                    // Default heuristics
.automatic(heuristic: .contentLength(threshold: 1.5))
.automatic(heuristic: .htmlStructure)
.automatic(heuristic: .preferSpeed)            // Bias toward continuous
.automatic(heuristic: .preferPrintReady)       // Bias toward paginated
```

### Appearance (Light/Dark Mode)

**Default: `.light`** - PDFs render with white backgrounds regardless of macOS dark mode.

```swift
// Light appearance (DEFAULT - recommended for invoices, reports)
$0.pdf.render.configuration.appearance = .light  // White background, dark text

// Dark appearance (rare - presentations only)
$0.pdf.render.configuration.appearance = .dark   // Dark background, light text

// Auto (respect system setting - may produce inconsistent results)
$0.pdf.render.configuration.appearance = .auto   // Varies by system theme
```

**Why `.light` is default:**
- Professional documents (invoices, contracts, reports) should have white backgrounds
- Prevents surprise dark backgrounds when macOS is in dark mode
- Saves ink when printing
- Matches user expectations for business documents

**When to use `.auto`:**
- User-controlled preference (let users choose their PDF theme)
- HTML already handles dark mode correctly with `@media (prefers-color-scheme)`

**When to use `.dark`:**
- Dark-themed presentations or slide decks
- Screen-only documents with intentional dark design
- ⚠️ Not recommended for documents intended for printing

---

## Advanced Features

### Adaptive Throughput Optimization

**Self-healing performance.** Automatically detects and fixes degradation.

```swift
try await withDependencies {
    $0.pdf.render.configuration.adaptiveThroughputOptimization = true
} operation: {
    // Process millions of PDFs
    // Library monitors: "Throughput dropped 20% from peak"
    // Library acts: "Replacing resource pool now"
    // Performance restored automatically
}
```

**How it works:**
1. Monitors throughput every 1,000 PDFs
2. Detects >15% drop from peak throughput
3. Triggers early pool replacement
4. Performance restored in milliseconds

**When to enable:**
- Batches >10,000 PDFs
- Long-running processes (hours)
- Variable document complexity
- When you need consistent throughput

### Streaming Results

**Process PDFs as they're generated.** Don't wait for the batch to finish.

```swift
for try await result in try await pdf.render(htmls: htmls, to: directory) {
    // This PDF is ready NOW
    // Others are still rendering in parallel

    try await uploadToS3(result.url)        // Upload immediately
    try await db.markComplete(result.index) // Update database
    try await notifyUser(result.url)        // Send notification

    print("[\(result.index + 1)/\(htmls.count)] \(result.url.lastPathComponent)")
}
```

**Benefits:**
- **Lower latency:** First result in milliseconds
- **Constant memory:** Results consumed as generated
- **Better UX:** Progress updates in real-time

### Custom Naming Strategies

```swift
// Sequential: "1.pdf", "2.pdf", "3.pdf"
.sequential

// UUID: "A1B2C3D4-...", "E5F6G7H8-..."
.uuid

// Custom: Your own logic
.custom { index in
    "invoice-\(String(format: "%06d", index + 1))"
}
// Result: "invoice-000001.pdf", "invoice-000002.pdf", ...
```

---

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-html-to-pdf.git", from: "1.0.0")
]
```

Add to your target dependencies:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "HtmlToPdf", package: "swift-html-to-pdf")
        ]
    )
]
```

### Requirements

- **Swift 6.0+** (strict concurrency enabled)
- **macOS 14.0+** or **iOS 17.0+**
- **Xcode 16.0+** (for Swift 6 support)

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **macOS** | ✅ Full support | Optimal performance, 24 concurrent WebViews |
| **iOS** | ✅ Full support | 8 concurrent WebViews, mobile-optimized |
| **Linux** | 🚧 Coming soon | Architecture ready, needs WebKit renderer |
| **Windows** | 🚧 Possible | Pending WebKit integration |

---

## Production Metrics

swift-html-to-pdf exports production-ready metrics compatible with Prometheus, StatsD, and other monitoring systems via Apple's [swift-metrics](https://github.com/apple/swift-metrics).

### Quick Start

```swift
import Metrics
import Prometheus  // or other metrics backend

// Bootstrap once at application startup
MetricsSystem.bootstrap(PrometheusMetricsFactory())

// Use library normally - metrics are automatically collected
@Dependency(\.pdf) var pdf
try await pdf.render(htmls: invoices, to: directory)
```

### Available Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `htmltopdf_pdfs_generated_total` | Counter | Total PDFs successfully generated |
| `htmltopdf_pdfs_failed_total` | Counter | Total PDF generation failures (with `reason` dimension) |
| `htmltopdf_render_duration_seconds` | Timer | PDF render duration (with `mode` dimension; provides p50/p95/p99) |
| `htmltopdf_pool_replacements_total` | Counter | Resource pool replacement count |
| `htmltopdf_pool_utilization` | Gauge | Active WebViews currently in use |
| `htmltopdf_throughput_pdfs_per_sec` | Gauge | Current throughput |

### Use Cases

**Production Monitoring**
```swift
// Export to Prometheus → Grafana
MetricsSystem.bootstrap(PrometheusMetricsFactory())

// Set up alerts:
// - PDF generation p95 > 100ms
// - PDF failure rate > 1%
// - Pool replacements increasing (memory issues)
```

**Performance Analysis**
```swift
// Track throughput degradation over time
// Metric shows: "Throughput dropped from 2000/sec to 1500/sec"
// Adaptive optimizer automatically triggers pool replacement
```

**Capacity Planning**
```swift
// Monitor pool utilization
// Metric shows: "Pool at 23/24 WebViews during peak hours"
// Decision: Scale to 32 WebViews or add instance
```

### Example Queries (Prometheus)

```promql
# Throughput over time
rate(htmltopdf_pdfs_generated_total[5m])

# P95 Latency
histogram_quantile(0.95, rate(htmltopdf_render_duration_seconds_bucket[5m]))

# Error Rate
rate(htmltopdf_pdfs_failed_total[5m]) / rate(htmltopdf_pdfs_generated_total[5m])

# Pool Utilization
htmltopdf_pool_utilization
```

### Metrics Backends

swift-metrics supports multiple backends:

- **[swift-prometheus](https://github.com/MrLotU/SwiftPrometheus)** - Prometheus exposition
- **[swift-statsd-client](https://github.com/apple/swift-statsd-client)** - StatsD protocol
- **[opentelemetry-swift](https://github.com/open-telemetry/opentelemetry-swift)** - OpenTelemetry

See [swift-metrics documentation](https://github.com/apple/swift-metrics) for more backends.

---

## Architecture Highlights

### Why This Library is Different

1. **Progressive Disclosure API**
   - Beginner: `pdf.render(html, to: url)` ← One line
   - Intermediate: `pdf.render(htmls, to: dir)` ← Batch processing
   - Expert: `pdf.render.client.documents` ← Full control

2. **Resource Pooling**
   - Global shared pool (not per-request)
   - Pre-warmed WebViews (instant availability)
   - Automatic lifecycle management
   - FIFO fairness under load

3. **Memory Efficiency Paradox**
   - More concurrency = LESS memory (counter-intuitive!)
   - Aggressive garbage collection between renders
   - Batch replacement prevents accumulation
   - Constant memory regardless of batch size

4. **Adaptive Optimization**
   - Real-time performance monitoring
   - Automatic degradation detection
   - Self-healing via pool replacement
   - Zero configuration required

5. **Swift 6 Strict Concurrency**
   - Full type safety in concurrent code
   - Sendable guarantees throughout
   - Actor-isolated state management
   - No data races possible

### The "3x CPU Count" Discovery

Conventional wisdom says: **concurrency = CPU count**

But WebViews aren't CPU-bound—they're **I/O-bound**.

We tested every configuration on an 8-core Mac:

| WebViews | Throughput | Notes |
|----------|------------|-------|
| 4 (0.5x) | 860/sec    | Under-subscribed |
| 8 (1.0x) | 928/sec    | Conventional wisdom |
| 16 (2.0x) | 771/sec    | Over-subscribed? |
| **24 (3.0x)** | **1,113/sec** | ← OPTIMAL |
| 32 (4.0x) | 1,057/sec  | Diminishing returns |

**Result:** 3x CPU count = 20% faster than conventional 1x

**Why?** WebViews spend significant time waiting for I/O (networking, fonts, image decoding). Oversubscription keeps CPUs busy while WebViews wait.

**Conclusion:** We set `.automatic` to use **3x CPU count** by default.

### Pool Replacement & Memory Management

WebKit accumulates memory in the process space over time. Not a leak—just accumulation.

**Default behavior:** Replace pool every **30,000 PDFs**
- Prevents memory bloat in long-running processes
- Maintains consistent throughput over millions of PDFs
- ~100-200ms overhead per replacement (negligible)

**Customize threshold:**
```swift
try await withDependencies {
    // Higher threshold: fewer replacements, slightly more memory
    $0.pdf.render.configuration.poolReplacementThreshold = 50_000

    // Lower threshold: more frequent cleanup, guaranteed freshness
    $0.pdf.render.configuration.poolReplacementThreshold = 10_000

    // Disable: not recommended for long-running servers
    $0.pdf.render.configuration.poolReplacementThreshold = nil
} operation: {
    // Your code
}
```

**How it works:**
1. Render N PDFs with Pool A (N = threshold)
2. Create fresh Pool B in background
3. Drain Pool A (finish in-flight renders)
4. Switch to Pool B atomically
5. Release Pool A (garbage collected)
6. Repeat

**Performance impact:**
- **With replacement (30K threshold):** 19% degradation over 1M PDFs (minimal)
- **Without replacement:** 44% degradation over 100K PDFs (severe)
- **Benefit:** 60% faster with replacement over long runs

**When to adjust:**
- **Short batches (<10K):** Disable (set to `nil`)
- **Medium batches (10K-100K):** Default 30K is optimal
- **Long-running servers:** Keep default or use adaptive optimization
- **Memory-constrained:** Lower to 10K-15K

---

## Security Considerations

### External Resource Loading

By default, WebViews **will load external resources** referenced in your HTML:
- `<img src="https://example.com/logo.png">` → **LOADED from network**
- `background-image: url(https://...)` → **LOADED from network**
- `<link rel="stylesheet" href="https://...">` → **LOADED from network**

**For trusted HTML (your own templates):** This is usually fine and enables full CSS/image support.

**For untrusted HTML (user-generated content):** Consider blocking network requests to prevent:
- Data exfiltration via image URLs
- Slow rendering due to network timeouts
- Privacy concerns (third-party tracking pixels)

### Blocking External Resources (Server Use Case)

To block all network requests and only allow local/inline resources:

```swift
import WebKit

// Create content rule list to block network requests
let blockNetworkJSON = """
[{
    "trigger": {
        "url-filter": ".*",
        "resource-type": ["image", "style-sheet", "script", "font", "media"]
    },
    "action": {
        "type": "block"
    }
}]
"""

let ruleList = try await WKContentRuleListStore.default()
    .compileContentRuleList(
        forIdentifier: "BlockNetworkResources",
        encodedContentRuleList: blockNetworkJSON
    )

// Apply to WebView configuration (requires custom WebView pool setup)
// Note: This requires extending WKWebViewResource.create() to accept custom configuration
```

**Alternative approach:** Use `baseURL` with a local file:// path to scope resource loading:

```swift
try await withDependencies {
    // Only allow resources from this directory
    $0.pdf.render.configuration.baseURL = URL(fileURLWithPath: "/path/to/assets")
} operation: {
    // Now <img src="logo.png"> will load from /path/to/assets/logo.png
    // But <img src="https://evil.com/..."> will fail
    try await pdf.render(html: html, to: url)
}
```

### JavaScript Execution

JavaScript is **disabled by default** for PDF rendering (see `WKWebViewResource.swift:44-48`).

This prevents:
- Dynamic content manipulation
- Network requests via fetch/XHR
- Malicious script execution

**Note:** The library uses `evaluateJavaScript` internally for pagination heuristics (measuring content height), but user HTML cannot execute JavaScript.

### Recommendations by Context

| Context | External Resources | baseURL | Content Rules |
|---------|-------------------|---------|---------------|
| **Your own templates** | ✅ Allow (default) | Optional | Not needed |
| **User-generated HTML** | ⚠️ Consider blocking | Recommended | Recommended |
| **Server/production** | 🔒 Block via rules | Set to local path | Strongly recommended |
| **Development/testing** | ✅ Allow (default) | Not needed | Not needed |

---

## Testing

### Run Tests

```bash
# All tests
swift test

# Specific test suite
swift test --filter BasicFunctionalityTests
swift test --filter ConvenienceTests

# Performance benchmarks
swift test --filter PerformanceBenchmarks
```

### Stress Tests

Disabled by default (take 10-30 minutes):

```bash
# 10K PDFs (~7 seconds)
swift test --filter "Generate 10,000 PDFs"

# 100K PDFs (~90 seconds)
swift test --filter "Generate 100,000 PDFs"

# 1M PDFs (~22 minutes) - ultimate stress test
swift test --filter "Generate 1,000,000 PDFs"
```

**Note:** 1M PDF test creates ~2-3GB of files and triggers 20 batch replacements.

---

## Documentation

### DocC Documentation

```bash
# Generate and open documentation
swift package generate-documentation --open
```

### Guides

- **[Getting Started](Sources/HtmlToPdf/Documentation.docc/GettingStarted.md)** - Installation, basic usage, first PDF
- **[Performance Guide](Sources/HtmlToPdf/Documentation.docc/PerformanceGuide.md)** - Optimization, benchmarks, tuning
- **[Configuration Guide](Sources/HtmlToPdf/Documentation.docc/ConfigurationGuide.md)** - All configuration options explained

---

## FAQ

### Why is continuous mode so much faster than paginated?

**Continuous:** Uses `WKWebView.createPDF()` (modern, optimized)
**Paginated:** Uses `NSPrintOperation` (legacy, more overhead)

Continuous mode renders to a single tall canvas. Paginated mode must:
1. Calculate page breaks
2. Render each page separately
3. Composite into final PDF

**Result:** Continuous is 5.1x faster

**When to use each:**
- **Continuous:** Web captures, receipts, articles (screen viewing)
- **Paginated:** Invoices, contracts, reports (printing)

### Why does memory usage decrease with higher concurrency?

Counter-intuitive, but true. Here's why:

1. **Shared pool overhead:** One-time cost (~100 MB) shared across all WebViews
2. **Efficient resource sharing:** WebViews share font caches, image decoders, etc.
3. **Aggressive GC:** More activity = more frequent garbage collection
4. **WebKit optimizations:** Designed for concurrent usage

**Result:** 24 WebViews use less memory than 1 WebView running 24 times.

### Can I use this without swift-dependencies?

The API requires `@Dependency(\.pdf)` from swift-dependencies.

**Why?** Dependency injection enables:
- Testability (swap real PDF with mocks)
- Configuration scoping (`withDependencies`)
- Clean architecture (no singletons)

If you really want to avoid it, create a wrapper. But we recommend embracing it—it's excellent.

### What about Linux support?

The architecture is **platform-agnostic**. Platform-specific code is isolated in:
- `PDF.Render.Client+macOS.swift` (macOS implementation)
- `PDF.Render.Client+iOS.swift` (iOS implementation)

Adding Linux requires:
1. Implement `PDF.Render.Client+Linux.swift`
2. Use a Linux WebKit renderer (e.g., via WebKitGTK)
3. Add platform detection

**Status:** Architecture ready, waiting for WebKit integration. PRs welcome!

---

## Comparison to Alternatives

| Solution | Throughput | Memory | Type-Safe | Platform | Cost |
|----------|------------|--------|-----------|----------|------|
| **HtmlToPdf** | **1,939/sec** | Constant | ✅ Swift 6 | Apple | Free |
| wkhtmltopdf | ~100/sec | Growing | ❌ CLI | Linux | Free |
| Puppeteer | ~50/sec | High | ❌ JS | Cross | Free |
| PDFKit (native) | N/A | Low | Partial | Apple | Free |
| AWS Lambda | ~1,667/sec | Per-invocation | ❌ | Cloud | $$$ |
| Commercial APIs | Varies | N/A | ❌ | Cloud | $$$$ |

**HtmlToPdf is the fastest open-source solution for Apple platforms.**

---

## Contributing

Contributions are welcome! Please:

1. **Read the code** - It's well-documented and educational
2. **Add tests** - We have 95%+ coverage
3. **Follow conventions** - Swift 6, strict concurrency, no force-unwraps
4. **Update docs** - DocC comments + README examples

### Areas for Contribution

- **Linux support** - Implement WebKit renderer for Linux
- **Performance improvements** - Always welcome
- **Documentation** - More examples, translations
- **Bug reports** - With reproduction steps

---

## Related Projects

Part of the [coenttb Swift ecosystem](https://github.com/coenttb):

- **[swift-html](https://github.com/coenttb/swift-html)** - Type-safe HTML & CSS DSL
- **[swift-html](https://github.com/coenttb/swift-html)** - Type-safe HTML & CSS DSL

Built on [Point-Free](https://www.pointfree.co) foundations:
- **[swift-dependencies](https://github.com/pointfreeco/swift-dependencies)** - Dependency injection
- **[pointfree-html](https://github.com/coenttb/pointfree-html)** - HTML DSL foundation

---

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- **Point-Free** for swift-dependencies and HTML DSL foundations
- **Apple** for WKWebView and Swift 6
- **The Swift Community** for feedback and contributions

---

## Questions?

- **Issues:** [GitHub Issues](https://github.com/coenttb/swift-html-to-pdf/issues)
- **Discussions:** [GitHub Discussions](https://github.com/coenttb/swift-html-to-pdf/discussions)
- **Email:** [coen@coenttb.com](mailto:coen@coenttb.com)

---

**Made with ❤️ by [Coen ten Thije Boonkkamp](https://coenttb.com)**

⚡ **Fast** • 💾 **Efficient** • 🎯 **Type-Safe** • 🧪 **Production-Ready**
