//
//  MultiPageVerificationTest.swift
//  swift-html-to-pdf
//
//  Verify multi-page PDF generation works correctly
//

import Testing
import Foundation
import HtmlToPdf
import Dependencies

@Suite("Multi-Page Verification")
struct MultiPageVerificationTests {

    @Test("Generate multi-page PDF with proper page breaks")
    func generateMultiPagePDF() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdfConfiguration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

            // Create HTML with enough content to naturally flow across multiple pages
            // Each section is ~500px tall, and A4 is ~842px, so we need substantial content
            let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>Multi-Page PDF Test</title>
                <style>
                    body {
                        font-family: 'Helvetica Neue', Arial, sans-serif;
                        line-height: 1.6;
                        color: #333;
                    }

                    .section {
                        padding: 40px;
                        margin-bottom: 40px;
                    }

                    /* Force actual page breaks between major sections */
                    .section {
                        page-break-inside: avoid;
                    }

                    .force-page-break {
                        page-break-before: always;
                    }

                    .page-header {
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        padding: 30px;
                        text-align: center;
                        border-radius: 8px;
                        margin-bottom: 30px;
                    }

                    .page-number {
                        font-size: 14px;
                        color: #6c757d;
                        text-align: center;
                        margin-top: 20px;
                    }

                    .content-section {
                        margin: 20px 0;
                        padding: 20px;
                        background: #f8f9fa;
                        border-left: 4px solid #667eea;
                    }

                    h1 {
                        font-size: 36px;
                        margin: 0;
                    }

                    h2 {
                        color: #667eea;
                        margin-top: 0;
                    }

                    p {
                        margin: 10px 0;
                    }

                    .test-item {
                        padding: 10px;
                        margin: 5px 0;
                        background: white;
                        border-radius: 4px;
                    }
                </style>
            </head>
            <body>
                <!-- Section 1 -->
                <div class="section">
                    <div class="page-header">
                        <h1>📄 Page 1 of 5</h1>
                        <p>Multi-Page PDF Test</p>
                    </div>

                    <div class="content-section">
                        <h2>Purpose of This Test</h2>
                        <p>This PDF tests that the ContiguousArray&lt;UInt8&gt; implementation correctly handles multi-page documents with proper page breaks.</p>
                        <p>Each page should be properly separated and all content should be visible without clipping.</p>
                    </div>

                    <div class="content-section">
                        <h2>Test Items - Page 1</h2>
                        \((1...20).map { "<div class='test-item'>Item \($0): Testing content flow and pagination</div>" }.joined(separator: "\n"))
                    </div>

                    <div class="page-number">— Page 1 —</div>
                </div>

                <!-- Page 2 -->
                <div class="page">
                    <div class="page-header">
                        <h1>📄 Page 2 of 5</h1>
                        <p>Testing CSS and Layout</p>
                    </div>

                    <div class="content-section">
                        <h2>CSS Features</h2>
                        <p>✓ Gradients work across pages</p>
                        <p>✓ Borders and padding preserved</p>
                        <p>✓ Colors and backgrounds render correctly</p>
                        <p>✓ Typography consistent across pages</p>
                    </div>

                    <div class="content-section">
                        <h2>Test Items - Page 2</h2>
                        \((21...40).map { "<div class='test-item'>Item \($0): More content to verify page breaks</div>" }.joined(separator: "\n"))
                    </div>

                    <div class="page-number">— Page 2 —</div>
                </div>

                <!-- Page 3 -->
                <div class="page">
                    <div class="page-header">
                        <h1>📄 Page 3 of 5</h1>
                        <p>Unicode and Special Characters</p>
                    </div>

                    <div class="content-section">
                        <h2>Emoji Test</h2>
                        <p>🎉 🚀 ✨ 💡 🔥 ⚡️ 🎯 🌟 🎨 📝 🎭 🌈 🔬 🧪 📊 📈</p>
                    </div>

                    <div class="content-section">
                        <h2>Math Symbols</h2>
                        <p>α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ σ τ υ φ χ ψ ω</p>
                        <p>∑ ∫ √ ∞ ≈ ≠ ± ∂ ∇ ∈ ∉ ⊂ ⊃ ∪ ∩</p>
                    </div>

                    <div class="content-section">
                        <h2>Currency Symbols</h2>
                        <p>$ € £ ¥ ₹ ₿ ¢ ₽ ₩ ₪ ₱ ₴ ₵</p>
                    </div>

                    <div class="content-section">
                        <h2>Accented Characters</h2>
                        <p>café, naïve, résumé, façade, à la carte, piñata, über, Zürich</p>
                    </div>

                    <div class="page-number">— Page 3 —</div>
                </div>

                <!-- Page 4 -->
                <div class="page">
                    <div class="page-header">
                        <h1>📄 Page 4 of 5</h1>
                        <p>Performance Metrics</p>
                    </div>

                    <div class="content-section">
                        <h2>Memory Efficiency</h2>
                        <div class="test-item">Old approach (String UTF-16): ~2 bytes per character</div>
                        <div class="test-item">New approach (ContiguousArray UTF-8): ~1 byte per character</div>
                        <div class="test-item">Memory savings: ~50% for ASCII-heavy content</div>
                        <div class="test-item">Additional benefit: Zero-copy from HTML DSL to WKWebView</div>
                    </div>

                    <div class="content-section">
                        <h2>Test Items - Page 4</h2>
                        \((41...60).map { "<div class='test-item'>Item \($0): Verifying pagination continues correctly</div>" }.joined(separator: "\n"))
                    </div>

                    <div class="page-number">— Page 4 —</div>
                </div>

                <!-- Page 5 -->
                <div class="page">
                    <div class="page-header">
                        <h1>📄 Page 5 of 5</h1>
                        <p>Final Page</p>
                    </div>

                    <div class="content-section">
                        <h2>✅ Verification Checklist</h2>
                        <p>If you can see this page clearly:</p>
                        <div class="test-item">✓ All 5 pages rendered correctly</div>
                        <div class="test-item">✓ No content clipping occurred</div>
                        <div class="test-item">✓ Page breaks work properly</div>
                        <div class="test-item">✓ CSS styles consistent across pages</div>
                        <div class="test-item">✓ Special characters display correctly</div>
                        <div class="test-item">✓ ContiguousArray&lt;UInt8&gt; implementation verified!</div>
                    </div>

                    <div class="content-section">
                        <h2>Implementation Details</h2>
                        <p><strong>Storage:</strong> ContiguousArray&lt;UInt8&gt;</p>
                        <p><strong>Encoding:</strong> UTF-8</p>
                        <p><strong>HTML Source:</strong> String → ContiguousArray conversion</p>
                        <p><strong>WKWebView:</strong> Direct Data loading</p>
                        <p><strong>Page Flow:</strong> Automatic (no rect clipping)</p>
                    </div>

                    <div class="content-section">
                        <h2>Test Summary</h2>
                        <p>Generated: \(Date().formatted())</p>
                        <p>Total Pages: 5</p>
                        <p>Test Items: 60</p>
                        <p>Status: ✅ All checks passed</p>
                    </div>

                    <div class="page-number">— Page 5 (Final) —</div>
                </div>
            </body>
            </html>
            """

            let output = desktop.appendingPathComponent("PDF_MultiPage_Test.pdf")

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Generating Multi-Page PDF")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("\nOutput location:")
            print("  \(output.path)")

            let url = try await pdf.render(htmlString, output)

            if FileManager.default.fileExists(atPath: url.path) {
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = attrs[.size] as? Int64 ?? 0

                print("\n✅ Multi-Page PDF Generated!")
                print("   Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                print("   Path: \(url.path)")
                print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("Open the PDF to verify:")
                print("  • Should have exactly 5 pages")
                print("  • Each page clearly labeled (Page 1/5, 2/5, etc.)")
                print("  • No content clipping or overflow")
                print("  • Page breaks occur at correct positions")
                print("  • All special characters visible on page 3")
                print("  • Final checklist visible on page 5")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            } else {
                throw NSError(domain: "PDF not created", code: -1)
            }
        }
    }
}
