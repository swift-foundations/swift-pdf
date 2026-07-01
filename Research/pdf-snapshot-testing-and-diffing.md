# PDF Snapshot Testing and Diffing

<!--
---
version: 1.0.0
last_updated: 2026-03-13
status: RECOMMENDATION
---
-->

## Context

The swift-pdf package currently tests PDF output by writing files to `/tmp/swift-pdf/` and relying on manual visual inspection. There is no automated regression detection — if rendering regresses, it's only caught by a human opening the file. The swift-testing snapshot infrastructure (`#snapshot`, `Strategy`, `Diffing`, recording modes) already supports binary data via `.data` strategy, and custom strategies via `pullback` and custom `Diffing<Format>`. The question is how to leverage this for PDF testing, and whether meaningful PDF-specific diffing (beyond byte comparison) is achievable.

## Question

How should PDF output be snapshot-tested, and what level of diffing is practical?

## Analysis

### Layer 1: Binary PDF Snapshots (Works Today)

The existing `.data` strategy stores `[UInt8]` with `.bin` extension. A custom strategy for PDF is straightforward:

```swift
extension Test.Snapshot.Strategy where Value == PDF.Document, Format == [UInt8] {
    static var pdf: Self {
        Strategy<[UInt8], [UInt8]>.data.pullback { document in
            [UInt8](document)  // Binary.Serializable
        }
    }
}
```

This gives:
- **Snapshot recording**: Reference `.pdf` files committed in `__Snapshots__/`
- **Byte-level diffing**: Reports "Binary content differs at offset N, size old vs new"
- **Recording modes**: `.missing` for CI, `.all` for re-baselining after intentional changes

**Limitation**: PDF binary output is non-deterministic across runs for several reasons:
- Creation/modification dates in document info
- Object IDs and cross-reference table offsets shift with any content change
- Font subsetting order may vary

**Mitigation**: Either (a) strip volatile metadata before comparison, or (b) use deterministic document info (fixed dates, no random IDs). Option (b) is simpler — pass fixed `PDF.Document.Info` in tests.

### Layer 2: Page-Count and Structural Assertions

A middle ground between byte comparison and visual diffing — assert on structural properties:

```swift
extension Test.Snapshot.Strategy where Value == PDF.Document, Format == String {
    static var pdfStructure: Self {
        Strategy<String, String>.lines.pullback { document in
            var lines: [String] = []
            lines.append("Pages: \(document.pages.count)")
            for (i, page) in document.pages.enumerated() {
                lines.append("Page \(i + 1): \(page.contentStream.data.count) bytes")
            }
            if let outline = document.outline {
                lines.append("Outline: \(outline.items.count) top-level items")
            }
            return lines.joined(separator: "\n")
        }
    }
}
```

This catches:
- Page count changes (the section 6.5 bug: 2 pages → 12 pages)
- Dramatic content size changes per page
- Outline structure changes

Uses `.lines` diffing so failures show exactly which page changed.

### Layer 3: Visual (Pixel) Diffing

Render each PDF page to an image, then compare pixels. Three sub-options:

#### Option A: ImageMagick CLI (available now)

ImageMagick `convert` and `compare` are already installed at `/opt/homebrew/bin/`.

```bash
# Render PDF pages to PNG
convert -density 150 reference.pdf page-ref-%d.png
convert -density 150 actual.pdf page-act-%d.png

# Compare with metric (returns non-zero on difference)
compare -metric AE page-ref-0.png page-act-0.png diff-0.png
```

A Swift wrapper would shell out to these commands and parse the output.

**Pros**: Already installed, industry-standard, generates visual diff images.
**Cons**: Shell dependency, slow (spawns processes), ImageMagick PDF rendering uses Ghostscript (may need separate install for PDF→image).

#### Option B: PDFKit + AppKit (macOS-native)

```swift
import PDFKit
import AppKit

func renderPage(_ pdfData: [UInt8], pageIndex: Int, scale: CGFloat = 2.0) -> [UInt8]? {
    let doc = PDFDocument(data: Data(pdfData))
    guard let page = doc?.page(at: pageIndex) else { return nil }
    let bounds = page.bounds(for: .mediaBox)
    let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
    let image = page.thumbnail(of: size, for: .mediaBox)
    return image.tiffRepresentation.flatMap {
        NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
    }.map { [UInt8]($0) }
}
```

Then compare rendered PNGs pixel-by-pixel:

```swift
func pixelDiff(_ a: [UInt8], _ b: [UInt8]) -> (identical: Bool, diffPercent: Double, diffImage: [UInt8]?) {
    // Compare pixel buffers, generate diff overlay
}
```

**Pros**: Native macOS, high-quality rendering, no external dependencies.
**Cons**: Requires Foundation/AppKit (forbidden in primitives/standards, fine at Layer 3+). Only works on macOS. PDFKit rendering may differ slightly from Preview.app.

#### Option C: CoreGraphics (lower-level, no AppKit)

Use `CGPDFDocument` + `CGBitmapContext` directly. More code, same result as Option B but without AppKit dependency. Still requires CoreGraphics (Darwin-only).

### Comparison

| Criterion | L1: Binary | L2: Structural | L3A: ImageMagick | L3B: PDFKit |
|-----------|-----------|---------------|-------------------|-------------|
| Catches byte-level changes | Yes | No | No | No |
| Catches page count regression | No (offset shift) | Yes | Yes | Yes |
| Catches visual regression | No | No | Yes | Yes |
| False positives from metadata | High | None | None | None |
| External dependencies | None | None | ImageMagick + GS | Foundation + AppKit |
| Works in swift-testing | Yes | Yes | Via Bash | Yes |
| CI-friendly | Yes | Yes | Needs ImageMagick | macOS runners only |
| Diff output quality | "offset N differs" | Line diff | Visual diff image | Visual diff image |
| Implementation effort | Trivial | Low | Medium | Medium |

### Recommended Approach: L2 + L3B Combined

**Layer 2 (structural)** catches the class of bugs we've been fixing (page count explosion, blank pages, missing content). It's fast, deterministic, and produces clear diffs. This should be the primary snapshot strategy.

**Layer 3B (PDFKit visual)** catches rendering regressions that structural tests miss (wrong font size, misaligned columns, incorrect colors). Since swift-pdf is already at Layer 3 (foundations) and tests can freely use Foundation, PDFKit is the natural fit. Visual snapshots are the gold standard but slower — run them as a separate snapshot suite.

**Layer 1 (binary)** is not recommended as a primary strategy due to metadata non-determinism. It's useful only if you need to assert exact byte-level reproducibility (unlikely for rendering).

## Outcome

**Status**: RECOMMENDATION

### Immediate (works with current infrastructure)

1. **Add `PDF Snapshot Tests` target** to `Tests/Testing/Package.swift`
2. **Create structural strategy** (`Strategy<PDF.Document, String>.pdfStructure`) — pullback on `.lines`
3. **Snapshot each test document** with `.pdfStructure` — page count, content sizes, outline
4. **Commit `__Snapshots__/` reference files** — any future page count regression fails the test

### Next Phase (new infrastructure)

5. **Create visual strategy** using PDFKit — render pages to PNG, compare pixel-by-pixel
6. **Custom `Diffing<[UInt8]>`** that reports pixel difference percentage and generates a visual diff PNG
7. **Threshold-based pass/fail** — e.g., <0.1% pixel difference passes (handles anti-aliasing jitter)
8. **Per-page snapshots** — one reference PNG per page, so diffs pinpoint the exact page

### Extension: PDF Content Stream Diffing

A PDF-specific innovation beyond what general tools offer — diff the content stream operators rather than pixels or bytes:

```swift
// Hypothetical: parse content stream back to operators and diff as text
extension Test.Snapshot.Strategy where Value == PDF.Document, Format == String {
    static var pdfContentStream: Self {
        Strategy<String, String>.lines.pullback { document in
            document.pages.enumerated().map { (i, page) in
                "--- Page \(i + 1) ---\n" + page.contentStream.disassemble()
            }.joined(separator: "\n\n")
        }
    }
}
```

This would show exactly which PDF operators changed (text positioning, font switches, line drawing). Requires a content stream disassembler — non-trivial but very powerful for debugging rendering changes.

## References

- `swift-test-primitives/Sources/Test Snapshot Primitives/` — Strategy, Diffing, Recording primitives
- `swift-tests/Sources/Tests Inline Snapshot/snapshot.swift` — `snapshot()` function API
- `swift-tests/Sources/Tests Snapshot/Test.Snapshot.Storage.swift` — File-backed snapshot I/O
- `swift-pdf/Tests/Testing/` — Existing nested testing package (performance tests only)
- `swift-iso-32000/Sources/ISO 32000/ISO_32000.Writer.swift` — PDF serialization
