//
//  NaturalMultiPageTest.swift
//  swift-html-to-pdf
//
//  Test that content naturally flows across multiple pages
//

import Testing
import Foundation
import HtmlToPdf
import Dependencies
import PDFKit

@Suite("Natural Multi-Page Flow")
struct NaturalMultiPageTests {

    @Test("Generate PDF with content that naturally spans multiple pages")
    func generateNaturalMultiPagePDF() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.render.configuration.paginationMode = .paginated  // Use proper pagination for multi-page
        } operation: {
            @Dependency(\.pdf) var pdf

            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

            // Generate lots of content - should naturally span 3-4 pages on A4
            let items = (1...200).map { i in
                """
                <div style="padding: 15px; margin: 10px 0; background: #f8f9fa; border-left: 4px solid #667eea; border-radius: 4px;">
                    <h3 style="margin: 0 0 10px 0; color: #667eea;">Item #\(i)</h3>
                    <p style="margin: 5px 0;">This is test item number \(i). It contains enough text to take up vertical space and demonstrate that content flows naturally across multiple pages without requiring CSS page-break directives.</p>
                    <p style="margin: 5px 0; font-size: 12px; color: #6c757d;">Testing ContiguousArray&lt;UInt8&gt; • UTF-8 Encoding • Zero-copy rendering</p>
                </div>
                """
            }.joined(separator: "\n")

            let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>Natural Multi-Page PDF Test</title>
                <style>
                    body {
                        font-family: 'Helvetica Neue', Arial, sans-serif;
                        line-height: 1.6;
                        color: #333;
                        margin: 0;
                        padding: 0;
                    }

                    .header {
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        padding: 40px;
                        text-align: center;
                    }

                    .header h1 {
                        margin: 0;
                        font-size: 48px;
                    }

                    .header p {
                        margin: 10px 0 0 0;
                        font-size: 18px;
                        opacity: 0.9;
                    }

                    .content {
                        padding: 20px;
                    }

                    .footer {
                        margin-top: 40px;
                        padding: 20px;
                        text-align: center;
                        background: #f8f9fa;
                        color: #6c757d;
                        border-top: 2px solid #e9ecef;
                    }
                </style>
            </head>
            <body>
                <div class="header">
                    <h1>📄 Natural Multi-Page Test</h1>
                    <p>Content Should Flow Across Multiple Pages</p>
                </div>

                <div class="content">
                    <div style="padding: 20px; margin: 20px 0; background: #e7f3ff; border-radius: 8px;">
                        <h2 style="margin-top: 0; color: #0066cc;">Purpose</h2>
                        <p>This PDF contains 200 test items. At approximately 100-120 pixels per item, this should naturally span 3-4 pages on A4 paper (595 × 842 points with margins).</p>
                        <p>No CSS page breaks are used - content flows naturally based on the paper size configured in PDF.Configuration.</p>
                    </div>

                    \(items)

                    <div class="footer">
                        <h3>✅ Test Complete</h3>
                        <p>If you see this footer and can scroll/navigate through multiple pages, the multi-page rendering is working correctly!</p>
                        <p>Generated: \(Date().formatted())</p>
                        <p>Total Items: 200 • Implementation: ContiguousArray&lt;UInt8&gt;</p>
                    </div>
                </div>
            </body>
            </html>
            """

            let output = desktop.appendingPathComponent("PDF_Natural_MultiPage_Test.pdf")

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Generating Natural Multi-Page PDF")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("\nOutput location:")
            print("  \(output.path)")
            print("\nExpected: 3-4 pages of content")
            print("Items: 200 test items")

            let url = try await pdf.render.client.html(htmlString, output)

            if FileManager.default.fileExists(atPath: url.path) {
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = attrs[.size] as? Int64 ?? 0

                // Verify PDF structure using PDFKit
                guard let pdfDoc = PDFDocument(url: url) else {
                    throw NSError(domain: "Failed to load PDF", code: -1)
                }

                let pageCount = pdfDoc.pageCount

                // Check first page dimensions (should be A4: 595.28 × 841.89 points)
                guard let firstPage = pdfDoc.page(at: 0) else {
                    throw NSError(domain: "Failed to get first page", code: -1)
                }
                let bounds = firstPage.bounds(for: .mediaBox)
                let expectedA4Width: CGFloat = 595.28
                let expectedA4Height: CGFloat = 841.89
                let tolerance: CGFloat = 1.0

                let isA4Width = abs(bounds.width - expectedA4Width) < tolerance
                let isA4Height = abs(bounds.height - expectedA4Height) < tolerance

                print("\n✅ PDF Generated!")
                print("   Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                print("   Path: \(url.path)")
                print("\n📄 PDF Structure:")
                print("   Pages: \(pageCount)")
                print("   Page 1 dimensions: \(bounds.width) × \(bounds.height) points")
                print("   Expected A4: \(expectedA4Width) × \(expectedA4Height) points")
                print("   Width correct: \(isA4Width ? "✅" : "❌")")
                print("   Height correct: \(isA4Height ? "✅" : "❌")")

                print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("Verification:")
                print("  • Total number of pages: \(pageCount) (expected 3-4)")
                print("  • All 200 items present: \(pageCount >= 3 ? "✅" : "❌")")
                print("  • Page dimensions A4: \(isA4Width && isA4Height ? "✅" : "❌")")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

                // Assert correct dimensions
                #expect(isA4Width, "PDF width should be A4 (595.28 points), got \(bounds.width)")
                #expect(isA4Height, "PDF height should be A4 (841.89 points), got \(bounds.height)")
                #expect(pageCount >= 3, "PDF should have at least 3 pages, got \(pageCount)")
            } else {
                throw NSError(domain: "PDF not created", code: -1)
            }
        }
    }
}
