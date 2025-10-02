//
//  TestHTML.swift
//  PDFTestSupport
//
//  Common HTML fixtures for PDF testing
//

import Foundation

/// Pre-built HTML fixtures for common test scenarios
///
/// Provides consistent HTML test data across test suites, reducing duplication
/// and ensuring tests use well-formed, predictable content.
public enum TestHTML {
    /// Minimal valid HTML document
    public static let minimal = "<html><body></body></html>"

    /// Simple single-page content with heading and paragraph
    public static let simple = """
    <html>
        <head><meta charset="UTF-8"></head>
        <body>
            <h1>Hello, World!</h1>
            <p>This is a test document.</p>
        </body>
    </html>
    """

    /// Generate HTML with multiple items for pagination testing
    ///
    /// Creates a document with the specified number of styled items,
    /// useful for testing multi-page rendering and pagination behavior.
    ///
    /// - Parameter count: Number of items to generate
    /// - Returns: HTML string with styled item divs
    public static func items(_ count: Int) -> String {
        let items = (1...count).map { i in
            """
            <div style="padding: 15px; margin: 10px 0; background: #f5f5f5; border-radius: 4px;">
                <h3>Item \(i)</h3>
                <p>Test content for item number \(i). This text helps verify that content flows correctly across pages.</p>
            </div>
            """
        }.joined(separator: "\n")

        return """
        <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    body {
                        font-family: Arial, sans-serif;
                        line-height: 1.6;
                        margin: 20px;
                    }
                </style>
            </head>
            <body>
                \(items)
            </body>
        </html>
        """
    }

    /// Rich formatting test with CSS, gradients, and tables
    public static let richFormatting = """
    <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: 'Helvetica Neue', Arial, sans-serif;
                    margin: 0;
                    padding: 0;
                }
                .header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 20px;
                    text-align: center;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 20px 0;
                }
                th {
                    background: #667eea;
                    color: white;
                    padding: 10px;
                    text-align: left;
                }
                td {
                    padding: 10px;
                    border-bottom: 1px solid #ddd;
                }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>Rich Formatting Test</h1>
            </div>
            <table>
                <tr><th>Column 1</th><th>Column 2</th></tr>
                <tr><td>Data 1</td><td>Data 2</td></tr>
                <tr><td>Data 3</td><td>Data 4</td></tr>
            </table>
        </body>
    </html>
    """

    /// Unicode and emoji test content
    public static let unicode = """
    <html>
        <head><meta charset="UTF-8"></head>
        <body>
            <h1>Unicode Test</h1>
            <p>Emoji: 🎉 🚀 ✨ 💡 🔥 ⚡️</p>
            <p>Math: α β γ δ ∑ ∫ √ ∞ ≈ ≠</p>
            <p>Currency: $ € £ ¥ ₹ ₿</p>
            <p>Accents: café, naïve, résumé, façade</p>
        </body>
    </html>
    """

    /// Build custom HTML with title, body content, and optional CSS
    ///
    /// - Parameters:
    ///   - title: Document title (default: "Test Document")
    ///   - body: HTML body content
    ///   - css: Optional CSS styles
    /// - Returns: Complete HTML document string
    public static func custom(
        title: String = "Test Document",
        body: String,
        css: String = ""
    ) -> String {
        """
        <html>
            <head>
                <meta charset="UTF-8">
                <title>\(title)</title>
                <style>\(css)</style>
            </head>
            <body>
                \(body)
            </body>
        </html>
        """
    }
}
