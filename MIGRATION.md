# Migration Guide

This document provides guidance for migrating between major versions of swift-html-to-pdf.

## Table of Contents

- [v0.5.x → v0.6.0](#v05x--v060)
  - [Overview](#overview)
  - [Breaking Changes](#breaking-changes)
  - [Migration Steps](#migration-steps)
  - [Before and After Examples](#before-and-after-examples)
  - [FAQ](#faq)

---

## v0.5.x → v0.6.0

### Overview

Version 0.6.0 represents a major architectural shift from a String extension-based API to a dependency-injection-based API using [swift-dependencies](https://github.com/pointfreeco/swift-dependencies). This change brings:

- ✅ **Better testability** - Mock PDF generation in tests
- ✅ **Cleaner architecture** - No global state, explicit dependencies
- ✅ **Progressive disclosure** - Simple one-liners to advanced batch processing
- ✅ **Type safety** - Compile-time guarantees with Swift 6 strict concurrency
- ✅ **Performance improvements** - 1,939 PDFs/sec peak throughput (vs ~500 in v0.5.x)

**Backward compatibility:** The v0.5.x API is **deprecated but still works** in v0.6.0. It will be removed in v1.0.0.

### Breaking Changes

#### 1. API Entry Point

**v0.5.x:** String extensions
```swift
try await html.print(to: fileUrl)
```

**v0.6.0:** Dependency injection
```swift
@Dependency(\.pdf) var pdf
try await pdf.render(html: html, to: fileUrl)
```

#### 2. Configuration

**v0.5.x:** Configuration passed as parameters
```swift
try await html.print(
    to: fileUrl,
    configuration: .a4,
    printingConfiguration: PrintingConfiguration(maxConcurrentOperations: 16)
)
```

**v0.6.0:** Configuration via dependency scoping
```swift
@Dependency(\.pdf) var pdf
try await withDependencies {
    $0.pdf.render.configuration.paperSize = .a4
    $0.pdf.render.configuration.concurrency = 16
} operation: {
    try await pdf.render(html: html, to: fileUrl)
}
```

#### 3. Type Renames

| v0.5.x | v0.6.0 |
|--------|--------|
| `PDFConfiguration` | `PDF.Configuration` |
| `PrintingConfiguration` | `PDF.Configuration` (merged) |
| `Document` | `PDF.Document` |
| `EdgeInsets` | `PDF.EdgeInsets` |

### Migration Steps

#### Step 1: Add swift-dependencies

If not already in your project:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0")
]

targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "Dependencies", package: "swift-dependencies")
        ]
    )
]
```

#### Step 2: Import Dependencies

```swift
import Dependencies  // Add this
import HtmlToPdf
```

#### Step 3: Replace String Extensions

**Option A: Quick migration** (use deprecated API with warnings)
```swift
// Keep existing code - it still works but shows deprecation warnings
try await html.print(to: fileUrl)
```

**Option B: Full migration** (recommended)
```swift
// Before
try await html.print(to: fileUrl, configuration: .a4)

// After
@Dependency(\.pdf) var pdf
try await pdf.render(html: html, to: fileUrl)
```

### Before and After Examples

#### Example 1: Single PDF

**Before (v0.5.x):**
```swift
let html = "<html><body><h1>Invoice #1234</h1></body></html>"
let url = URL.downloadsDirectory
    .appendingPathComponent("invoice.pdf")

try await html.print(to: url, configuration: .a4)
```

**After (v0.6.0):**
```swift
import Dependencies

let html = "<html><body><h1>Invoice #1234</h1></body></html>"
let url = URL.downloadsDirectory
    .appendingPathComponent("invoice.pdf")

@Dependency(\.pdf) var pdf
try await pdf.render(html: html, to: url)
```

#### Example 2: Batch PDFs

**Before (v0.5.x):**
```swift
let htmls = [
    "<html><body><h1>Invoice #1</h1></body></html>",
    "<html><body><h1>Invoice #2</h1></body></html>",
    // ...
]

try await htmls.print(
    to: .downloadsDirectory,
    configuration: .a4,
    filename: { index in "invoice-\(index + 1)" }
)
```

**After (v0.6.0):**
```swift
import Dependencies

let htmls = [
    "<html><body><h1>Invoice #1</h1></body></html>",
    "<html><body><h1>Invoice #2</h1></body></html>",
    // ...
]

@Dependency(\.pdf) var pdf

try await withDependencies {
    $0.pdf.render.configuration.namingStrategy = .custom { index in
        "invoice-\(index + 1)"
    }
} operation: {
    try await pdf.render(htmls: htmls, to: .downloadsDirectory)
}
```

#### Example 3: Custom Configuration

**Before (v0.5.x):**
```swift
let config = PDFConfiguration(
    paperSize: .letter,
    margins: .wide
)

let printConfig = PrintingConfiguration(
    maxConcurrentOperations: 16,
    documentTimeout: 30
)

try await html.print(
    to: url,
    configuration: config,
    printingConfiguration: printConfig
)
```

**After (v0.6.0):**
```swift
@Dependency(\.pdf) var pdf

try await withDependencies {
    $0.pdf.render.configuration.paperSize = .letter
    $0.pdf.render.configuration.margins = .wide
    $0.pdf.render.configuration.concurrency = 16
    $0.pdf.render.configuration.documentTimeout = .seconds(30)
} operation: {
    try await pdf.render(html: html, to: url)
}
```

#### Example 4: Type-Safe HTML (NEW in v0.6.0)

**Before (v0.5.x):**
```swift
// Only String-based HTML supported
let html = "<html><body><h1>Hello</h1></body></html>"
try await html.print(to: url)
```

**After (v0.6.0):**
```swift
// Option 1: String (same as before)
try await pdf.render(html: "<html>...</html>", to: url)

// Option 2: Type-safe HTML (NEW!)
import HTML

struct Invoice: HTMLDocument {
    let number: Int

    var head: some HTML {
        title { "Invoice #\(number)" }
    }

    var body: some HTML {
        h1 { "Invoice #\(number)" }
    }
}

try await pdf.render(html: Invoice(number: 1234), to: url)
```

#### Example 5: Streaming Results (NEW in v0.6.0)

**Before (v0.5.x):**
```swift
// Had to wait for entire batch to complete
try await htmls.print(to: directory)
```

**After (v0.6.0):**
```swift
// Process results as they complete
@Dependency(\.pdf) var pdf

for try await result in try await pdf.render(htmls: htmls, to: directory) {
    print("Generated: \(result.url.lastPathComponent)")
    print("Duration: \(result.duration)")

    // Upload to S3 immediately
    try await uploadToS3(result.url)
}
```

### FAQ

#### Q: Do I need to migrate immediately?

**A:** No. The v0.5.x API is deprecated but still works in v0.6.0. However, it will be removed in v1.0.0, so we recommend migrating when convenient.

#### Q: Why the switch to dependency injection?

**A:** Three main reasons:

1. **Testability** - You can now easily mock PDF generation in tests:
   ```swift
   try await withDependencies {
       $0.pdf.render.client = .testValue  // Mock client
   } operation: {
       // Tests run without generating real PDFs
   }
   ```

2. **Configuration scoping** - Different configurations for different parts of your app without global state

3. **Type safety** - Full Swift 6 strict concurrency support with compile-time guarantees

#### Q: Can I use both APIs in the same codebase?

**A:** Yes! The deprecated API works alongside the new API. Migrate incrementally at your own pace.

#### Q: What if I don't want to use swift-dependencies?

**A:** The new architecture requires swift-dependencies. However, the overhead is minimal:
- Zero runtime cost (compile-time only dependency injection)
- Widely adopted in the Swift community
- Excellent for testability and clean architecture

If you strongly prefer not to adopt it, you can stay on v0.5.1 until you're ready to migrate.

#### Q: Will there be a v0.7.0 with more deprecation warnings?

**A:** No. v0.6.0 is the beta release with full backward compatibility. v1.0.0 will remove the deprecated API entirely.

#### Q: How do I migrate complex configurations?

**A:** The old `PrintingConfiguration` and `PDFConfiguration` are now merged into a single `PDF.Configuration`:

```swift
// Old
PDFConfiguration(paperSize: .a4, margins: .wide, baseURL: nil)
PrintingConfiguration(maxConcurrentOperations: 16, documentTimeout: 30)

// New
try await withDependencies {
    $0.pdf.render.configuration.paperSize = .a4
    $0.pdf.render.configuration.margins = .wide
    $0.pdf.render.configuration.baseURL = nil
    $0.pdf.render.configuration.concurrency = 16
    $0.pdf.render.configuration.documentTimeout = .seconds(30)
} operation: {
    // ...
}

// Or use a preset
try await withDependencies {
    $0.pdf.render.configuration = .multiPage  // Preset for paginated output
} operation: {
    // ...
}
```

#### Q: What about AsyncStream support?

**A:** The new API returns `AsyncThrowingStream` by default for batch operations:

```swift
// v0.5.x had separate methods for streaming
try await htmls.print(to: directory)  // Fire and forget

// v0.6.0 always streams
for try await result in try await pdf.render(htmls: htmls, to: directory) {
    // Process each result as it completes
}

// Or collect all results
let results = try await Array(pdf.render(htmls: htmls, to: directory))
```

---

## Questions?

If you have questions about migration:
- **GitHub Issues:** [https://github.com/coenttb/swift-html-to-pdf/issues](https://github.com/coenttb/swift-html-to-pdf/issues)
- **Discussions:** [https://github.com/coenttb/swift-html-to-pdf/discussions](https://github.com/coenttb/swift-html-to-pdf/discussions)
- **Email:** [coen@coenttb.com](mailto:coen@coenttb.com)
