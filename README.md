# swift-pdf

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Generates PDF documents from HTML views and Markdown authored with a Swift result-builder DSL.

> ### Heritage & migration — this repository was `swift-html-to-pdf`
>
> `swift-pdf` is the evolved successor to
> [`coenttb/swift-html-to-pdf`](https://github.com/coenttb/swift-html-to-pdf), transferred here to
> preserve its full history, tags, and stars. **swift-pdf presents a redesigned API that differs
> from html-to-pdf.** See [Migration & versioning](#migration--versioning).
>
> - **Staying on the original html-to-pdf API?** Pin a `1.x` version (tags `0.1.0`–`1.0.5`, e.g.
>   `from: "1.0.5"`) or track the [`html-to-pdf`](../../tree/html-to-pdf) branch — that line stays
>   maintained and receives `1.0.x` patch releases.
> - **Adopting swift-pdf?** The first swift-pdf release will be **`2.0.0`** (a clean major break).
>
> Existing version-pinned dependents are unaffected — the tags `≤ 1.0.5` still resolve to the
> original html-to-pdf commits.

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
Discuss this package: [swift-institute/discussions/38](https://github.com/orgs/swift-institute/discussions/38)
<!-- END: discussion -->

## Status & maintainer

This package is public alpha: the redesigned swift-pdf API on `main` is unreleased and will first ship as `2.0.0`; interfaces may change until then. See [Migration & versioning](#migration--versioning) for the maintained html-to-pdf `1.x` line.

Maintained by [Coen ten Thije Boonkkamp](https://github.com/coenttb) — available for Swift infrastructure and document-systems consulting: coen@coenttb.com.

## License

Apache 2.0. See [LICENSE](LICENSE.md).

---

## Migration & versioning

`swift-pdf` is the evolved successor to
[`coenttb/swift-html-to-pdf`](https://github.com/coenttb/swift-html-to-pdf), transferred into Swift
Institute to preserve the original's full history, tags, and stars. **The API differs** — swift-pdf
is a redesign, not a drop-in update.

### Staying on html-to-pdf (no migration needed)

The original API is preserved and remains maintainable:

- **Pin a 1.x version** (tags `0.1.0`–`1.0.5`):
  ```swift
  .package(url: "https://github.com/swift-foundations/swift-pdf.git", from: "1.0.5")
  ```
- **or track the maintenance branch:**
  ```swift
  .package(url: "https://github.com/swift-foundations/swift-pdf.git", branch: "html-to-pdf")
  ```

Bug-fix releases for the old API are cut as `1.0.x` on the `html-to-pdf` branch. The entire `1.x`
range is reserved for html-to-pdf, so `.upToNextMajor(from: "1.0.x")` will never pull the new
swift-pdf API by accident.

### Moving to swift-pdf

- The first swift-pdf release will be **`2.0.0`** — a deliberate major break signalling the new API.
- **API mapping:** _pending_ — the full old→new mapping will be added by a focused migration pass
  over both codebases.

### Version guardrail (maintainers)

```
main             = swift-pdf    (new API, releases >= 2.0.0)
html-to-pdf      = original API (maintenance, releases 1.0.x)
tags 0.1.0–1.0.5 = original html-to-pdf commits (immutable)
```

The entire `1.x` range is **reserved** for html-to-pdf. **Never cut a `1.x` tag on `main`** — it
would collide with the html-to-pdf line and silently auto-upgrade `.upToNextMajor(from: "1.0.x")`
consumers into the incompatible new API. The first swift-pdf release on `main` **must be `2.0.0` or
higher.**
