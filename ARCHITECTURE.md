# swift-html-to-pdf Architecture

## Three-Target Design

Following the Point-Free pattern (similar to swift-structured-queries), this package is organized into three targets for maximum flexibility and minimal dependencies:

### 1. **HtmlToPdfTypes** - Pure Types (Dependency-Free)

**Purpose**: Core types and interfaces with NO implementation dependencies.

**Contains**:
- `PDF` namespace
- `PDF.Document` - Document model (string/bytes-based)
- `PDF.Configuration` - PDF configuration
- `PDF.Render` - Render capability struct
- `PDF.Render.Client` - Client interface (DependencyClient)
- All value types: `PaperSize`, `EdgeInsets`, `Result`, etc.

**Dependencies**: Only `swift-dependencies` for dependency injection

**Use when**: You only need types for interfaces, testing, or defining protocols.

```swift
import HtmlToPdfTypes

func processDocument(_ doc: PDF.Document) {
    // Work with document types
}
```

### 2. **HtmlToPdfLive** - WKWebView Implementation

**Purpose**: Live implementation using WebKit, **still NO swift-html dependency**.

**Contains**:
- `PDF.Render.Client+macOS` - macOS WKWebView implementation
- `PDF.Render.Client+iOS` - iOS WKWebView implementation
- `PDF+DependencyKey` - Live/test dependency values
- `PDF+Convenience.swift` - String-based convenience methods (no HTML protocol)
- `PDF.Render+Convenience.swift` - Render-level forwarding conveniences
- `PDF.Render.Client+Convenience.swift` - Client-level conveniences
- Resource pool management
- WebView lifecycle handling

**Dependencies**:
- `HtmlToPdfTypes` (re-exported)
- `swift-dependencies`
- `swift-logging-extras`
- `swift-metrics`
- `swift-resource-pool`

**Use when**: You want PDF rendering but don't need swift-html integration.

```swift
import HtmlToPdfLive

@Dependency(\.pdf) var pdf

// Works with strings or bytes - convenience methods available
try await pdf.render(html: "<html>...</html>", to: url)
```

### 3. **HtmlToPdf** - Batteries-Included + swift-html Integration

**Purpose**: Convenience umbrella that adds PointFreeHTML/swift-html integration.

**Contains**:
- `exports.swift` - Re-exports Live + PointFreeHTML
- `PDF.Document+HTML.swift` - HTML protocol extensions
- `PDF+Convenience.swift` - HTML protocol convenience methods only

**Dependencies**:
- `HtmlToPdfLive` (re-exported)
- `PointFreeHTML` (exported for convenience)

**Use when**: You want the full experience with type-safe HTML from swift-html.

```swift
import HtmlToPdf
import HTML

@Dependency(\.pdf) var pdf

let page = html {
    body {
        h1 { "Type-safe PDF" }
        p { "Generated from swift-html" }
    }
}

// HTML protocol types work seamlessly
try await pdf.render.client.document(
    PDF.Document(html: page, destination: url)
)
```

## Usage Patterns

### Pattern 1: Minimal Dependencies (Types Only)

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-html-to-pdf", from: "1.0.0")
]

targets: [
    .target(
        name: "MyPackage",
        dependencies: [
            .product(name: "HtmlToPdfTypes", package: "swift-html-to-pdf")
        ]
    )
]
```

### Pattern 2: PDF Rendering Without swift-html

```swift
dependencies: [
    .product(name: "HtmlToPdfLive", package: "swift-html-to-pdf")
]
```

```swift
import HtmlToPdfLive

try await PDF.render.client.html(
    "<html><body>String-based HTML</body></html>",
    to: outputURL
)
```

### Pattern 3: Full Integration with swift-html (Recommended ⭐)

```swift
dependencies: [
    .product(name: "HtmlToPdf", package: "swift-html-to-pdf"),
    .product(name: "HTML", package: "swift-html")
]
```

```swift
import HtmlToPdf
import HTML

let page = html {
    body {
        h1 { "Type-Safe HTML" }
        p { "Compiled at build time" }
    }
}

try await PDF.render.client.document(
    PDF.Document(html: page, destination: outputURL)
)
```

## Benefits of This Architecture

✅ **Zero-Cost Abstraction**: Users who don't import swift-html pay no cost
✅ **Flexible Integration**: Can integrate with any HTML library, not just swift-html
✅ **Testability**: Types target enables easy mocking and testing
✅ **Clear Boundaries**: Types/Implementation/Integration clearly separated
✅ **Future-Proof**: Easy to add integrations for Vapor Leaf, Plot, etc.

## Comparison to Monolithic Design

| Feature | Monolithic | Three-Target |
|---------|-----------|--------------|
| Core dependencies | PointFreeHTML required | Optional |
| Custom HTML libs | Difficult | Easy |
| Bundle size | Always includes HTML DSL | Opt-in |
| Testing | Coupled to implementation | Clean mocking |
| Maintenance | Changes ripple through | Isolated changes |

## Adding New Integrations

To integrate with another HTML library:

1. Create extension in your own code:
```swift
import HtmlToPdfTypes
import YourHTMLLibrary

extension YourHTMLType {
    func toPDFDocument(destination: URL) -> PDF.Document {
        let bytes = self.renderToBytes()
        return PDF.Document(htmlBytes: bytes, destination: destination)
    }
}
```

2. Or create a separate integration package following the same pattern.

## Migration from Pre-1.0

If upgrading from the monolithic design:

**Before:**
```swift
import HtmlToPdf  // Got everything, including PointFreeHTML
```

**After (same behavior):**
```swift
import HtmlToPdf  // Still gets everything, but now modular
```

No code changes needed! The umbrella target maintains backward compatibility.
