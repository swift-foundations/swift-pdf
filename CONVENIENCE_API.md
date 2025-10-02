# Convenience API Levels

The swift-html-to-pdf API provides three levels of convenience, allowing you to choose the right balance between brevity and explicitness.

## Quick Reference

```swift
@Dependency(\.pdf) var pdf

// Level 1: Shortest (top-level convenience)
try await pdf.html(html, to: url)
try await pdf.documents(docs)

// Level 2: Mid-level (capability-focused)
try await pdf.render.html(html, url)
try await pdf.render.documents(docs)
try await pdf.render.html(htmls, to: dir)

// Level 3: Explicit (full control)
try await pdf.render.client.html(html, url)
try await pdf.render.client.documents(docs)
try await pdf.render.client.html(htmls, to: dir)
```

## Level 1: Top-Level Convenience (Shortest)

**Best for:** Quick scripts, simple use cases, minimalist code

```swift
@Dependency(\.pdf) var pdf

// Single HTML to file
let url = try await pdf.html(html, to: destination)

// In-memory data
let data = try await pdf.data(html)

// Documents with stream
for try await result in try await pdf.documents(documents) {
    print("Generated: \(result.url)")
}
```

**Implementation:** Forwards through `PDF` → `PDF.Render` → `PDF.Render.Client`

## Level 2: Capability-Level Convenience (Mid-Level)

**Best for:** Production code, showing domain structure, good balance

```swift
@Dependency(\.pdf) var pdf

// Single HTML to file
let url = try await pdf.render.html(html, destination)

// In-memory data
let data = try await pdf.render.data(html)

// HTML batch rendering (stream)
for try await result in try await pdf.render.html(htmls, to: directory) {
    print("Generated: \(result.url)")
}

// Documents with stream
for try await result in try await pdf.render.documents(documents) {
    print("Generated: \(result.url)")
}

// Single document
let url = try await pdf.render.document(document)

// Platform capabilities
let caps = pdf.render.capabilities()
```

**Implementation:** Forwards through `PDF.Render` → `PDF.Render.Client`

**Benefits:**
- Shows the capability structure (`render`)
- Still convenient (no `.client` needed)
- Prepares for future router: `pdf.render.router`

## Level 3: Explicit Client Access (Full Control)

**Best for:** Advanced use cases, dependency injection, testing, maximum clarity

```swift
@Dependency(\.pdf) var pdf

// Single HTML to file
let url = try await pdf.render.client.html(html, destination)

// In-memory data
let data = try await pdf.render.client.data(html)

// HTML batch rendering (stream)
for try await result in try await pdf.render.client.html(htmls, to: directory) {
    print("Generated: \(result.url)")
}

// Documents with stream
for try await result in try await pdf.render.client.documents(documents) {
    print("Generated: \(result.url)")
}

// Single document
let url = try await pdf.render.client.document(document)

// Platform capabilities
let caps = pdf.render.client.capabilities()
```

**Implementation:** Direct access to `PDF.Render.Client`

**Benefits:**
- Explicit about using client
- Easy to mock in tests: `$0.pdf.render.client = mockClient`
- Clear separation of concerns
- Follows domain-first architecture pattern

## Configuration

Configuration is accessed at the capability level regardless of which convenience level you use:

```swift
try await withDependencies {
    $0.pdf.render.configuration.paperSize = .letter
    $0.pdf.render.configuration.margins = .wide
    $0.pdf.render.configuration.concurrency = 8
} operation: {
    // Use any convenience level here
    try await pdf.html(html, to: url)
}
```

## Collecting Streams into Arrays

All batch methods return `AsyncThrowingStream<PDF.Result, Error>` for progressive processing. If you need all URLs collected into an array, use standard Swift patterns:

```swift
// Collect stream into array
var urls: [URL] = []
for try await result in try await pdf.render.client.html(htmls, to: directory) {
    urls.append(result.url)
}

// Or using reduce
let urls = try await pdf.render.client.html(htmls, to: directory)
    .reduce(into: [] as [URL]) { $0.append($1.url) }
```

**Benefits of streams:**
- **Progress tracking**: Process results as they complete
- **Early error handling**: Handle errors incrementally
- **Memory efficiency**: No need to hold all results in memory
- **Responsiveness**: Start processing PDFs immediately

## Choosing the Right Level

| Level | Use When | Example |
|-------|----------|---------|
| **1: Top-level** | Quick scripts, simple one-liners | `pdf.html(html, to: url)` |
| **2: Capability** | Production code, showing structure | `pdf.render.html(html, url)` |
| **3: Explicit** | Tests, mocking, maximum clarity | `pdf.render.client.html(html, url)` |

## Progressive Disclosure

Start with Level 1 for simplicity:
```swift
try await pdf.html(html, to: url)
```

As your needs grow, move to Level 2 to show capability:
```swift
try await pdf.render.html(html, url)
```

For testing or advanced scenarios, use Level 3 for explicit control:
```swift
try await pdf.render.client.html(html, url)
```

All three levels compile to the same code and have identical performance.

## Architecture Benefits

This three-level approach provides:

1. **Progressive disclosure** - Beginners start simple, experts get control
2. **Domain-first structure** - Shows business capability (`render`)
3. **Future-proof** - Ready for router: `pdf.render.router`
4. **Testability** - Easy to mock: `$0.pdf.render.client = mockClient`
5. **Consistency** - Follows swift-identities-types pattern

## Complete Example

```swift
import Dependencies
import HtmlToPdf

@Dependency(\.pdf) var pdf

// Configure once
try await withDependencies {
    $0.pdf.render.configuration.paperSize = .letter
    $0.pdf.render.configuration.margins = .wide
} operation: {

    // Level 1: Quick and simple
    let url1 = try await pdf.html("<html>...</html>", to: fileURL)

    // Level 2: Shows structure
    let url2 = try await pdf.render.html("<html>...</html>", fileURL)

    // Level 3: Explicit control
    let url3 = try await pdf.render.client.html("<html>...</html>", fileURL)

    // All three produce the same result
    assert(url1.absoluteString == url2.absoluteString)
    assert(url2.absoluteString == url3.absoluteString)
}
```
