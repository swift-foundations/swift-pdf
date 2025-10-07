//
//  HTMLDSLExamplesTests.swift
//  swift-html-to-pdf
//
//  Tests that verify the HTML DSL examples work correctly with PDF generation
//

import Testing
import HtmlToPdf
import Foundation
import Dependencies
import PDFTestSupport

#if HTML
import HTML

@Suite("HTML DSL Examples")
struct HTMLDSLExamplesTests {

    // MARK: - Simple Invoice Example

    @Test("Simple Invoice HTML DSL renders to PDF")
    func simpleInvoiceExample() async throws {
        @Dependency(\.pdf) var pdf

        let invoiceHTML = HTMLDocument {
            h1 { "Invoice #1234" }
            p { "Total: $99.99" }
        } head: {
            title { "Invoice #1234" }
        }

        try await withTemporaryDirectory { tempDir in
            let url = tempDir.appendingPathComponent("invoice.pdf")
            let result = try await pdf.render(html: invoiceHTML, to: url)

            // Verify PDF was created
            #expect(FileManager.default.fileExists(atPath: result.path))
        }
    }

    // MARK: - Invoice with Styling
    @Test("Invoice with CSS styling renders")
    func styledInvoiceExample() async throws {
        @Dependency(\.pdf) var pdf

        let invoiceHTML = HTMLDocument {
            h1 { "Invoice #1234" }
                .color(.hex("#333"))
            p { "Thank you for your business!" }
            p { "Total: $99.99" }
        } head: {
            title { "Invoice #1234" }
            style { """
                body { font-family: system-ui; padding: 20px; }
                """
            }
        }

        try await withTemporaryDirectory { tempDir in
            let url = tempDir.appendingPathComponent("styled-invoice.pdf")
            let result = try await pdf.render(html: invoiceHTML, to: url)

            #expect(FileManager.default.fileExists(atPath: result.path))
        }
    }
}
#endif
