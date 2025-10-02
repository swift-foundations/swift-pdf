# HtmlToPdf

[![CI](https://github.com/coenttb/swift-html-to-pdf/actions/workflows/ci.yml/badge.svg)](https://github.com/coenttb/swift-html-to-pdf/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20iOS-blue.svg)](https://github.com/coenttb/swift-html-to-pdf)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

HtmlToPdf provides an easy-to-use interface for concurrently printing HTML to PDF on iOS and macOS.

## Features

- Convert HTML strings to PDF documents on both iOS and macOS.
- Lightweight and fast: it can handle thousands of documents quickly.
- Customize margins for PDF documents.
- Swift 6 language mode enabled
- And one more thing: easily print images in your PDFs!

## Examples

Print to a file url:
```swift
try await "<html><body><h1>Hello, World 1!</h1></body></html>".print(to: URL(...))
```
Print to a directory with a file title.
```swift
let directory = URL(...)
let html = "<html><body><h1>Hello, World 1!</h1></body></html>"
try await html.print(title: "file title", to: directory)
```

Print a collection to a directory.
```swift
let directory = URL(...)
try await [
    html,
    html,
    html,
    ....
]
.print(to: directory)
```

## Pagination Modes

HtmlToPdf supports different pagination styles to match your use case:

### Paginated PDFs (Print-Ready)

Split content into multiple pages with proper dimensions - perfect for printing:

```swift
try await withDependencies {
    $0.pdfConfiguration.paginationMode = .paginated
} operation: {
    @Dependency(\.pdf) var pdf
    try await pdf.render(invoice, output)
}
// Result: Multiple A4 pages (595 × 842 pt each)
```

### Continuous PDFs (Screen Viewing)

Single tall page containing all content - ideal for web viewing:

```swift
try await withDependencies {
    $0.pdfConfiguration.paginationMode = .continuous
} operation: {
    @Dependency(\.pdf) var pdf
    try await pdf.render(article, output)
}
// Result: Single tall page (595 × content-height pt)
```

### Automatic Detection

Let the system choose the best approach based on content analysis:

```swift
try await withDependencies {
    $0.pdfConfiguration.paginationMode = .automatic()
} operation: {
    @Dependency(\.pdf) var pdf
    let result = try await pdf.render(html, output)
    print("Generated \(result.pageCount) pages")
}
// Automatically uses:
// - Continuous mode for short content (fast)
// - Paginated mode for long content (print-ready)
```

### Configuration Presets

```swift
// Default: Paginated mode (print-ready)
$0.pdfConfiguration = .default

// Fast continuous mode
$0.pdfConfiguration = .continuous

// Smart auto-detection
$0.pdfConfiguration = .smart

// Multi-page (alias for paginated)
$0.pdfConfiguration = .multiPage
```

## Configuration Options

### PDF Configuration

Control printing behavior and resource management with `PDF.Configuration`:

```swift
// Default configuration - suitable for most use cases
try await htmls.print(
    to: directory,
    printingConfiguration: .default
)

// Large batch configuration - optimized for millions of documents
try await htmls.print(
    to: directory,
    printingConfiguration: .largeBatch
)

// Custom configuration with progress tracking
let config = PrintingConfiguration(
    maxConcurrentOperations: 8,           // Limit concurrent prints
    documentTimeout: 30,                  // Timeout per document (seconds)
    batchTimeout: 3600,                   // Overall batch timeout (seconds)
    webViewAcquisitionTimeout: 60,        // WebView acquisition timeout
    progressHandler: { completed, total in
        print("Progress: \(completed)/\(total)")
    }
)
try await htmls.print(
    to: directory,
    printingConfiguration: config
)
```

## Performance

The package uses a globally shared WebView resource pool with **automatic batch replacement** for sustained high-throughput PDF generation:

- **Peak Throughput**: 1,386 PDFs/second (10K PDFs)
- **Sustained Throughput**: 1,160 PDFs/sec (100K), 764 PDFs/sec (1M)
- **Latency**: 0.72ms average per PDF (simple), 1.37ms (complex)
- **Stress tested**: Successfully generates 1,000,000 PDFs in 22 minutes!

### Performance Benchmarks

| Test                      | Count      | Duration  | Throughput   | Avg/PDF   | Notes                          |
|---------------------------|------------|-----------|--------------|-----------|--------------------------------|
| 100 Simple                | 100        | 0.08s     | 1,289/sec    | 0.78ms    |                                |
| 1,000 Simple              | 1,000      | 0.71s     | 1,401/sec    | 0.71ms    |                                |
| 10,000 Simple             | 10,000     | 7.21s     | 1,386/sec    | 0.72ms    | Peak performance               |
| 100,000 Simple            | 100,000    | 86.21s    | 1,160/sec    | 0.86ms    | Batch replacement @ 50K        |
| 1,000,000 Simple          | 1,000,000  | 21m 48s   | 764/sec      | 1.31ms    | Sustained high-volume          |
| 100 Complex               | 100        | 0.15s     | 659/sec      | 1.52ms    |                                |
| 1,000 Complex             | 1,000      | 1.37s     | 728/sec      | 1.37ms    |                                |

**Test Environment:** macOS 26.0, Apple Silicon (8 cores), Swift 6.0+

**Simple document:** `<html><body><p>{{ID}}</p></body></html>`
**Complex document:** Multi-section HTML with CSS styling, tables, and structured content

**Note on large-scale tests:** Tests generating 100K+ PDFs automatically distribute files across subdirectories (1,000 files per directory) to maintain optimal file system performance.

### Memory Management & Batch Replacement

The package implements **automatic batch replacement** to address WebKit's process-level memory accumulation:

- **Pool Size**: 8 concurrent WKWebView instances (optimal for most systems)
- **Replacement Threshold**: 50,000 PDFs (configurable)
- **Process**: Entire pool is replaced with fresh instances, old pool cleaned up by ARC
- **Result**: Prevents memory degradation over millions of PDFs

**Performance characteristics:**
- **Without replacement**: 44% throughput degradation over 100K PDFs
- **With batch replacement @ 50K**: 19% degradation (86s vs 75s baseline)
- **1M PDFs**: 60% faster than without replacement (22min vs 54min)

This approach follows industry best practices for high-volume PDF generation, achieving sustained throughput comparable to commercial solutions while maintaining WKWebView's excellent rendering quality.

### Architecture & Design Decisions

**Why batch replacement over per-PDF process isolation?**

During development, we explored subprocess-based process isolation (spawning a fresh process per PDF) as recommended by some WebKit documentation. However, testing revealed:

- **Subprocess per PDF**: ~1.7 PDFs/sec (680x slower!)
- **Process spawning overhead**: 5-15ms per process
- **Batch replacement**: 1,160 PDFs/sec (optimal)

The batch replacement pattern reuses a pool of WKWebView instances (like a worker pool pattern) and replaces the entire pool every 50K PDFs. This provides:
- Near-zero overhead (pool reuse)
- Effective memory management (fresh pool every 50K)
- True concurrency (8 parallel WebViews)
- Sustained high throughput

This matches patterns used by production systems processing millions of PDFs daily (e.g., Zerodha's 1.5M PDFs in 25 minutes, AWS Lambda implementations at 1,667 PDFs/sec).

### Resource Pool Benefits

- ✅ **Shared pool** prevents resource exhaustion (8 WebViews, not 56)
- ✅ **Background warmup** for instant availability
- ✅ **FIFO queueing** ensures fairness under load
- ✅ **Automatic validation** and reset between uses
- ✅ **Graceful degradation** - queues requests when pool is busy

### Stress Tests

The package includes optional stress tests that are disabled by default to keep regular test runs fast:

```bash
# Run the quick 10k stress test
swift test --filter "Generate 10,000 PDFs"

# Run the full 100k stress test (takes ~10-15 minutes)
swift test --filter "Generate 100,000 PDFs"

# Run all stress tests
swift test --enable-test StressTests
```

**Available stress tests:**
- `test10kPDFs` - 10,000 PDFs in ~7s @ 1,386 PDFs/sec (quick validation)
- `test100kPDFs` - 100,000 PDFs in ~90s @ 1,160 PDFs/sec (batch replacement active)
- `test1MPDFs` - 1,000,000 PDFs in ~22 minutes @ 764 PDFs/sec (ultimate stress test 💪)
- `test1kComplexPDFs` - 1,000 complex styled documents
- `testSustainedLoad` - 5 minutes continuous generation

**Note:** The 1M PDF test creates ~2-3GB of files and triggers 20 batch replacements (every 50K PDFs). Ensure sufficient disk space.

### ``AsyncStream<URL>``

Optionally, you can invoke an overload that returns an ``AsyncStream<URL>`` that yields the URL of each printed PDF.
> [!NOTE] 
> You need to include the ``AsyncStream`` type signature in the variable declaration, otherwise the return value will be Void.

```swift
let directory = URL(...)
let urls: AsyncStream = try await [
    html,
    html,
    html,
    ....
]
.print(to: directory)

for await url in urls {
    Swift.print(url)
}
```

## Including Images in PDFs

HtmlToPdf supports base64-encoded images out of the box.

> [!Important]
> You are responsible for encoding your images to base64.

### Example HTML
The example below will correctly render the image in the HTML, assuming the `[...]` is replaced with a valid base64-encoded string.

```swift
"<html><body><h1>Hello, World 1!</h1><img src="data:image/png;charset=utf-8;base64, [...]" alt="imageDescription"></body></html>"
   .print(to: URL(...))
```

> [!Tip]
> You can use swift to load the image from a relative or absolute path and then convert them to base64.
> Here's how you can achieve this using the convenience initializer on Image using [coenttb/swift-html](https://www.github.com/coenttb/swift-html):
> ```
> struct Example: HTML {
>     var body: some HTML {
>         [...]
>         if let image = Image(base64EncodedFromURL: "path/to/your/image.jpg", description: "Description of the image") {
>             image
>         }
>         [...]
>     }
> } 
> ```
> [Click here for the implementation of `Image.init(base64EncodedFromURL:)`](https://github.com/coenttb/swift-html/blob/main/Sources/HTML/Image.swift), which shows how to encode an image to base64.

## Related projects

### The coenttb stack

* [swift-css](https://www.github.com/coenttb/swift-css): A Swift DSL for type-safe CSS.
* [swift-html](https://www.github.com/coenttb/swift-html): A Swift DSL for type-safe HTML & CSS, integrating [swift-css](https://www.github.com/coenttb/swift-css) and [pointfree-html](https://www.github.com/coenttb/pointfree-html).
* [swift-web](https://www.github.com/coenttb/swift-web): Foundational tools for web development in Swift.
* [coenttb-html](https://www.github.com/coenttb/coenttb-html): Builds on [swift-html](https://www.github.com/coenttb/swift-html), and adds functionality for HTML, Markdown, Email, and printing HTML to PDF.
* [coenttb-web](https://www.github.com/coenttb/coenttb-web): Builds on [swift-web](https://www.github.com/coenttb/swift-web), and adds functionality for web development.
* [coenttb-server](https://www.github.com/coenttb/coenttb-server): Build fast, modern, and safe servers that are a joy to write. `coenttb-server` builds on [coenttb-web](https://www.github.com/coenttb/coenttb-web), and adds functionality for server development.
* [coenttb-vapor](https://www.github.com/coenttb/coenttb-server-vapor): `coenttb-server-vapor` builds on [coenttb-server](https://www.github.com/coenttb/coenttb-server), and adds functionality and integrations with Vapor and Fluent.
* [coenttb-com-server](https://www.github.com/coenttb/coenttb-com-server): The backend server for coenttb.com, written entirely in Swift and powered by [coenttb-server-vapor](https://www.github.com/coenttb-server-vapor).

### PointFree foundations
* [coenttb/pointfree-html](https://www.github.com/coenttb/pointfree-html): A Swift DSL for type-safe HTML, forked from [pointfreeco/swift-html](https://www.github.com/pointfreeco/swift-html) and updated to the version on [pointfreeco/pointfreeco](https://github.com/pointfreeco/pointfreeco).
* [coenttb/pointfree-web](https://www.github.com/coenttb/pointfree-html): Foundational tools for web development in Swift, forked from  [pointfreeco/swift-web](https://www.github.com/pointfreeco/swift-web).
* [coenttb/pointfree-server](https://www.github.com/coenttb/pointfree-html): Foundational tools for server development in Swift, forked from  [pointfreeco/swift-web](https://www.github.com/pointfreeco/swift-web).

## Known Issues

### WebKit Process Assertion Warnings

When running tests or using this library in a command-line environment, you may see warnings like:

```
Error acquiring assertion: <Error Domain=RBSServiceErrorDomain Code=1 
"(target is not running or doesn't have entitlement com.apple.runningboard.assertions.webkit AND 
originator doesn't have entitlement com.apple.runningboard.assertions.webkit)" 
UserInfo={NSLocalizedFailureReason=(target is not running or doesn't have entitlement 
com.apple.runningboard.assertions.webkit AND originator doesn't have entitlement 
com.apple.runningboard.assertions.webkit)}>
```

#### Why This Happens

These warnings occur because:

1. **WebKit in Non-UI Contexts**: This library uses WKWebView to render HTML to PDF, which is designed for use in UI applications, not command-line or test environments.

2. **RunningBoard Service**: macOS uses RunningBoard Service (RBS) to manage process lifecycles. When WebKit processes start in a non-UI context, RBS tries to create process assertions but cannot because the process lacks the required entitlements.

3. **Missing Entitlements**: The `com.apple.runningboard.assertions.webkit` entitlement is needed to properly manage WebKit processes, but is only available to proper UI applications.

#### Impact

Despite these warnings, the library should still function correctly. These messages are warnings, not errors, and don't prevent the PDF generation from working.

#### Potential Solutions

If these warnings are problematic:

1. **Use in a UI Application**: Use this library in a proper UI application context where entitlements can be properly assigned.

2. **Create Test Mocks**: For testing, create mock implementations that don't use real WebKit processes.

3. **Custom Test Runner**: Run tests inside a properly entitlemented app bundle rather than directly.

## CI/CD Status

This project uses GitHub Actions for continuous integration and deployment:

- **Continuous Integration**: Runs on every push and PR to ensure code quality
- **Multi-Platform Testing**: Tests on macOS, iOS (Mac Catalyst), Linux, and Windows
- **Performance Monitoring**: Automated benchmarks track performance across releases
- **Documentation**: Automatic documentation generation with DocC
- **Dependency Updates**: Dependabot keeps dependencies current

## Installation

To install the package, add the following line to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-html-to-pdf.git", from: "0.5.0")
]
```

You can then make HtmlToPdf available to your Package's target by including HtmlToPdf in your target's dependencies as follows:
```swift
targets: [
    .target(
        name: "TheNameOfYourTarget",
        dependencies: [
            .product(name: "HtmlToPdf", package: "swift-html-to-pdf")
        ]
    )
]
```
