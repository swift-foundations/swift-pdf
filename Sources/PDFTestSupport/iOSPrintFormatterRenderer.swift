//
//  iOSPrintFormatterRenderer.swift
//  PDFTestSupport
//
//  Direct UIMarkupTextPrintFormatter rendering for testing iOS capabilities
//

#if canImport(UIKit)
import UIKit
import Foundation

/// Render HTML directly using UIMarkupTextPrintFormatter for testing
///
/// This bypasses the library's automatic routing logic to test the
/// capabilities and limitations of UIMarkupTextPrintFormatter in isolation.
///
/// **Known limitation**: UIMarkupTextPrintFormatter cannot render images.
/// This was verified through testing - `<img>` tags in HTML are ignored.
///
/// Usage:
/// ```swift
/// let html = "<html><body><h1>Test</h1></body></html>"
/// let url = try await iOSPrintFormatterRenderer.renderPDF(
///     html: html,
///     to: outputURL
/// )
/// ```
@MainActor
public enum iOSPrintFormatterRenderer {
    /// Render HTML to PDF using UIMarkupTextPrintFormatter
    ///
    /// - Parameters:
    ///   - html: HTML string to render
    ///   - destination: Output file URL for the PDF
    ///   - paperSize: Paper dimensions (default: A4)
    ///   - margins: Page margins in points (default: 36pt all sides)
    /// - Returns: Time taken to render in seconds
    /// - Throws: Error if rendering or file writing fails
    @discardableResult
    public static func renderPDF(
        html: String,
        to destination: URL,
        paperSize: CGSize = CGSize(width: 595.28, height: 841.89), // A4
        margins: UIEdgeInsets = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)
    ) throws -> TimeInterval {
        let start = Date()

        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let paperRect = CGRect(origin: .zero, size: paperSize)
        let printableRect = CGRect(
            x: margins.left,
            y: margins.top,
            width: paperSize.width - margins.left - margins.right,
            height: paperSize.height - margins.top - margins.bottom
        )

        renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))

        let bounds = UIGraphicsGetPDFContextBounds()
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: bounds)
        }
        UIGraphicsEndPDFContext()

        try (pdfData as Data).write(to: destination)

        return Date().timeIntervalSince(start)
    }
}
#endif
