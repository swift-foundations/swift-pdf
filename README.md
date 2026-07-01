# swift-pdf

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Generates PDF documents from HTML views and Markdown authored with a Swift result-builder DSL.

---

## Key Features

- **HTML-to-PDF rendering** — Compose pages from a typed HTML view DSL (`H1`, `Paragraph`, `Table`, `UnorderedList`, …) and render them to PDF.
- **Markdown source** — Render Markdown blocks straight into a document with `Markdown { ... }`.
- **Tables** — Table rendering with `colspan`/`rowspan`, headers, footers, and captions.
- **Automatic outline** — Generate PDF bookmarks from `H1`–`H6` headings with `generateOutline: true`.
- **CSS styling** — Apply inline styles such as `.css.textAlign(...)`, `.css.color(...)`, and page-break control.
- **Atomic file writing** — Write a document to disk with `write(to:)`, optionally creating intermediate directories.
- **Single import** — `import PDF` re-exports the HTML authoring DSL, the rendering pipeline, and file-system writing.

---

## Quick Start

```swift
import PDF

let document = PDF.Document(
    info: .init(title: "Release Notes", author: "Engineering"),
    generateOutline: true
) {
    H1 { "Release Notes" }
    Paragraph {
        "Version "
        StrongImportance { "2.4.1" }
        " ships table rendering and automatic bookmarks."
    }
    UnorderedList {
        ListItem { "Tables with colspan and rowspan" }
        ListItem { "Bookmarks generated from headings" }
    }
}

try document.write(to: File("release-notes.pdf"), createIntermediates: true)
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-pdf.git", branch: "main")
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "PDF", package: "swift-pdf")
    ]
)
```

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26.

---

## Community

<!-- BEGIN: discussion -->
*Discussion thread will be created at first public flip.*
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE](LICENSE.md).
