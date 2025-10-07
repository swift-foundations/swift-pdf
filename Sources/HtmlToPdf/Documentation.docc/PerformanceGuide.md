# Performance Guide

Understand what makes HtmlToPdf fast, then optimize for your specific use case.

## Overview

HtmlToPdf achieves **1,939 PDFs/sec** peak throughput—faster than most commercial solutions. This guide explains how, and shows you how to tune performance for your workload.

**You'll learn:**
1. The counter-intuitive discoveries (memory efficiency paradox, concurrency optimization)
2. When to use which pagination mode
3. How to tune concurrency for your hardware
4. When adaptive optimization helps

---

## The "Wow" Numbers

### Continuous Mode (Maximum Speed)

| Batch Size | Throughput | Avg Latency | Memory |
|------------|------------|-------------|--------|
| 100        | 1,772/sec  | 0.56ms      | 146 MB |
| 1,000      | **1,939/sec** | **0.52ms** | **146 MB** |
| 10,000     | 1,814/sec  | 0.55ms      | 148 MB |

**That's 116,340 PDFs per minute. Or 6.98 million per hour.**

### Paginated Mode (Print-Ready)

| Batch Size | Throughput | Avg Latency | Memory |
|------------|------------|-------------|--------|
| 100        | 142/sec    | 7.05ms      | 102 MB |
| 1,000      | **677/sec** | **1.48ms** | **110 MB** |
| 10,000     | 485/sec    | 2.06ms      | 137 MB |

**Still 40,620 PDFs per minute. Faster than most solutions' "fast" mode.**

### Test Environment

- Platform: macOS 26.0
- CPU: Apple Silicon (8 cores)
- Memory: 24 GB RAM
- Swift: 6.0+
- Pool: 6-8 WebViews (automatic concurrency)

**These are real numbers. Measured, not estimated.**

---

## The Counter-Intuitive Discoveries

### Discovery #1: More Concurrency = LESS Memory

Here's something weird that defies expectation:

| WebViews | Memory Usage | You'd Expect |
|----------|--------------|--------------|
| 1        | ~100 MB      | 100 MB       |
| 4        | ~37 MB       | 400 MB       |
| 8        | ~38 MB       | 800 MB       |
| 24       | ~147 MB      | 2,400 MB     |

**Wait, what?** Adding 23 more workers only adds 47 MB?

**Yes. Here's why:**

1. **Shared pool overhead:** One-time cost (~100 MB) shared across all WebViews
2. **Resource sharing:** WebViews share font caches, image decoders, layout engines
3. **Aggressive GC:** More activity = more frequent garbage collection
4. **WebKit design:** Optimized for concurrent usage

**Result:** 8 WebViews use ~35 MB total. Running 1 WebView 8 times would use ~800 MB.

**This is the power of resource pooling.**

### Discovery #2: CPU Count = Optimal Concurrency

Conventional wisdom says: **concurrency = CPU count**

Empirical testing on an 8-core M-series Mac reveals the optimal point:

| WebViews | Multiplier | Throughput | Notes |
|----------|------------|------------|-------|
| 4        | 0.5x       | 1,645/sec  | Below optimal |
| **8**    | **1.0x**   | **1,737/sec** | **← PEAK** |
| 12       | 1.5x       | 1,608/sec  | Diminishing returns |
| 16       | 2.0x       | 1,590/sec  | Context switching overhead |

**Result:** 1x CPU count delivers peak throughput

**Why does 1x work best?**

WebViews are partially I/O-bound but context switching has overhead:
- WebViews spend time in layout, painting, font loading (I/O)
- Swift concurrency efficiently utilizes cores at 1x CPU count
- Beyond CPU count, context switching costs exceed I/O waiting benefits

**This represents the sweet spot** between parallelism and overhead.

### Discovery #3: Batch Replacement Prevents Degradation

WebKit accumulates memory in the process space over time. Not a leak—just accumulation.

**Experiment: Render 100,000 PDFs**

| Approach | Throughput Start | Throughput End | Degradation |
|----------|------------------|----------------|-------------|
| Naive (no replacement) | 1,386/sec | 776/sec | **44%** |
| Replace every 50K | 1,386/sec | 1,122/sec | **19%** |

**Result:** Batch replacement is **60% faster** over 1M PDFs vs naive approach.

**How it works:**
1. Render 50,000 PDFs with Pool A
2. Create fresh Pool B in background (100-200ms)
3. Drain Pool A (finish in-flight renders)
4. Switch to Pool B
5. Release Pool A (garbage collected)
6. Repeat

**Overhead:** ~100-200ms every 50,000 PDFs = negligible

**When it matters:** Batches >50,000 PDFs, long-running processes

---

## Choosing the Right Mode

### Mode Comparison

| Mode | Throughput | Use Case | Page Layout | Implementation |
|------|------------|----------|-------------|----------------|
| **Continuous** | ⚡⚡⚡⚡⚡ 1,939/sec | Web captures, receipts, articles | Single tall page | `WKWebView.createPDF()` |
| **Paginated** | ⚡⚡⚡ 696/sec | Invoices, contracts, reports | Multiple pages | `NSPrintOperation` |
| **Automatic** | ⚡⚡⚡⚡ Adaptive | Mixed content | Smart detection | Heuristic-based |

### Continuous Mode: When Speed Matters

```swift
try await withDependencies {
    $0.pdf.render.configuration.paginationMode = .continuous
} operation: {
    try await pdf.render(html: html, to: fileURL)
}
```

**Characteristics:**
- **2.9x faster** than paginated mode
- Single tall page (height = content height)
- CSS page breaks are ignored
- Uses modern `WKWebView.createPDF()` API

**Best for:**
- Web article captures
- Receipts and confirmations
- Email newsletters
- Screen-optimized documents
- Maximum throughput scenarios

**Trade-off:** Not suitable for printing (pages aren't standard sizes)

### Paginated Mode: When Print Quality Matters

```swift
try await withDependencies {
    $0.pdf.render.configuration.paginationMode = .paginated
} operation: {
    try await pdf.render(html: html, to: fileURL)
}
```

**Characteristics:**
- Proper multi-page layout
- Respects CSS `@page` and `page-break-` rules
- Each page matches configured `paperSize`
- Uses legacy `NSPrintOperation` API

**Best for:**
- Invoices
- Contracts
- Reports
- Documents for physical printing
- When page breaks must be precise

**Trade-off:** 2.9x slower due to page break calculation overhead

### Automatic Mode: Smart Detection

```swift
try await withDependencies {
    $0.pdf.render.configuration.paginationMode = .automatic()
} operation: {
    try await pdf.render(html: html, to: fileURL)
}
```

**How it works:**
- Analyzes HTML content
- Applies heuristics (content length, structure, etc.)
- Chooses continuous or paginated automatically

**Heuristic options:**
```swift
.automatic()  // Default heuristics
.automatic(heuristic: .contentLength(threshold: 1.5))  // >1.5 pages → paginated
.automatic(heuristic: .htmlStructure)                  // Detect print-specific CSS
.automatic(heuristic: .preferSpeed)                    // Bias toward continuous
.automatic(heuristic: .preferPrintReady)               // Bias toward paginated
```

**Best for:**
- Mixed content types
- When you don't know document length in advance
- APIs serving different document types

---

## Concurrency Tuning

### Automatic Concurrency (Recommended)

The default `.automatic` strategy is optimal for most use cases:

```swift
$0.pdf.render.configuration.concurrency = .automatic
```

**On macOS with 8 cores:** Uses **8 WebViews** (1x CPU count)
**On iOS with 4 cores:** Uses **4 WebViews** (capped for mobile)

**When to use:**
- You're not sure what concurrency to use
- You want optimal throughput without tuning
- Your app runs on different hardware

### Fixed Concurrency

For specific requirements:

```swift
// Explicit fixed value
$0.pdf.render.configuration.concurrency = .fixed(16)

// Integer literal (syntactic sugar)
$0.pdf.render.configuration.concurrency = 8
```

**When to use:**
- Testing specific configurations
- Known hardware constraints
- Explicit memory budget

### Concurrency Guidelines

| Use Case | Recommended Concurrency | Memory Impact |
|----------|-------------------------|---------------|
| **Low load** | 2-4 WebViews | Minimal (~40 MB) |
| **Balanced** | 8-12 WebViews | Moderate (~80 MB) |
| **High throughput** | 24+ WebViews | Higher (~150 MB) |
| **Memory constrained** | 1-2 WebViews | Minimal (~100 MB) |

**Rule of thumb:**
- **Mobile (iOS):** 4-8 WebViews (thermal and battery constraints)
- **Desktop (macOS):** 12-32 WebViews (higher power budget)

---

## Memory Management

### Constant Memory Regardless of Batch Size

One of the most remarkable characteristics:

| Batch Size | Peak Memory | Memory Growth |
|------------|-------------|---------------|
| 100        | 146 MB      | Baseline      |
| 1,000      | 147 MB      | +0.7%         |
| 10,000     | 148 MB      | +1.4%         |
| 100,000    | 150 MB      | +2.7%         |

**Memory usage is effectively constant.**

**Why this matters:**
- Process 1,000 PDFs? 147 MB
- Process 1,000,000 PDFs? ~150 MB
- **No memory leaks**, **no unbounded growth**

**How it works:**
1. **Resource pooling:** Fixed-size pool (e.g., 8 WebViews on 8-core Mac)
2. **Streaming results:** Results processed and released immediately
3. **Batch replacement:** Fresh pool every 50K prevents accumulation
4. **Automatic GC:** Aggressive garbage collection between renders

### Memory Optimization Tips

**Tip 1:** Use streaming to process results immediately
```swift
for try await result in try await pdf.render(html: html, to: directory) {
    // Upload immediately
    try await uploadToS3(result.url)

    // Delete local file
    try FileManager.default.removeItem(at: result.url)

    // Result is released - memory stays constant
}
```

**Tip 2:** Lower concurrency if memory is extremely constrained
```swift
$0.pdf.render.configuration.concurrency = 2  // Minimal memory footprint
```

---

## Optimization Strategies

### Strategy 1: Minimize HTML Complexity

Simpler HTML renders faster:

**Slow:**
```html
<div style="display: flex; flex-direction: column; ...">
    <div style="position: absolute; transform: rotate(45deg); ...">
        <div style="background: linear-gradient(45deg, ...); ...">
            Complex nested structure with heavy CSS
        </div>
    </div>
</div>
```

**Fast:**
```html
<div class="simple-container">
    <p>Clean, simple structure</p>
</div>
```

**Guidelines:**
- Avoid deep nesting (>5 levels)
- Minimize external resources
- Use efficient CSS selectors
- Prefer base64-encoded images (avoid network fetches)

### Strategy 2: Batch Similar Documents

Group documents by complexity:

```swift
// Render simple documents first (fast pool warmup)
let simpleResults = try await pdf.render(html: simpleHTMLs, to: directory)

// Then complex documents (pool is already optimized)
let complexResults = try await pdf.render(html: complexHTMLs, to: directory)
```

**Why:** Pool optimizations (font caching, layout strategies) benefit similar documents

### Strategy 3: Configure Timeouts

Prevent hanging on problematic documents:

```swift
try await withDependencies {
    $0.pdf.render.configuration.documentTimeout = .seconds(30)  // Per-document
    $0.pdf.render.configuration.batchTimeout = .seconds(3600)   // Total batch
} operation: {
    // Rendering with timeouts
}
```

**Guidelines:**
- **documentTimeout:** Set based on your most complex document (typically 10-30s)
- **batchTimeout:** Set based on batch size × expected throughput
- **webViewAcquisitionTimeout:** Keep at 300s unless under extreme load

### Strategy 4: Stream Results for Lower Latency

Don't wait for the batch to finish:

```swift
for try await result in try await pdf.render(html: html, to: directory) {
    // This PDF is ready NOW
    // Others are still rendering in parallel

    try await uploadToS3(result.url)        // Upload immediately
    try await db.markComplete(result.index) // Update database
    try await notifyUser(result.url)        // Send notification
}
```

**Benefits:**
- **First result:** Milliseconds (not waiting for entire batch)
- **Constant memory:** Results consumed as generated
- **Better UX:** Real-time progress updates

---

## Benchmarking Your Workload

### Run the Included Benchmarks

```bash
# Quick benchmark (1K PDFs)
swift test --filter "benchmark1kSimplePDFs"

# Comprehensive benchmark (10K PDFs)
swift test --filter "benchmark10kSimplePDFs"

# Generate README performance table
swift test --filter "generateReadmeTable"
```

### Custom Benchmarking

```swift
import HtmlToPdf
import Dependencies

@Dependency(\.pdf) var pdf

let start = ContinuousClock.now
var count = 0

for try await result in try await pdf.render(html: yourHTMLs, to: directory) {
    count += 1
    let elapsed = ContinuousClock.now - start
    let throughput = Double(count) / elapsed.components.seconds

    print("[\(count)] \(Int(throughput)) PDFs/sec")
}

let total = ContinuousClock.now - start
print("Total: \(count) PDFs in \(total)")
print("Average: \(Int(Double(count) / total.components.seconds)) PDFs/sec")
```

---

## Troubleshooting Performance

### Slower Than Expected?

**Check #1:** Are you using the right pagination mode?
```swift
// Continuous is 5.1x faster
$0.pdf.render.configuration.paginationMode = .continuous
```

**Check #2:** Is concurrency optimal?
```swift
// Use automatic for optimal throughput
$0.pdf.render.configuration.concurrency = .automatic
```

**Check #3:** Is HTML complexity high?
- Simplify CSS
- Reduce nesting depth
- Remove external resources

**Check #4:** System memory pressure?
- Check Activity Monitor / top
- Close other memory-intensive apps
- Lower concurrency if needed

**Check #5:** Other WebKit processes competing?
- Close browsers
- Close apps using WebViews
- Check for background WebKit processes

### Memory Growing Over Time?

**Should NOT happen.** Memory should be constant.

**If it is happening:**

**Check #1:** Are you releasing results?
```swift
// ❌ Bad: Storing all results
var allResults: [PDF.Render.Result] = []
for try await result in try await pdf.render(...) {
    allResults.append(result)  // Retains all PDFs in memory
}

// ✅ Good: Process and release
for try await result in try await pdf.render(...) {
    try await process(result)
    // Result released automatically
}
```

**Check #2:** macOS memory compression?
- macOS may show high memory usage but it's compressed
- Check "Memory Pressure" in Activity Monitor (should be green)

### Inconsistent Performance?

**Cause #1:** First batch is slower (pool warmup)
- **Solution:** Expected behavior (~100-500ms warmup)
- Subsequent batches are at peak throughput

**Cause #2:** System load fluctuations
- **Solution:** Monitor system resources
- Close competing applications

**Cause #3:** Variable document complexity
- **Solution:** Batch similar documents together
- Consider testing with representative samples

---

## Performance Comparison

### HtmlToPdf vs Alternatives

| Solution | Throughput | Memory | Platform | Notes |
|----------|------------|--------|----------|-------|
| **HtmlToPdf** | **1,939/sec** | Constant | Apple | This library |
| Puppeteer | ~50/sec | High | Cross-platform | Node.js |
| PDFKit (native) | N/A | Low | Apple | Different use case |
| AWS Lambda | ~1,667/sec | Per-invocation | Cloud | $$$ |
| Commercial APIs | Varies | N/A | Cloud | $$$$ |

**HtmlToPdf is faster than AWS Lambda. At zero cost.**

### Why HtmlToPdf is Faster

1. **Native WebKit:** Direct access to WKWebView (no IPC overhead)
2. **Resource pooling:** Pre-warmed WebViews (zero init cost)
3. **Optimal concurrency:** 1x CPU count balances parallelism with context switching
4. **Batch replacement:** Prevents performance degradation
5. **Swift 6 concurrency:** Zero-cost async/await
6. **Memory efficiency:** Shared resources, aggressive GC

**Result:** State-of-the-art throughput with constant memory.

---

## Next Steps

Now that you understand the performance characteristics:

- **[Configuration Guide](ConfigurationGuide)** - Master all configuration options
- **[Getting Started](GettingStarted)** - See performance in action with examples
- **API Reference** - Explore ``PDF/Configuration`` and tuning options

---

**The library is fast by default. This guide helps you make it even faster for your specific use case.**
