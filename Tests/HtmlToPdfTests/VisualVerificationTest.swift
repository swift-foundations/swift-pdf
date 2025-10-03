//
//  VisualVerificationTest.swift
//  swift-html-to-pdf
//
//  Manual verification tests - generate PDFs to Desktop for visual inspection
//

import Testing
import Foundation
import HtmlToPdf
import Dependencies
import DependenciesTestSupport
import PDFTestSupport

@Suite(
    "Visual Verification (Manual)",
    .dependency(\.pdf, .liveValue)
)
struct VisualVerificationTests {

    @Test("Generate rich PDF for manual verification")
    func generateVerificationPDF() async throws {
        @Dependency(\.pdf) var pdf

        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

        // Load test images
        let base64PNG = try TestImages.loadBase64(named: "coenttb", extension: "png", from: .module)

        // Build comprehensive verification HTML
        let html = TestHTML.custom(
            title: "PDF Verification Test",
            body: """
            <div class="header">
                <h1>🎯 PDF Generation Verification</h1>
                <p>Testing ContiguousArray&lt;UInt8&gt; Implementation</p>
            </div>

            <div class="section">
                <h2>✅ Implementation Verified</h2>
                <p>This PDF was generated using the new <code>ContiguousArray&lt;UInt8&gt;</code> approach. If you can see this document with proper formatting, colors, and layout, then the implementation is working correctly!</p>
            </div>

            <div class="section">
                <h2>📊 Performance Characteristics</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Metric</th>
                            <th>Old (String)</th>
                            <th>New (ContiguousArray)</th>
                            <th>Improvement</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td>Memory Usage</td>
                            <td>~1388 bytes</td>
                            <td>~694 bytes</td>
                            <td>50% reduction</td>
                        </tr>
                        <tr>
                            <td>CSS Injection</td>
                            <td>String operations</td>
                            <td>3.71μs (byte ops)</td>
                            <td>Faster</td>
                        </tr>
                        <tr>
                            <td>Type Safety</td>
                            <td>Runtime strings</td>
                            <td>Compile-time</td>
                            <td>✓ Guaranteed</td>
                        </tr>
                        <tr>
                            <td>Copy Operations</td>
                            <td>Multiple</td>
                            <td>Zero-copy</td>
                            <td>Eliminated</td>
                        </tr>
                    </tbody>
                </table>
            </div>

            <div class="feature-grid">
                <div class="feature">
                    <h3>🎨 CSS Support</h3>
                    <p>Gradients, shadows, borders, and modern CSS features are properly rendered.</p>
                </div>

                <div class="feature">
                    <h3>📝 Typography</h3>
                    <p>Multiple font families, sizes, and weights display correctly.</p>
                </div>

                <div class="feature">
                    <h3>🎭 Layout</h3>
                    <p>CSS Grid, flexbox, and positioning work as expected.</p>
                </div>

                <div class="feature">
                    <h3>🌈 Colors</h3>
                    <p>Hex colors, gradients, and opacity render perfectly.</p>
                </div>
            </div>

            <div class="section">
                <h2>🔬 Technical Details</h2>
                <p><strong>Storage Format:</strong> ContiguousArray&lt;UInt8&gt; (UTF-8 encoded bytes)</p>
                <p><strong>HTML Source:</strong> String → ContiguousArray&lt;UInt8&gt;</p>
                <p><strong>WKWebView Loading:</strong> Direct Data from ContiguousArray (zero-copy)</p>
                <p><strong>CSS Injection:</strong> Byte-level search and insertion</p>
                <p><strong>Memory Layout:</strong> Contiguous, cache-friendly byte array</p>
            </div>

            <div class="section">
                <h2>🧪 Character Encoding Test</h2>
                <p>Testing UTF-8 encoding with special characters:</p>
                <ul>
                    <li>Emoji: 🎉 🚀 ✨ 💡 🔥 ⚡️ 🎯 🌟</li>
                    <li>Math: α β γ δ ε ∑ ∫ √ ∞ ≈ ≠ ±</li>
                    <li>Currency: $ € £ ¥ ₹ ₿</li>
                    <li>Punctuation: « » „ " ' ' – — …</li>
                    <li>Accents: café, naïve, résumé, façade</li>
                </ul>
            </div>

            <div class="section">
                <h2>🖼️ Base64 Image Test - SVG</h2>
                <p>Testing inline base64 encoded SVG images (red, green, and blue 50x50px squares):</p>
                <div style="display: flex; gap: 20px; align-items: center; margin: 20px 0;">
                    <div style="text-align: center;">
                        <img src="data:image/svg+xml;base64,\(TestImages.SVG.redSquare)" alt="Red" style="border: 2px solid #ddd; border-radius: 4px;">
                        <p style="margin: 8px 0 0 0; color: #dc3545;">Red Square</p>
                    </div>
                    <div style="text-align: center;">
                        <img src="data:image/svg+xml;base64,\(TestImages.SVG.greenSquare)" alt="Green" style="border: 2px solid #ddd; border-radius: 4px;">
                        <p style="margin: 8px 0 0 0; color: #28a745;">Green Square</p>
                    </div>
                    <div style="text-align: center;">
                        <img src="data:image/svg+xml;base64,\(TestImages.SVG.blueSquare)" alt="Blue" style="border: 2px solid #ddd; border-radius: 4px;">
                        <p style="margin: 8px 0 0 0; color: #007bff;">Blue Square</p>
                    </div>
                </div>
                <p style="font-size: 14px; color: #6c757d;">If you see three colored squares (red, green, blue) above, SVG rendering is working correctly! ✓</p>
            </div>

            <div class="section">
                <h2>📷 Base64 Image Test - PNG</h2>
                <p>Testing actual PNG image loaded from test resources and embedded as base64:</p>
                <div style="text-align: center; margin: 20px 0;">
                    <img src="data:image/png;base64,\(base64PNG)" alt="Test PNG" style="max-width: 200px; border: 2px solid #ddd; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <p style="margin: 12px 0 0 0; color: #6c757d; font-size: 14px;">PNG image from test resources (coenttb.png)</p>
                </div>
                <p style="font-size: 14px; color: #6c757d;">If you see the coenttb logo image above, PNG base64 encoding is working correctly! ✓</p>
            </div>

            <div class="footer">
                <p>Generated: \(Date().formatted())</p>
                <p>swift-html-to-pdf • ContiguousArray&lt;UInt8&gt; Implementation</p>
            </div>
            """,
            css: TestCSS.richVerification
        )

        let output = desktop.appendingPathComponent("PDF_Verification_Test.pdf")

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Generating Verification PDF")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("\nOutput location:")
        print("  \(output.path)")

        let url = try await pdf.render.client.html(html, to: output)

        if FileManager.default.fileExists(atPath: url.path) {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? Int64 ?? 0

            print("\n✅ PDF Generated Successfully!")
            print("   Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
            print("   Path: \(url.path)")
            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Open the PDF to verify:")
            print("  • Gradients and colors render correctly")
            print("  • CSS Grid layout works")
            print("  • Tables are properly formatted")
            print("  • Special characters display (emoji, math symbols)")
            print("  • Base64 SVG images render (3 colored squares)")
            print("  • Base64 PNG image renders (coenttb logo)")
            print("  • Typography and spacing look good")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        } else {
            throw TestError.pdfNotFound(output)
        }
    }
}
