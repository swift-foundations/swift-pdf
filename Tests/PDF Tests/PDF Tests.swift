// PDF Tests.swift

import Foundation
import PDF
import Testing

extension PDF {
    enum Test {
        @Suite struct Unit {}
    }
}

// MARK: - Markdown to PDF Tests

extension PDF.Test.Unit {
    @Suite
    struct `Markdown to PDF` {

        @Test
        func `Basic markdown renders to PDF`() throws {
            let doc = PDF.Document(
                info: .init(
                    title: "Markdown Demo",
                    author: "Test Suite"
                ),
                generateOutline: true
            ) {
                Markdown {
                    """
                    # Welcome to Markdown PDF

                    This document demonstrates **Markdown to PDF** rendering.

                    ## Features

                    - Bold and *italic* text
                    - Lists (ordered and unordered)
                    - Code blocks
                    - And much more!

                    ### Code Example

                    Here's some inline `code` and a code block:

                    ```swift
                    let greeting = "Hello, World!"
                    print(greeting)
                    ```

                    ## Conclusion

                    Markdown makes document creation simple and readable.
                    """
                }
            }

            try doc.write(
                to: File("/tmp/swift-pdf/markdown-to-pdf-test.pdf"),
                createIntermediates: true
            )

            #expect(doc.pages.count >= 1)
            #expect(doc.outline != nil, "Document should have outline from markdown headings")
        }

        @Test
        func `Markdown with tables renders to PDF`() throws {
            let doc = PDF.Document(
                info: .init(
                    title: "Markdown Table Demo",
                    author: "Test Suite"
                )
            ) {
                Markdown {
                    """
                    # Product Catalog

                    Here's our current inventory:

                    | Product | Price | Stock |
                    |---------|-------|-------|
                    | Widget A | $10.00 | 100 |
                    | Widget B | $15.00 | 50 |
                    | Widget C | $20.00 | 25 |

                    ## Notes

                    - Prices subject to change
                    - Stock updated daily
                    """
                }
            }

            #expect(doc.pages.count >= 1)

            try doc.write(
                to: File("/tmp/swift-pdf/markdown-table-to-pdf-test.pdf"),
                createIntermediates: true
            )
        }

        @Test
        func `Complex markdown document renders to PDF`() throws {

            let doc = PDF.Document(
                info: .init(
                    title: "Technical Documentation",
                    author: "Test Suite"
                ),
                generateOutline: true
            ) {
                Markdown {
                    """
                    # Swift PDF Library Documentation

                    ## Overview

                    The **swift-pdf** library provides a pure Swift implementation for generating PDF documents from HTML content.

                    ### Key Features

                    1. **HTML to PDF conversion** - Transform HTML views into PDF documents
                    2. **Markdown support** - Write content in Markdown and render to PDF
                    3. **Table support** - Full support for tables with rowspan/colspan
                    4. **Outline generation** - Automatic bookmark generation from headings

                    ## Installation

                    Add the following to your `Package.swift`:

                    ```swift
                    dependencies: [
                        .package(url: "https://github.com/coenttb/swift-pdf", from: "1.0.0")
                    ]
                    ```

                    ## Quick Start

                    ### Creating a Simple Document

                    ```swift
                    import PDF

                    let doc = PDF.Document {
                        H1 { "Hello, PDF!" }
                        Paragraph { "This is my first PDF document." }
                    }

                    try doc.write(to: "output.pdf")
                    ```

                    ### Using Markdown

                    ```swift
                    let markdown = Markdown()

                    let doc = PDF.Document {
                        markdown {
                            \"\"\"
                            # My Document

                            Written in **Markdown**!
                            \"\"\"
                        }
                    }
                    ```

                    ## API Reference

                    ### PDF.Document

                    The main entry point for creating PDF documents.

                    | Method | Description |
                    |--------|-------------|
                    | `init(info:generateOutline:content:)` | Create a new document |
                    | `write(to:)` | Write document to file |
                    | `pages` | Access generated pages |
                    | `outline` | Access document outline |

                    ## Conclusion

                    For more information, visit the [GitHub repository](https://github.com/coenttb/swift-pdf).
                    """
                }
            }

            try doc.write(
                to: File("/tmp/swift-pdf/markdown-complex-to-pdf-test.pdf"),
                createIntermediates: true
            )

            #expect(doc.pages.count >= 1)
            #expect(doc.outline != nil, "Document should have outline")
        }
    }
}
