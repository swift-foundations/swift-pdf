# Getting Started

Generate your first PDF in seconds, then discover the full power of HtmlToPdf.

## Overview

HtmlToPdf uses **progressive disclosure**: start with a one-liner, then unlock advanced features as you need them.

This guide follows the learning path:
1. **Level 1:** One-line PDF generation (30 seconds)
2. **Level 2:** Type-safe HTML and batch processing (5 minutes)
3. **Level 3:** Custom configuration and advanced batches (15 minutes)

---

## Level 1: The Absolute Simplest Example

### Installation

Add HtmlToPdf to your `Package.swift`:

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

### Your First PDF (HTML String)

```swift
import HtmlToPdf
import Dependencies

@Dependency(\.pdf) var pdf

// HTML string → PDF file
let html = "<html><body><h1>Hello, World!</h1></body></html>"
try await pdf.render(html: html, to: fileURL)
```

**That's it.** One line creates a PDF.

### Your First PDF (In-Memory)

Need PDF data instead of a file?

```swift
// HTML string → PDF data (in-memory)
let pdfData = try await pdf.render(html: "<h1>Invoice #1234</h1>")

// Use the data however you want
try await uploadToS3(pdfData)
try await emailToCustomer(pdfData)
```

**Perfect for:** API responses, email attachments, immediate uploads

---

## Level 2: Type-Safe HTML

### Why Type Safety Matters

String-based HTML has problems:

```swift
// ❌ Typo in closing tag - runtime error
let html = "<html><body><h1>Hello</h2></body></html>"

// ❌ Unclosed tag - malformed PDF
let html = "<html><body><h1>Hello</body></html>"

// ❌ Invalid nesting - browser guesses what you meant
let html = "<p><h1>Title</h1></p>"
```

**Type-safe HTML:** Invalid HTML won't compile.

### Using the HTML DSL

```swift
import HTML

struct Invoice: HTML {
    let number: Int
    let total: Decimal

    var body: some HTML {
        html {
            head {
                title { "Invoice #\(number)" }
                style { """
                    body { font-family: system-ui; padding: 20px; }
                    h1 { color: #333; }
                    """
                }
            }
            body {
                h1 { "Invoice #\(number)" }
                p { "Thank you for your business!" }
                p { "Total: $\(total)" }
            }
        }
    }
}

@Dependency(\.pdf) var pdf
try await pdf.render(html: Invoice(number: 1234, total: 99.99), to: fileURL)
```

**Benefits:**
- **Compile-time safety:** Invalid HTML won't compile
- **Autocomplete:** Xcode suggests valid tags
- **Refactoring:** Rename variables safely
- **Type checking:** Pass wrong type? Compiler error

### Complex HTML with Swift

Use all of Swift's features:

```swift
struct Report: HTML {
    let items: [LineItem]

    var body: some HTML {
        html {
            body {
                h1 { "Sales Report" }

                // For loops
                for item in items {
                    div {
                        p { item.name }
                        p { "$\(item.price)" }
                    }
                }

                // Conditionals
                if items.isEmpty {
                    p { "No items to display" }
                }

                // Computed properties
                p { "Total: $\(totalPrice)" }
            }
        }
    }

    var totalPrice: Decimal {
        items.reduce(0) { $0 + $1.price }
    }
}
```

**This is just Swift.** All language features work.

---

## Level 3: Batch Processing

### Simple Batch (Fail-Fast)

Generate multiple PDFs:

```swift
@Dependency(\.pdf) var pdf

let htmls = [
    "<html><body><h1>Document 1</h1></body></html>",
    "<html><body><h1>Document 2</h1></body></html>",
    "<html><body><h1>Document 3</h1></body></html>"
]

for try await result in try await pdf.render(htmls: htmls, to: directory) {
    print("[\(result.index + 1)/\(htmls.count)] \(result.url.lastPathComponent)")
    print("  Duration: \(result.duration)")
    print("  Pages: \(result.pageCount)")
}
```

**Behavior:** Throws on first error, stops processing

**When to use:**
- When you want fail-fast behavior
- When errors should stop processing immediately
- When you'll handle errors yourself

---

## Level 4: Configuration

### Using Presets

Quick configuration for common scenarios:

```swift
// Default (good for 90% of use cases)
$0.pdf.render.configuration = .default

// Maximum speed
$0.pdf.render.configuration = .continuous

// Print-ready documents
$0.pdf.render.configuration = .multiPage

// Smart auto-detection
$0.pdf.render.configuration = .smart

// High-volume batch processing
$0.pdf.render.configuration = .largeBatch
```

### Custom Configuration

```swift
try await withDependencies {
    $0.pdf.render.configuration.paperSize = .letter
    $0.pdf.render.configuration.margins = .wide
    $0.pdf.render.configuration.paginationMode = .paginated
    $0.pdf.render.configuration.concurrency = 24
} operation: {
    @Dependency(\.pdf) var pdf
    try await pdf.render(html: html, to: fileURL)
}
```

### Full Control

```swift
try await withDependencies {
    $0.pdf.render.configuration = PDF.Configuration(
        // Document
        paperSize: .letter,                    // 8.5" × 11"
        margins: .wide,                        // 1 inch margins
        paginationMode: .paginated,            // Multi-page layout

        // Performance
        concurrency: 24,                       // Max throughput
        adaptiveThroughputOptimization: true,  // Self-healing

        // Timeouts
        documentTimeout: .seconds(30),         // Per-document
        batchTimeout: .seconds(3600),          // Total batch

        // File system
        createDirectories: true,               // Auto-create dirs
        namingStrategy: .sequential            // 1.pdf, 2.pdf, ...
    )
} operation: {
    // Your rendering code
}
```

---

## Real-World Example: Invoice System

Here's a complete, production-ready invoice system:

```swift
import HtmlToPdf
import HTML
import Dependencies

// Type-safe invoice model
struct Invoice: HTML {
    let number: Int
    let date: Date
    let customer: Customer
    let items: [LineItem]

    var body: some HTML {
        html {
            head {
                title { "Invoice #\(number)" }
                style { invoiceCSS }
            }
            body {
                div(.class("header")) {
                    h1 { "INVOICE" }
                    p { "Invoice #\(number)" }
                    p { "Date: \(formattedDate)" }
                }

                div(.class("customer")) {
                    h2 { "Bill To:" }
                    p { customer.name }
                    p { customer.address }
                }

                table(.class("items")) {
                    thead {
                        tr {
                            th { "Item" }
                            th { "Quantity" }
                            th { "Price" }
                            th { "Total" }
                        }
                    }
                    tbody {
                        for item in items {
                            tr {
                                td { item.name }
                                td { "\(item.quantity)" }
                                td { "$\(item.price)" }
                                td { "$\(item.total)" }
                            }
                        }
                    }
                }

                div(.class("total")) {
                    p { "Subtotal: $\(subtotal)" }
                    p { "Tax: $\(tax)" }
                    p { "Total: $\(total)" }
                }
            }
        }
    }

    var invoiceCSS: String {
        """
        body { font-family: system-ui; padding: 40px; }
        .header { text-align: center; margin-bottom: 30px; }
        .customer { margin-bottom: 30px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; border-bottom: 1px solid #ddd; text-align: left; }
        .total { text-align: right; margin-top: 30px; font-weight: bold; }
        """
    }

    var formattedDate: String {
        // Date formatting logic
    }

    var subtotal: Decimal { /* calculation */ }
    var tax: Decimal { /* calculation */ }
    var total: Decimal { /* calculation */ }
}

// Generate invoices
func generateInvoices() async throws {
    @Dependency(\.pdf) var pdf

    let invoices = try await database.fetchPendingInvoices()

    try await withDependencies {
        $0.pdf.render.configuration.paginationMode = .paginated
        $0.pdf.render.configuration.concurrency = 24
    } operation: {
        let documents = invoices.map { invoice in
            PDF.Document(
                html: invoice,
                destination: outputDirectory
                    .appendingPathComponent("invoice-\(invoice.number).pdf")
            )
        }

        for try await result in try await pdf.render.client.documents(documents) {
            try await database.markInvoiceGenerated(invoice: result.index)
            try await emailInvoice(result.url)
            print("✅ Invoice #\(result.index) sent in \(result.duration)")
        }
    }
}
```

**This example demonstrates:**
- ✅ Type-safe HTML with Swift models
- ✅ Custom CSS styling
- ✅ Computed properties for totals
- ✅ Batch processing with streaming
- ✅ Database integration
- ✅ Real-time progress tracking

---

## Performance Tips

### Start Simple, Then Optimize

**Level 1:** Just use defaults
```swift
try await pdf.render(html: html, to: fileURL)
```

**Level 2:** Pick the right mode
```swift
$0.pdf.render.configuration.paginationMode = .continuous  // 2,016 PDFs/sec
// or
$0.pdf.render.configuration.paginationMode = .paginated   // 696 PDFs/sec
```

**Level 3:** Tune concurrency
```swift
$0.pdf.render.configuration.concurrency = 24  // 3x CPU count = optimal
```

**Level 4:** Enable adaptive optimization (for large batches)
```swift
$0.pdf.render.configuration.adaptiveThroughputOptimization = true
```

### When to Use Each Pagination Mode

| Mode | Speed | Best For | Page Layout |
|------|-------|----------|-------------|
| **Continuous** | ⚡⚡⚡⚡⚡ 2,016/sec | Receipts, web captures | Single tall page |
| **Paginated** | ⚡⚡⚡ 696/sec | Invoices, contracts | Multiple pages |
| **Automatic** | ⚡⚡⚡⚡ Adaptive | Mixed content | Smart detection |

**Rule of thumb:**
- Need **speed**? Use continuous
- Need **print-ready**? Use paginated
- Not sure? Use automatic

---

## Common Patterns

### Pattern 1: Generate and Upload

```swift
for try await result in try await pdf.render(htmls: htmls, to: directory) {
    // Upload immediately after generation
    try await uploadToS3(result.url)

    // Delete local file to save disk space
    try FileManager.default.removeItem(at: result.url)
}
```

### Pattern 2: Progress Reporting

```swift
let total = htmls.count
var completed = 0

for try await result in try await pdf.render(htmls: htmls, to: directory) {
    completed += 1
    let progress = Double(completed) / Double(total)
    print("Progress: \(Int(progress * 100))%")

    // Update UI or send progress events
    await MainActor.run {
        progressView.progress = progress
    }
}
```

### Pattern 3: Custom Error Handling

```swift
var completed = 0
var failed = 0

do {
    for try await result in try await pdf.render(htmls: htmls, to: directory) {
        completed += 1
        try await uploadToS3(result.url)
        print("✅ \(completed) complete")
    }
} catch {
    failed = htmls.count - completed
    print("❌ Processing stopped at \(completed)/\(htmls.count)")
    print("   Error: \(error.localizedDescription)")
    // Handle the error as needed
}

print("Summary: \(completed) successful, \(failed) failed")

---

## Next Steps

You've learned the essentials. Now dive deeper:

- **[Performance Guide](PerformanceGuide)** - Optimize for your use case, understand the "3x CPU count" discovery
- **[Configuration Guide](ConfigurationGuide)** - Master all configuration options
- **API Reference** - Explore ``PDF/Render``, ``PDF/Configuration``, and ``PDF/PaginationMode``

---

## Quick Reference

### One-Liners

```swift
// HTML string → PDF file
try await pdf.render(html: html, to: fileURL)

// HTML string → PDF data
let data = try await pdf.render(html: html)

// Type-safe HTML → PDF file
try await pdf.render(html: MyPage(), to: fileURL)

// Batch HTML → PDF files (streaming)
for try await result in try await pdf.render(htmls: htmls, to: directory) { ... }

// Direct primitive access
for try await result in try await pdf.render.client.documents(documents) { ... }
```

### Common Configurations

```swift
// Fast (continuous mode)
$0.pdf.render.configuration = .continuous

// Print-ready (paginated mode)
$0.pdf.render.configuration = .multiPage

// High-volume (adaptive optimization)
$0.pdf.render.configuration = .largeBatch

// Custom paper size
$0.pdf.render.configuration.paperSize = .letter

// Custom margins
$0.pdf.render.configuration.margins = .wide

// Max concurrency
$0.pdf.render.configuration.concurrency = 24
```

---

**Ready to build?** The API is simple, but the performance is exceptional. Start with one line, scale to millions of PDFs.
