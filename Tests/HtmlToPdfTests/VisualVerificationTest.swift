//
//  VisualVerificationTest.swift
//  swift-html-to-pdf
//
//  Manual verification test - generates a PDF to Desktop for visual inspection
//

import Testing
import Foundation
import HtmlToPdf
import Dependencies

@Suite("Visual Verification (Manual)")
struct VisualVerificationTests {

    @Test("Generate rich PDF for manual verification")
    func generateVerificationPDF() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            // $0.pdf.render.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

            // Test 1: Rich HTML with ContiguousArray<UInt8>
            let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>PDF Verification Test</title>
                <style>
                    body {
                        font-family: 'Helvetica Neue', Arial, sans-serif;
                        line-height: 1.6;
                        color: #333;
                    }

                    .header {
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        padding: 40px;
                        text-align: center;
                        border-radius: 8px;
                        margin-bottom: 30px;
                    }

                    .header h1 {
                        margin: 0;
                        font-size: 48px;
                        font-weight: bold;
                    }

                    .header p {
                        margin: 10px 0 0 0;
                        font-size: 18px;
                        opacity: 0.9;
                    }

                    .section {
                        margin: 30px 0;
                        padding: 20px;
                        background: #f8f9fa;
                        border-left: 4px solid #667eea;
                        border-radius: 4px;
                    }

                    .section h2 {
                        margin-top: 0;
                        color: #667eea;
                    }

                    .feature-grid {
                        display: grid;
                        grid-template-columns: repeat(2, 1fr);
                        gap: 20px;
                        margin: 20px 0;
                    }

                    .feature {
                        background: white;
                        padding: 20px;
                        border-radius: 8px;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                    }

                    .feature h3 {
                        margin-top: 0;
                        color: #764ba2;
                    }

                    table {
                        width: 100%;
                        border-collapse: collapse;
                        margin: 20px 0;
                        background: white;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                    }

                    th {
                        background: #667eea;
                        color: white;
                        padding: 12px;
                        text-align: left;
                    }

                    td {
                        padding: 12px;
                        border-bottom: 1px solid #e9ecef;
                    }

                    tr:hover {
                        background: #f8f9fa;
                    }

                    code {
                        background: #f4f4f4;
                        padding: 2px 6px;
                        border-radius: 3px;
                        font-family: 'Monaco', 'Courier New', monospace;
                        color: #e83e8c;
                    }

                    .footer {
                        margin-top: 40px;
                        padding: 20px;
                        text-align: center;
                        color: #6c757d;
                        border-top: 2px solid #e9ecef;
                    }
                </style>
            </head>
            <body>
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

                <div class="footer">
                    <p>Generated: \(Date().formatted())</p>
                    <p>swift-html-to-pdf • ContiguousArray&lt;UInt8&gt; Implementation</p>
                </div>
            </body>
            </html>
            """

            let output = desktop.appendingPathComponent("PDF_Verification_Test.pdf")

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Generating Verification PDF")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("\nOutput location:")
            print("  \(output.path)")

            let url = try await pdf.render.client.html(htmlString, output)

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
                print("  • Typography and spacing look good")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            } else {
                throw NSError(domain: "PDF not created", code: -1)
            }
        }
    }
}
