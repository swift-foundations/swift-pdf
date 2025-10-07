# Getting Started

Generate your first PDF in 30 seconds, then master advanced features at your own pace.

## Overview

HtmlToPdf is designed for **progressive disclosure**: start with one line of code, then add sophistication as needed.

**What you'll learn:**
1. Generate PDFs from HTML strings (30 seconds)
2. Use type-safe HTML for compile-time safety (5 minutes)
3. Process batches with streaming results (10 minutes)
4. Configure for your specific use case (15 minutes)

**Prerequisites:**
- Swift 6.0+
- macOS 14.0+ or iOS 17.0+
- Xcode 16.0+

---

## Installation

### Add Package Dependency

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-html-to-pdf.git", from: "1.0.0")
]
```

Add to your target:

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

### Optional: Enable Type-Safe HTML

To use the HTML DSL trait, add `traits: ["HTML"]` to your package dependency:

```swift
dependencies: [
    .package(
        url: "https://github.com/coenttb/swift-html-to-pdf.git",
        from: "1.0.0",
        traits: ["HTML"]
    )
]
```

---

## Your First PDF

### HTML String to File

```swift
import HtmlToPdf

@Dependency(\.pdf) var pdf

let html = "<html><body><h1>Hello, World!</h1></body></html>"
try await pdf.render(html: html, to: fileURL)
```

**That's it.** One line creates a PDF with sensible defaults.

### HTML String to Data

Need PDF data instead of a file?

```swift
let pdfData = try await pdf.render(html: "<h1>Invoice #1234</h1>")
```

**Use cases:** API responses, email attachments, in-memory processing

---

## Understanding the Dependency Pattern

HtmlToPdf uses [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) for dependency injection.

### In Functions

```swift
func generateInvoice(invoice: Invoice) async throws {
    @Dependency(\.pdf) var pdf
    let html = "<html><body>\(invoice.html)</body></html>"
    try await pdf.render(html: html, to: fileURL)
}
```

### In Types

```swift
struct InvoiceService {
    @Dependency(\.pdf) var pdf

    func generateInvoice(_ invoice: Invoice) async throws {
        try await pdf.render(html: invoice.html, to: invoice.fileURL)
    }
}
```

### Benefits

- **Testable:** Replace with mock implementation in tests
- **Configurable:** Override configuration per-operation
- **Type-safe:** Compiler-enforced dependencies

---

## Type-Safe HTML (Recommended)

String-based HTML is error-prone:

```swift
// ❌ Typo in closing tag - runtime error
let html = "<html><body><h1>Hello</h2></body></html>"

// ❌ Unclosed tag - malformed PDF
let html = "<html><body><h1>Hello</body></html>"

// ❌ Invalid nesting - unpredictable results
let html = "<p><h1>Title</h1></p>"
```

**Solution:** Type-safe HTML DSL

### Simple Example

```swift
import HTML

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

**Benefits:**
- Invalid HTML won't compile
- Autocomplete for valid tags
- Refactoring safety
- Type checking for dynamic content

**This is just Swift.** All language features work naturally.

---

## Batch Processing

### Streaming Results

Process PDFs as they're generated:

```swift
@Dependency(\.pdf) var pdf

let html = [
    "<html><body><h1>Document 1</h1></body></html>",
    "<html><body><h1>Document 2</h1></body></html>",
    "<html><body><h1>Document 3</h1></body></html>"
]

for try await result in try await pdf.render(html: html, to: directory) {
    print("✅ [\(result.index + 1)/\(html.count)] \(result.url.lastPathComponent)")
    print("   Duration: \(result.duration)")
    print("   Pages: \(result.pageCount)")
}
```

**Behavior:**
- Throws on first error
- Stops processing immediately
- Returns streaming results as PDFs complete

### Progress Tracking

```swift
let total = html.count
var completed = 0

for try await result in try await pdf.render(html: html, to: directory) {
    completed += 1
    let progress = Double(completed) / Double(total)
    print("Progress: \(Int(progress * 100))%")

    // Update UI on main actor
    await MainActor.run {
        progressView.progress = progress
    }
}
```

### Error Handling

```swift
var completed = 0

do {
    for try await result in try await pdf.render(html: html, to: directory) {
        completed += 1
        try await uploadToS3(result.url)
    }
    print("✅ Completed \(completed)/\(html.count)")
} catch {
    print("❌ Failed at \(completed)/\(html.count): \(error.localizedDescription)")
    // Handle partial completion
}
```

**Note:** Current implementation uses fail-fast semantics. Resilient batch processing (continue on error) is planned for future release.

---

## Configuration

### Default Behavior

Sensible defaults work for 90% of use cases:

```swift
@Dependency(\.pdf) var pdf
try await pdf.render(html: html, to: fileURL)
```

**Defaults:**
- Paper: A4 (210 × 297 mm)
- Margins: Standard (0.5 inch / 36pt)
- Mode: Continuous (maximum speed)
- Concurrency: Automatic (1x CPU count)
- Appearance: Light (white background)

### Using Presets

Quick configurations for common scenarios:

```swift
try await withDependencies {
    // Maximum speed (1,939 PDFs/sec)
    $0.pdf.render.configuration = .continuous

    // Print-ready documents (677 PDFs/sec)
    $0.pdf.render.configuration = .multiPage

    // Smart auto-detection
    $0.pdf.render.configuration = .smart

    // Large batch processing
    $0.pdf.render.configuration = .largeBatch
} operation: {
    @Dependency(\.pdf) var pdf
    try await pdf.render(html: html, to: fileURL)
}
```

### Custom Configuration

Fine-tune individual settings:

```swift
try await withDependencies {
    $0.pdf.render.configuration.paperSize = .letter        // US Letter
    $0.pdf.render.configuration.margins = .wide            // 1 inch margins
    $0.pdf.render.configuration.paginationMode = .paginated // Print-ready
    $0.pdf.render.configuration.concurrency = .automatic   // Optimal
} operation: {
    @Dependency(\.pdf) var pdf
    try await pdf.render(html: html, to: fileURL)
}
```

### Full Configuration

Complete control over all options:

```swift
try await withDependencies {
    $0.pdf.render.configuration = PDF.Configuration(
        // Document appearance
        paperSize: .letter,                          // 8.5 × 11 inches
        margins: .wide,                              // 1 inch all sides
        baseURL: URL(string: "https://example.com"), // Resolve relative URLs
        appearance: .light,                          // Force light mode

        // Pagination
        paginationMode: .paginated,                  // Multi-page layout

        // Performance
        concurrency: .automatic,                     // 1x CPU count

        // Timeouts
        documentTimeout: .seconds(30),               // Per-document
        batchTimeout: .seconds(3600),                // Entire batch
        webViewAcquisitionTimeout: .seconds(300),    // Pool acquisition

        // File system
        createDirectories: true,                     // Auto-create
        namingStrategy: .sequential                  // 1.pdf, 2.pdf, ...
    )
} operation: {
    @Dependency(\.pdf) var pdf
    try await pdf.render(html: html, to: fileURL)
}
```

### Per-Operation Configuration

Override settings for specific operations:

```swift
@Dependency(\.pdf) var pdf

// Use defaults for most documents
try await pdf.render(html: receipt, to: receiptURL)

// Override for special documents
try await withDependencies {
    $0.pdf.render.configuration.paginationMode = .paginated
    $0.pdf.render.configuration.margins = .wide
} operation: {
    try await pdf.render(html: contract, to: contractURL)
}
```

---

## Real-World Example: Invoice System

Production invoice generator using real patterns:

```swift
import HtmlToPdf
import HTML

// Type-safe invoice model
struct Invoice: HTMLDocument {
    let invoiceNumber: String
    let invoiceDate: Date
    let client: Client
    let rows: [Row]

    var head: some HTML {
        title { "Invoice #\(invoiceNumber)" }
        style { invoiceCSS }
    }

    var body: some HTML {
        // Header with invoice details
        table {
            tr {
                td {
                    h1 { "Invoice" }
                        .margin(top: 0)
                        .margin(bottom: 0)
                }
                .verticalAlign(.top)
                .width(.percent(100))

                td {
                    table {
                        tr {
                            td { b { "Invoice Number" } }
                                .padding(right: .px(15))
                            td { invoiceNumber }
                        }
                        tr {
                            td { b { "Invoice Date" } }
                                .padding(right: .px(15))
                            td { invoiceDate.formatted(date: .long, time: .omitted) }
                        }
                    }
                }
            }
        }
        .borderCollapse(.collapse)

        br()()
        br()()

        // Items table
        table {
            thead {
                tr {
                    td { b { "Description" } }
                        .width(.percent(100))
                        .padding(right: .px(15))
                    td { b { "Quantity" } }
                        .padding(right: .px(15))
                    td { b { "Unit" } }
                        .padding(right: .px(15))
                    td { b { "Rate" } }
                        .padding(right: .px(15))
                    td { b { "VAT %" } }
                        .padding(right: .px(15))
                }
                .inlineStyle("border-bottom", "1px solid #000")
            }

            HTMLForEach(rows) { row in
                tr {
                    td { row.description }
                        .padding(right: .px(15))
                    td { "\(row.hours)" }
                        .padding(right: .px(15))
                    td { row.hours == 1 ? "Hour" : "Hours" }
                        .padding(right: .px(15))
                    td { row.rate.formatted(.currency(code: "USD")) }
                        .padding(right: .px(15))
                    td { "\(Int(row.vatPercentage * 100))%" }
                        .padding(right: .px(15))
                }
            }
        }
        .borderCollapse(.separate)

        hr().body

        // Totals
        table {
            tr {
                td { HTMLEmpty() }
                    .width(.percent(100))
                td {
                    table {
                        tr {
                            td { "Amount excl. VAT" }
                                .whiteSpace(.nowrap)
                                .padding(right: .px(15))
                            td { totalExcludingVAT.formatted(.currency(code: "USD")) }
                        }
                        tr {
                            td { "VAT" }
                            td { totalVAT.formatted(.currency(code: "USD")) }
                                .inlineStyle("border-bottom", "3px double #000")
                        }
                        tr {
                            td { b { "Total Amount" } }
                            td { b { totalIncludingVAT.formatted(.currency(code: "USD")) } }
                        }
                    }
                }
            }
        }
        .borderCollapse(.collapse)
    }

    var invoiceCSS: String {
        """
        body { font-family: -apple-system, system-ui; color: #333; }
        @media print { @page { margin: 0.5in; } }
        """
    }

    var totalExcludingVAT: Decimal {
        rows.reduce(0) { $0 + $1.total }
    }

    var totalVAT: Decimal {
        rows.reduce(0) { $0 + ($1.total * Decimal($1.vatPercentage)) }
    }

    var totalIncludingVAT: Decimal {
        totalExcludingVAT + totalVAT
    }
}

struct Client {
    let id: String
    let name: String
    let address: [String]
}

struct Row {
    let description: String
    let hours: Decimal
    let rate: Decimal
    let vatPercentage: Double

    var total: Decimal { hours * rate }
}

// Invoice generation service
struct InvoiceService {
    @Dependency(\.pdf) var pdf
    @Dependency(\.database) var database

    func generateInvoices() async throws {
        let pendingInvoices = try await database.fetchPendingInvoices()

        try await withDependencies {
            // Print-ready configuration
            $0.pdf.render.configuration.paperSize = .letter
            $0.pdf.render.configuration.margins = .standard
            $0.pdf.render.configuration.paginationMode = .paginated
            $0.pdf.render.configuration.concurrency = .automatic
        } operation: {
            for try await result in try await pdf.render(
                html: pendingInvoices.map(\.htmlDocument),
                to: invoiceDirectory
            ) {
                let invoice = pendingInvoices[result.index]

                // Mark as generated
                try await database.markInvoiceGenerated(invoice.id)

                // Email to customer
                try await emailService.send(
                    to: invoice.customer.email,
                    subject: "Invoice #\(invoice.number)",
                    attachment: result.url
                )

                print("✅ Invoice #\(invoice.number) sent (\(result.duration))")
            }
        }
    }
}
```

**This example demonstrates:**
- ✅ Type-safe HTML with Swift models
- ✅ Real-world patterns from production code
- ✅ Modern HTML DSL with `.padding()`, `.margin()`, `.inlineStyle()`
- ✅ `HTMLForEach` for iterating collections
- ✅ Nested tables for complex layouts
- ✅ Computed properties for VAT calculations
- ✅ Clean separation of concerns (model, view, styling)
- ✅ Print-optimized with minimal CSS
- ✅ Batch processing with streaming
- ✅ Database integration
- ✅ Email delivery

---

## Common Patterns

### Pattern 1: Generate and Upload

```swift
for try await result in try await pdf.render(html: html, to: directory) {
    // Upload immediately
    try await uploadToS3(result.url)

    // Delete local file to save disk space
    try FileManager.default.removeItem(at: result.url)
}
```

**Benefit:** Constant memory usage, no disk accumulation

### Pattern 2: Progress with UI Updates

```swift
let total = documents.count
var completed = 0

for try await result in try await pdf.render(html: documents, to: directory) {
    completed += 1

    await MainActor.run {
        progressView.progress = Double(completed) / Double(total)
        statusLabel.text = "Generated \(completed) of \(total)"
    }
}
```

### Pattern 3: API Endpoint

```swift
import Vapor

app.post("generate-pdf") { req async throws -> Response in
    struct Request: Content {
        let html: String
    }

    let requestData = try req.content.decode(Request.self)

    @Dependency(\.pdf) var pdf
    let pdfData = try await pdf.render(html: requestData.html)

    return Response(
        status: .ok,
        headers: ["Content-Type": "application/pdf"],
        body: .init(data: pdfData)
    )
}
```

### Pattern 4: Temporary Files

```swift
let temporaryDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)

defer {
    try? FileManager.default.removeItem(at: temporaryDirectory)
}

for try await result in try await pdf.render(html: html, to: temporaryDirectory) {
    try await processAndUpload(result.url)
}
```

---

## Performance Tips

### Choose the Right Pagination Mode

| Mode | Throughput | Best For | Trade-off |
|------|-----------|----------|-----------|
| **Continuous** | 1,939 PDFs/sec | Receipts, web captures, speed-critical | Single tall page (not print-ready) |
| **Paginated** | 677 PDFs/sec | Invoices, contracts, printing | 2.9x slower but proper page breaks |
| **Automatic** | Adaptive | Mixed content, unsure | Smart detection based on content |

**Rule of thumb:**
- Need **maximum speed**? Use `.continuous`
- Need **print-ready**? Use `.paginated`
- **Not sure**? Use `.automatic()`

### Concurrency Guidelines

The default `.automatic` is optimal for most cases:

```swift
$0.pdf.render.configuration.concurrency = .automatic
```

**How it works:**
- **macOS**: 1x CPU count (e.g., 8 WebViews on 8-core Mac)
- **iOS**: Capped at 4 for thermal/battery constraints

**Custom concurrency:**

```swift
// Explicit value
$0.pdf.render.configuration.concurrency = .fixed(8)

// Integer literal (syntactic sugar)
$0.pdf.render.configuration.concurrency = 8
```

**When to customize:**
- Memory-constrained: Use lower value (2-4)
- High-throughput server: Use higher value (12-16)
- Testing: Use specific value for reproducibility

### Memory Optimization

**The library uses constant memory** regardless of batch size:

```swift
// 100 PDFs: ~146 MB
// 10,000 PDFs: ~148 MB
// Memory is constant!
```

**Additional tips:**

```swift
// Process and release immediately
for try await result in try await pdf.render(html: html, to: directory) {
    try await uploadToS3(result.url)
    try FileManager.default.removeItem(at: result.url)
    // Result is released - memory stays constant
}
```

---

## Troubleshooting

### Common Issues

**Issue: "Cannot find 'pdf' in scope"**

Solution: Add `@Dependency(\.pdf) var pdf` to access the PDF client.

**Issue: PDFs have dark backgrounds**

Solution: The library defaults to `.light` appearance. Check your HTML doesn't override this.

**Issue: Slow performance**

Solution: Use `.continuous` mode for maximum speed, or increase concurrency.

**Issue: Memory growing**

Solution: Ensure you're not accumulating results. Use streaming and release PDFs after processing.

**Issue: Timeout errors**

Solution: Increase `documentTimeout` for complex documents:

```swift
$0.pdf.render.configuration.documentTimeout = .seconds(60)
```

---

## Next Steps

You've learned the essentials. Dive deeper:

- **<doc:PerformanceGuide>** - Optimize for your workload (1,939 PDFs/sec explained)
- **<doc:ConfigurationGuide>** - Master all configuration options
- **<doc:MetricsGuide>** - Production monitoring with swift-metrics
- **API Reference** - Explore ``PDF``, ``PDF/Configuration``, ``PDF/Render``

---

## Quick Reference

### Basic Operations

```swift
// HTML string → PDF file
@Dependency(\.pdf) var pdf
try await pdf.render(html: html, to: fileURL)

// HTML string → PDF data
let data = try await pdf.render(html: html)

// Type-safe HTML → PDF
try await pdf.render(html: MyDocument(), to: fileURL)

// Batch with streaming
for try await result in try await pdf.render(html: html, to: directory) {
    print("Generated: \(result.url)")
}
```

### Configuration Presets

```swift
// Maximum speed
$0.pdf.render.configuration = .continuous

// Print-ready
$0.pdf.render.configuration = .multiPage

// Large batches
$0.pdf.render.configuration = .largeBatch

// Platform-optimized
$0.pdf.render.configuration = .platformOptimized
```

### Common Settings

```swift
$0.pdf.render.configuration.paperSize = .letter           // or .a4
$0.pdf.render.configuration.margins = .wide               // or .standard
$0.pdf.render.configuration.paginationMode = .paginated   // or .continuous
$0.pdf.render.configuration.concurrency = .automatic      // or .fixed(8)
```

---

**Ready to build?** Start with one line, scale to millions of PDFs. The API is simple, the performance is exceptional.
