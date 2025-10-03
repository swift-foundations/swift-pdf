# Getting Started

Learn how to integrate HtmlToPdf into your project and generate your first PDF.

## Installation

Add HtmlToPdf to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-html-to-pdf.git", from: "1.0.0")
]
```

Then add it to your target dependencies:

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

## Basic Usage

### Single PDF Generation

The simplest way to generate a PDF:

```swift
import HtmlToPdf
import Dependencies

@Dependency(\.pdf) var pdf

// Generate a PDF from HTML string
try await pdf.render(
    html: "<html><body><h1>Hello, World!</h1></body></html>",
    to: fileURL
)
```

### Using Type-Safe HTML

For better type safety, use the HTML DSL:

```swift
import PointFreeHTML

struct MyPage: HTML {
    var body: some HTML {
        html {
            head {
                title { "My PDF Document" }
            }
            body {
                h1 { "Hello, World!" }
                p { "This is a type-safe PDF document." }
            }
        }
    }
}

try await pdf.render(html: MyPage(), to: fileURL)
```

### Batch Processing

Generate multiple PDFs efficiently:

```swift
let htmls = [
    "<html><body><h1>Document 1</h1></body></html>",
    "<html><body><h1>Document 2</h1></body></html>",
    "<html><body><h1>Document 3</h1></body></html>"
]

for try await result in try await pdf.render(htmls: htmls, to: directory) {
    print("Generated \(result.url.lastPathComponent) in \(result.duration)")
}
```

### Resilient Batch Processing

Continue processing on errors:

```swift
let documents = /* ... your documents ... */

for await result in await pdf.render.client.documentsResilient(documents) {
    switch result {
    case .success(let pdf):
        print("✅ Success: \(pdf.url.lastPathComponent)")
    case .failure(let failed):
        print("❌ Failed: \(failed.document.destination.lastPathComponent)")
        print("   Error: \(failed.error.localizedDescription)")
    }
}
```

## Configuration

### Using Presets

```swift
try await withDependencies {
    $0.pdf.render.configuration = .platformOptimized
} operation: {
    @Dependency(\.pdf) var pdf
    try await pdf.render(html: html, to: fileURL)
}
```

### Custom Configuration

```swift
try await withDependencies {
    $0.pdf.render.configuration.paperSize = .letter
    $0.pdf.render.configuration.margins = .wide
    $0.pdf.render.configuration.paginationMode = .paginated
} operation: {
    @Dependency(\.pdf) var pdf
    try await pdf.render(html: html, to: fileURL)
}
```

## Next Steps

- Read the <doc:PerformanceGuide> to optimize for your use case
- Explore <doc:ConfigurationGuide> for advanced options
- Learn about pagination modes in ``PDF/PaginationMode``
