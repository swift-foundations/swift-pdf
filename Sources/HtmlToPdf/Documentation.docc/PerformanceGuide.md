# Performance Guide

Optimize HtmlToPdf for your specific use case and workload.

## Overview

HtmlToPdf achieves exceptional performance through intelligent resource pooling, adaptive concurrency, and efficient memory management. This guide helps you understand and optimize performance for your needs.

## Performance Characteristics

### Throughput Benchmarks

**Continuous Mode** (fast, single-page):
- Peak: **2,016 PDFs/sec** (1K batch)
- 10K batch: 1,929 PDFs/sec
- Average latency: 0.50ms per PDF
- p95 latency: 4.62ms

**Paginated Mode** (print-ready, multi-page):
- Peak: **696 PDFs/sec** (1K batch)
- 10K batch: 484 PDFs/sec
- Average latency: 1.44ms per PDF
- p95 latency: 12.47ms

### Memory Profile

- Peak memory: ~147 MB (continuous mode)
- Peak memory: ~128 MB (paginated mode)
- Memory usage is **constant** regardless of batch size
- Automatic garbage collection between batches

## Choosing the Right Mode

### Continuous Mode

Use when you need **maximum speed** and **single-page output**:

```swift
$0.pdf.render.configuration.paginationMode = .continuous
```

**Best for:**
- Web captures
- Articles and blog posts
- Infographics
- Screen-optimized documents

**Characteristics:**
- 5.1x faster than paginated mode
- Single tall page (height = content height)
- CSS page breaks are ignored
- Uses `WKWebView.createPDF()` API

### Paginated Mode

Use when you need **print-ready output** with **proper page breaks**:

```swift
$0.pdf.render.configuration.paginationMode = .paginated
```

**Best for:**
- Invoices
- Reports
- Contracts
- Documents for physical printing

**Characteristics:**
- Proper multi-page layout
- Respects CSS page breaks
- Each page matches configured `paperSize`
- Uses `NSPrintOperation` API

### Automatic Mode

Let the library choose based on content:

```swift
// Prefer speed for short content, pagination for long
$0.pdf.render.configuration.paginationMode = .automatic()

// Always prefer speed
$0.pdf.render.configuration.paginationMode = .automatic(heuristic: .preferSpeed)

// Always prefer print-ready
$0.pdf.render.configuration.paginationMode = .automatic(heuristic: .preferPrintReady)
```

## Concurrency Tuning

### Automatic Concurrency (Recommended)

The default `.automatic` strategy calculates optimal concurrency based on your hardware:

```swift
$0.pdf.render.configuration.concurrency = .automatic
```

On macOS with 8 cores, this uses **24 WebViews** (3x CPU count) for optimal throughput.

### Fixed Concurrency

For specific requirements:

```swift
// Explicit value
$0.pdf.render.configuration.concurrency = .fixed(16)

// Integer literal
$0.pdf.render.configuration.concurrency = 8
```

**Guidelines:**
- **Low concurrency (1-4)**: Minimal resource usage, lower throughput
- **Medium concurrency (4-8)**: Balanced for most workloads
- **High concurrency (12-24)**: Maximum throughput, more memory

### Adaptive Throughput Optimization

Enable real-time optimization for long-running batches:

```swift
$0.pdf.render.configuration.adaptiveThroughputOptimization = true
```

**Benefits:**
- Detects performance degradation (>15% drop from peak)
- Triggers early pool replacement to restore performance
- Adapts dynamically to workload characteristics

**When to use:**
- Batches >10,000 PDFs
- Variable document complexity
- Long-running background processes

## Memory Management

### Resource Pooling

HtmlToPdf uses a global WebView pool that's shared across your application:

- Pool is created on first use
- WebViews are warmed up in the background
- Automatic validation between renders
- Graceful degradation under load

### Batch Replacement

For sustained high-volume generation (100K+ PDFs), the library automatically replaces the entire pool every 50,000 PDFs to prevent memory accumulation.

**Performance impact:**
- Without replacement: 44% degradation over 100K PDFs
- With replacement: 19% degradation (minimal)

## Optimization Tips

### 1. Use Streaming for Large Batches

Process results as they arrive instead of waiting for completion:

```swift
for try await result in try await pdf.render(documents: documents) {
    // Process immediately (upload, save to database, etc.)
    try await processResult(result)
}
```

### 2. Minimize HTML Complexity

Simpler HTML renders faster:

- Avoid deep nesting
- Minimize external resources (prefer base64 images)
- Use efficient CSS selectors
- Remove unnecessary whitespace

### 3. Batch Similar Documents

Group documents by complexity for better pool utilization:

```swift
// Render simple documents first
let simpleResults = try await pdf.render(htmls: simpleHTMLs, to: directory)

// Then complex documents
let complexResults = try await pdf.render(htmls: complexHTMLs, to: directory)
```

### 4. Configure Timeouts Appropriately

Prevent hanging on problematic documents:

```swift
$0.pdf.render.configuration.documentTimeout = .seconds(30)
$0.pdf.render.configuration.batchTimeout = .seconds(3600)
$0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(300)
```

## Benchmarking Your Workload

Run the included benchmarks with your actual HTML:

```bash
# Quick benchmark (1K PDFs)
swift test --filter "benchmark1kSimplePDFs"

# Comprehensive benchmark (10K PDFs)
swift test --filter "benchmark10kSimplePDFs"

# Generate README table with all metrics
swift test --filter "generateReadmeTable"
```

## Performance Monitoring

Track performance in production:

```swift
let start = ContinuousClock.now

for try await result in try await pdf.render(documents: documents) {
    let duration = ContinuousClock.now - start
    let throughput = Double(result.index + 1) / duration.components.seconds

    print("Throughput: \(Int(throughput)) PDFs/sec")
    print("Avg latency: \(result.duration)")
}
```

## Troubleshooting Performance

### Slower Than Expected?

1. **Check your HTML complexity**: Complex CSS and layouts take longer
2. **Verify pagination mode**: Continuous is 5x faster than paginated
3. **Monitor memory pressure**: System may throttle under memory pressure
4. **Check for competing workloads**: Other processes using WebKit
5. **Try adaptive optimization**: Enable for batches >10K PDFs

### Memory Growing Over Time?

1. **Batch replacement is automatic**: Should prevent unbounded growth
2. **Check for leaks in your code**: Ensure you're not retaining results
3. **Monitor system memory**: macOS may hold memory for optimization

### Inconsistent Performance?

1. **First batch is slower**: Pool warmup time (~100-500ms)
2. **Enable adaptive optimization**: Helps maintain consistent throughput
3. **Check system load**: Background processes may compete for resources

## See Also

- ``PDF/Configuration``
- ``PDF/PaginationMode``
- ``PDF/ConcurrencyStrategy``
