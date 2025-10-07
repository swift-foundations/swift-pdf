# Configuration Guide

Comprehensive guide to configuring HtmlToPdf for your specific needs.

## Overview

HtmlToPdf uses a flexible configuration system that follows progressive disclosure - start simple with sensible defaults, then customize as needed.

## Configuration Hierarchy

### Default Configuration

Works out of the box with optimal settings:

```swift
@Dependency(\.pdf) var pdf
try await pdf.render(html: html, to: fileURL)
// Uses: A4 paper, standard margins, continuous mode, automatic concurrency
```

### Using Presets

Quick configuration for common scenarios:

```swift
// Platform-optimized settings
$0.pdf.render.configuration = .platformOptimized

// US Letter paper
$0.pdf.render.configuration = .letter

// Print-ready multi-page documents
$0.pdf.render.configuration = .multiPage

// Fast continuous mode
$0.pdf.render.configuration = .continuous

// Smart auto-detection
$0.pdf.render.configuration = .smart

// Large batch processing
$0.pdf.render.configuration = .largeBatch
```

### Custom Configuration

Fine-tune every aspect:

```swift
try await withDependencies {
    $0.pdf.render.configuration = PDF.Configuration(
        paperSize: .letter,
        margins: .wide,
        baseURL: URL(string: "https://example.com"),
        paginationMode: .paginated,
        concurrency: 16,
        documentTimeout: .seconds(30),
        batchTimeout: .seconds(3600),
        webViewAcquisitionTimeout: .seconds(300),
        createDirectories: true,
        namingStrategy: .sequential
    )
} operation: {
    @Dependency(\.pdf) var pdf
    try await pdf.render(html: html, to: fileURL)
}
```

## Document Configuration

### Paper Size

Standard paper sizes are provided as static properties:

```swift
// ISO 216 sizes
$0.pdf.render.configuration.paperSize = .a3    // 297 × 420 mm
$0.pdf.render.configuration.paperSize = .a4    // 210 × 297 mm (default)
$0.pdf.render.configuration.paperSize = .a5    // 148 × 210 mm

// US sizes
$0.pdf.render.configuration.paperSize = .letter   // 8.5 × 11 inches
$0.pdf.render.configuration.paperSize = .legal    // 8.5 × 14 inches
$0.pdf.render.configuration.paperSize = .tabloid  // 11 × 17 inches

// Landscape orientation
$0.pdf.render.configuration.paperSize = .a4.landscape
$0.pdf.render.configuration.paperSize = .letter.landscape

// Custom size (in points: 1 point = 1/72 inch)
$0.pdf.render.configuration.paperSize = CGSize(width: 600, height: 800)
```

### Margins

Predefined margin presets:

```swift
$0.pdf.render.configuration.margins = .none         // 0 inches
$0.pdf.render.configuration.margins = .minimal      // 0.25 inch (18pt)
$0.pdf.render.configuration.margins = .standard     // 0.5 inch (36pt) - default
$0.pdf.render.configuration.margins = .comfortable  // 0.75 inch (54pt)
$0.pdf.render.configuration.margins = .wide         // 1 inch (72pt)

// Custom margins (in points)
$0.pdf.render.configuration.margins = EdgeInsets(
    top: 50,
    left: 40,
    bottom: 50,
    right: 40
)

// Symmetric margins
$0.pdf.render.configuration.margins = EdgeInsets(all: 72)

// Horizontal and vertical
$0.pdf.render.configuration.margins = EdgeInsets(
    horizontal: 40,
    vertical: 50
)
```

**Note:** Negative margin values are automatically clamped to zero.

### Base URL

Resolve relative URLs in HTML:

```swift
$0.pdf.render.configuration.baseURL = URL(string: "https://example.com")
```

This allows relative paths in your HTML:
```html
<img src="/images/logo.png">  <!-- Resolves to https://example.com/images/logo.png -->
<link rel="stylesheet" href="/css/styles.css">
```

### Pagination Mode

Choose how content flows into pages:

```swift
// Single tall page (fast, 1,939 PDFs/sec)
$0.pdf.render.configuration.paginationMode = .continuous

// Multiple pages (print-ready, 677 PDFs/sec)
$0.pdf.render.configuration.paginationMode = .paginated

// Automatic selection based on content
$0.pdf.render.configuration.paginationMode = .automatic()
$0.pdf.render.configuration.paginationMode = .automatic(heuristic: .contentLength(threshold: 1.5))
$0.pdf.render.configuration.paginationMode = .automatic(heuristic: .htmlStructure)
$0.pdf.render.configuration.paginationMode = .automatic(heuristic: .preferSpeed)
$0.pdf.render.configuration.paginationMode = .automatic(heuristic: .preferPrintReady)
```

See <doc:PerformanceGuide> for detailed mode comparison.

## Batch Configuration

### Concurrency Strategy

Control how many PDFs render simultaneously:

```swift
// Automatic (recommended) - 1x CPU count on macOS
$0.pdf.render.configuration.concurrency = .automatic

// Fixed value
$0.pdf.render.configuration.concurrency = .fixed(16)

// Integer literal (syntactic sugar for .fixed)
$0.pdf.render.configuration.concurrency = 8
```

**Performance characteristics:**
- **1-4 WebViews**: Conservative, minimal memory
- **4-8 WebViews**: Balanced (typical iOS constraint)
- **8 WebViews**: High throughput (macOS optimal on 8-core)

### Timeouts

Prevent hanging on problematic documents:

```swift
// Per-document timeout (nil = no timeout)
$0.pdf.render.configuration.documentTimeout = .seconds(30)

// Entire batch timeout (nil = no timeout)
$0.pdf.render.configuration.batchTimeout = .seconds(3600)

// WebView acquisition timeout (must have a value)
$0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(300)
```

**Guidelines:**
- **documentTimeout**: Set based on your most complex document (typically 10-30s)
- **batchTimeout**: Set based on expected batch size and throughput
- **webViewAcquisitionTimeout**: Keep at 300s unless under extreme load

## File System Configuration

### Directory Creation

Automatically create output directories:

```swift
// Automatically create directories (default: true)
$0.pdf.render.configuration.createDirectories = true

// Require directories to exist
$0.pdf.render.configuration.createDirectories = false
```

### Naming Strategy

Control how files are named in batch operations:

```swift
// Sequential numbering: "1.pdf", "2.pdf", ... (default)
$0.pdf.render.configuration.namingStrategy = .sequential

// UUID-based names
$0.pdf.render.configuration.namingStrategy = .uuid

// Custom naming function
$0.pdf.render.configuration.namingStrategy = PDF.NamingStrategy { index in
    "document-\(String(format: "%05d", index + 1))"
}
// Results in: "document-00001.pdf", "document-00002.pdf", ...
```

## Common Configuration Patterns

### High-Volume Processing

Optimize for throughput:

```swift
$0.pdf.render.configuration = PDF.Configuration(
    paperSize: .a4,
    margins: .standard,
    paginationMode: .continuous,  // Fast mode
    concurrency: .automatic,      // Maximum throughput
    batchTimeout: .seconds(86400), // 24 hours
    createDirectories: true
)
```

### Print-Ready Documents

Optimize for quality:

```swift
$0.pdf.render.configuration = PDF.Configuration(
    paperSize: .letter,
    margins: .wide,
    paginationMode: .paginated,   // Proper page breaks
    concurrency: 8,               // Balanced
    documentTimeout: .seconds(60), // Complex documents
    createDirectories: true
)
```

### Memory-Constrained Environments

Minimize resource usage:

```swift
$0.pdf.render.configuration = PDF.Configuration(
    paperSize: .a4,
    margins: .standard,
    paginationMode: .continuous,
    concurrency: 2,               // Minimal concurrency
    webViewAcquisitionTimeout: .seconds(60),
    createDirectories: true
)
```

### Development and Testing

Fast iteration with debugging:

```swift
$0.pdf.render.configuration = PDF.Configuration(
    paperSize: .a4,
    margins: .minimal,
    paginationMode: .continuous,  // Fastest
    concurrency: 4,               // Moderate
    documentTimeout: .seconds(10), // Fail fast
    createDirectories: true,
    namingStrategy: .sequential   // Easy to identify
)
```

## Configuration Scoping

### Global Configuration

Set once for entire application:

```swift
// In your app setup
withDependencies {
    $0.pdf.render.configuration = .platformOptimized
} operation: {
    // All PDF operations use this configuration
}
```

### Per-Operation Configuration

Override for specific operations:

```swift
// Default configuration for most operations
@Dependency(\.pdf) var pdf

// Override for specific operation
try await withDependencies {
    $0.pdf.render.configuration.paginationMode = .paginated
} operation: {
    try await pdf.render(html: invoice, to: fileURL)
}
```

### Configuration Testing

Test different configurations:

```swift
@Test(.dependency(\.pdf.render.configuration.paperSize, .letter))
func testLetterSize() async throws {
    // Test runs with Letter paper size
}

@Test(.dependency(\.pdf.render.configuration.margins, .wide))
func testWideMargins() async throws {
    // Test runs with wide margins
}
```

## See Also

- ``PDF/Configuration``
- ``PDF/PaginationMode``
- ``PDF/ConcurrencyStrategy``
- ``PDF/NamingStrategy``
- ``EdgeInsets``
