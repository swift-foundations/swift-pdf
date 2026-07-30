# ``PDF``

@Metadata {
    @DisplayName("PDF")
    @TitleHeading("Swift Foundations")
}

The umbrella import for PDF generation: re-exports `HTML` (for building a
PDF from HTML-and-CSS content, including Markdown-to-HTML rendering) and
`PDF Rendering` (for direct, low-level PDF composition with `PDF.View` and
`@PDF.Builder`, with no HTML involved), plus `File System` and `Kernel` for
writing the result to disk.

## When to use this

`import PDF` is the default entry point and pulls in the whole stack;
reach for it unless a narrower import is specifically needed. Import `HTML`
alone when only the HTML-to-PDF path is used and the direct rendering API
is not needed; import `PDF Rendering` alone when composing a PDF directly
with `PDF.View`/`@PDF.Builder` and HTML is not involved at all.

## Topics

### Related packages

- [swift-pdf-html-render](https://github.com/swift-foundations/swift-pdf-html-render) —
  the HTML-to-PDF rendering layer this package re-exports.
- [swift-pdf-render](https://github.com/swift-foundations/swift-pdf-render) —
  the direct, low-level `PDF.View`/`@PDF.Builder` composition layer this
  package re-exports.
- [swift-html](https://github.com/swift-foundations/swift-html) — the HTML
  builder used to compose PDF content from HTML and CSS.
