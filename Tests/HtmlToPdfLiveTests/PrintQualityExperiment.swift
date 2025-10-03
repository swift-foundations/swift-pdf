//
//  PrintQualityExperiment.swift
//  swift-html-to-pdf
//
//  Experiments to improve NSPrintOperation rendering quality
//

import Testing
import Foundation
import HtmlToPdfLive
import Dependencies
import DependenciesTestSupport

@Suite(
    "Print Quality Experiments",
    .dependency(\.pdf, .liveValue),
    .disabled("Run manually: swift test --filter PrintQualityExperiments")
)
struct PrintQualityExperiments {
    @Dependency(\.pdf) var pdf

    @Test(
        "Compare different bullet character rendering quality",
        .dependency(\.pdf.render.configuration.paginationMode, .paginated)
    )
    func compareBulletCharacters() async throws {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

        let experiments = [
            ("Unicode Bullet (•)", "•"),
            ("HTML Entity (&middot;)", "&middot;"),
            ("HTML Entity (&bull;)", "&bull;"),
            ("Hyphen (-)", "-"),
            ("Pipe (|)", "|"),
            ("Em Dash (—)", "—"),
            ("En Dash (–)", "–"),
            ("Dot Operator (⋅)", "⋅"),
        ]

        for (name, character) in experiments {
            let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>Print Quality Test: \(name)</title>
                <style>
                    @page {
                        size: A4;
                        margin: 20mm;
                    }

                    @media print {
                        body {
                            -webkit-print-color-adjust: exact;
                            print-color-adjust: exact;
                        }
                    }

                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif;
                        -webkit-font-smoothing: antialiased;
                        -moz-osx-font-smoothing: grayscale;
                        text-rendering: geometricPrecision;
                        font-feature-settings: normal;
                        font-variant-ligatures: none;
                        line-height: 1.6;
                        color: #333;
                        margin: 0;
                        padding: 20px;
                    }

                    .test-section {
                        margin: 20px 0;
                        padding: 20px;
                        background: #f8f9fa;
                        border-radius: 8px;
                    }

                    .separator {
                        display: inline-block;
                        margin: 0 8px;
                        font-weight: normal;
                    }

                    .size-test {
                        margin: 10px 0;
                    }
                </style>
            </head>
            <body>
                <h1>\(name)</h1>

                <div class="test-section">
                    <h2>Font Size Tests</h2>
                    <div class="size-test" style="font-size: 10px;">
                        10px: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-size: 12px;">
                        12px: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-size: 14px;">
                        14px: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-size: 16px;">
                        16px: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-size: 18px;">
                        18px: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                </div>

                <div class="test-section">
                    <h2>Color Tests</h2>
                    <div class="size-test" style="color: #000000;">
                        Black: ContiguousArray&lt;UInt8&gt; <span class="separator">\(character)</span> UTF-8 Encoding <span class="separator">\(character)</span> Zero-copy
                    </div>
                    <div class="size-test" style="color: #333333;">
                        Dark Gray: ContiguousArray&lt;UInt8&gt; <span class="separator">\(character)</span> UTF-8 Encoding <span class="separator">\(character)</span> Zero-copy
                    </div>
                    <div class="size-test" style="color: #666666;">
                        Medium Gray: ContiguousArray&lt;UInt8&gt; <span class="separator">\(character)</span> UTF-8 Encoding <span class="separator">\(character)</span> Zero-copy
                    </div>
                    <div class="size-test" style="color: #999999;">
                        Light Gray: ContiguousArray&lt;UInt8&gt; <span class="separator">\(character)</span> UTF-8 Encoding <span class="separator">\(character)</span> Zero-copy
                    </div>
                </div>

                <div class="test-section">
                    <h2>Font Weight Tests</h2>
                    <div class="size-test" style="font-weight: 300;">
                        Light (300): Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-weight: 400;">
                        Regular (400): Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-weight: 500;">
                        Medium (500): Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-weight: 700;">
                        Bold (700): Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                </div>

                <div class="test-section">
                    <h2>System Font Variants</h2>
                    <div class="size-test" style="font-family: -apple-system;">
                        -apple-system: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-family: 'Helvetica Neue';">
                        Helvetica Neue: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-family: Arial;">
                        Arial: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-family: Georgia;">
                        Georgia: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-family: 'Times New Roman';">
                        Times New Roman: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                </div>
            </body>
            </html>
            """

            let fileName = "PDF_PrintQuality_\(name.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")).pdf"
            let output = desktop.appendingPathComponent(fileName)

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Testing: \(name)")
            print("Character: '\(character)'")
            print("Output: \(fileName)")

            _ = try await pdf.render.client.html(htmlString, to: output)

            print("✅ Generated: \(output.lastPathComponent)")
        }

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("All quality experiments generated!")
        print("Check Desktop for PDF_PrintQuality_*.pdf files")
        print("Compare visual quality of each character")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    @Test(
        "Test advanced CSS print optimizations",
        .dependency(\.pdf.render.configuration.paginationMode, .paginated)
    )
    func advancedPrintOptimizations() async throws {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Advanced Print Quality Optimizations</title>
            <style>
                @page {
                    size: A4;
                    margin: 15mm;
                }

                @media print {
                    * {
                        -webkit-print-color-adjust: exact !important;
                        print-color-adjust: exact !important;
                        color-adjust: exact !important;
                    }

                    body {
                        /* Force vector rendering */
                        text-rendering: geometricPrecision;
                        -webkit-font-smoothing: antialiased;
                        -moz-osx-font-smoothing: grayscale;

                        /* Disable features that might cause rasterization */
                        font-variant-ligatures: none;
                        font-feature-settings: normal;
                        -webkit-font-feature-settings: normal;

                        /* Optimize for print */
                        image-rendering: -webkit-optimize-contrast;
                        image-rendering: crisp-edges;
                    }

                    /* Prevent sub-pixel rendering */
                    * {
                        -webkit-backface-visibility: hidden;
                        backface-visibility: hidden;
                        -webkit-transform: translateZ(0);
                        transform: translateZ(0);
                    }
                }

                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif;
                    line-height: 1.6;
                    color: #1d1d1f;
                    margin: 0;
                    padding: 20px;
                }

                .test-card {
                    margin: 20px 0;
                    padding: 20px;
                    background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
                    border-radius: 8px;
                    border: 1px solid #e1e4e8;
                }

                .separator {
                    display: inline-block;
                    margin: 0 6px;
                    color: #86868b;
                }

                .text-small { font-size: 11px; }
                .text-normal { font-size: 13px; }
                .text-large { font-size: 15px; }
            </style>
        </head>
        <body>
            <h1>Advanced Print Quality Optimizations</h1>

            <div class="test-card">
                <h2>CSS Optimization Test</h2>
                <p class="text-small">
                    Small text <span class="separator">•</span> ContiguousArray&lt;UInt8&gt; <span class="separator">•</span> UTF-8 Encoding <span class="separator">•</span> Zero-copy rendering
                </p>
                <p class="text-normal">
                    Normal text <span class="separator">•</span> ContiguousArray&lt;UInt8&gt; <span class="separator">•</span> UTF-8 Encoding <span class="separator">•</span> Zero-copy rendering
                </p>
                <p class="text-large">
                    Large text <span class="separator">•</span> ContiguousArray&lt;UInt8&gt; <span class="separator">•</span> UTF-8 Encoding <span class="separator">•</span> Zero-copy rendering
                </p>
            </div>

            <div class="test-card">
                <h2>Alternative Characters</h2>
                <p>Using middot: Testing <span class="separator">&middot;</span> UTF-8 <span class="separator">&middot;</span> Rendering</p>
                <p>Using bull: Testing <span class="separator">&bull;</span> UTF-8 <span class="separator">&bull;</span> Rendering</p>
                <p>Using hyphen: Testing <span class="separator">-</span> UTF-8 <span class="separator">-</span> Rendering</p>
                <p>Using pipe: Testing <span class="separator">|</span> UTF-8 <span class="separator">|</span> Rendering</p>
                <p>Using en dash: Testing <span class="separator">–</span> UTF-8 <span class="separator">–</span> Rendering</p>
            </div>

            <div class="test-card">
                <h2>Emoji & Symbol Quality Test</h2>
                <p>📄 Document <span class="separator">•</span> ✅ Success <span class="separator">•</span> 🎯 Target</p>
                <p>⚡ Performance <span class="separator">•</span> 🔧 Tools <span class="separator">•</span> 📊 Analytics</p>
            </div>

            <div class="test-card">
                <h2>Complex Typography</h2>
                <p style="font-variant-numeric: tabular-nums;">
                    Numbers: 1,234,567.89 <span class="separator">•</span> 9,876,543.21 <span class="separator">•</span> 5,555,555.55
                </p>
                <p style="letter-spacing: 0.5px;">
                    Letter spacing <span class="separator">•</span> Character <span class="separator">•</span> Quality
                </p>
            </div>
        </body>
        </html>
        """

        let output = desktop.appendingPathComponent("PDF_PrintQuality_Advanced_CSS.pdf")

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Testing Advanced Print Optimizations")
        print("Output: \(output.lastPathComponent)")

        _ = try await pdf.render.client.html(htmlString, to: output)

        print("✅ Generated!")
        print("Check if CSS optimizations improve rendering")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    @Test(
        "Test SVG-based separators for perfect vector quality",
        .dependency(\.pdf.render.configuration.paginationMode, .paginated)
    )
    func svgSeparators() async throws {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>SVG Separator Quality Test</title>
            <style>
                body {
                    font-family: -apple-system, 'Helvetica Neue', Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    padding: 20px;
                }

                .svg-separator {
                    display: inline-block;
                    margin: 0 8px;
                    vertical-align: middle;
                    width: 4px;
                    height: 4px;
                }

                .test-section {
                    margin: 30px 0;
                    padding: 20px;
                    background: #f8f9fa;
                    border-radius: 8px;
                }
            </style>
        </head>
        <body>
            <h1>SVG-Based Separator Test</h1>

            <div class="test-section">
                <h2>SVG Circle Separator (Always Vector)</h2>
                <p>
                    Testing
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="2" cy="2" r="1.5" fill="#666"/>
                    </svg>
                    ContiguousArray&lt;UInt8&gt;
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="2" cy="2" r="1.5" fill="#666"/>
                    </svg>
                    UTF-8 Encoding
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="2" cy="2" r="1.5" fill="#666"/>
                    </svg>
                    Zero-copy
                </p>
            </div>

            <div class="test-section">
                <h2>SVG Square Separator</h2>
                <p>
                    Testing
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <rect x="1" y="1" width="2" height="2" fill="#666"/>
                    </svg>
                    ContiguousArray&lt;UInt8&gt;
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <rect x="1" y="1" width="2" height="2" fill="#666"/>
                    </svg>
                    UTF-8 Encoding
                </p>
            </div>

            <div class="test-section">
                <h2>SVG Diamond Separator</h2>
                <p>
                    Testing
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <polygon points="2,0.5 3.5,2 2,3.5 0.5,2" fill="#666"/>
                    </svg>
                    ContiguousArray&lt;UInt8&gt;
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <polygon points="2,0.5 3.5,2 2,3.5 0.5,2" fill="#666"/>
                    </svg>
                    UTF-8 Encoding
                </p>
            </div>

            <div class="test-section">
                <h2>Comparison: Unicode vs SVG</h2>
                <p style="font-size: 12px; color: #6c757d;">
                    Unicode bullet: Testing • UTF-8 • Rendering
                </p>
                <p style="font-size: 12px; color: #6c757d;">
                    SVG circle: Testing
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="2" cy="2" r="1.5" fill="#6c757d"/>
                    </svg>
                    UTF-8
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="2" cy="2" r="1.5" fill="#6c757d"/>
                    </svg>
                    Rendering
                </p>
            </div>
        </body>
        </html>
        """

        let output = desktop.appendingPathComponent("PDF_PrintQuality_SVG_Separators.pdf")

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Testing SVG-Based Separators")
        print("Output: \(output.lastPathComponent)")

        _ = try await pdf.render.client.html(htmlString, to: output)

        print("✅ Generated!")
        print("SVG should always render as perfect vectors")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
}
