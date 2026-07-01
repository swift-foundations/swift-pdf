> ### Heritage & migration — this repository was `swift-html-to-pdf`
>
> `swift-pdf` is the evolved successor to
> [`coenttb/swift-html-to-pdf`](https://github.com/coenttb/swift-html-to-pdf), transferred here to
> preserve its full history, tags, and stars. **swift-pdf presents a redesigned API that differs
> from html-to-pdf.**
>
> - **Staying on the original html-to-pdf API?** Pin a `1.x` version (tags `0.1.0`–`1.0.5`, e.g.
>   `from: "1.0.5"`) or track the [`html-to-pdf`](../../tree/html-to-pdf) branch — that line stays
>   maintained and receives `1.0.x` patch releases.
> - **Adopting swift-pdf?** The first swift-pdf release will be **`2.0.0`** (a clean major break).
>   See [MIGRATION.md](MIGRATION.md).
>
> Existing version-pinned dependents are unaffected — the tags `≤ 1.0.5` still resolve to the
> original html-to-pdf commits.

---

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
