//
//  PlatformSpecificTests.swift
//  swift-html-to-pdf
//
//  Platform-specific behavior tests
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
import PDFKit
import PDFTestSupport
@testable import HtmlToPdfLive

@Suite(
    "Platform-Specific Behavior"
)
struct PlatformSpecificTests {
    @Dependency(\.pdf) var pdf

    #if os(iOS)
    @Test("iOS renders images using WebView path")
    func iOSImageRendering() async throws {
        try await withTemporaryPDF { output in
            let html = """
            <html>
            <head><title>Test</title></head>
            <body>
                <h1>Image Test</h1>
                <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" alt="test" />
                <p>This HTML contains an image</p>
            </body>
            </html>
            """

            let result = try await pdf.render.client.html(html, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF with image should be created")

            // Verify PDF was created and has content
            let pdfData = try Data(contentsOf: result)
            #expect(pdfData.count > 1000, "PDF with image should have substantial content")
        }
    }

    @Test("iOS uses fast text-only rendering when no images")
    func iOSTextOnlyRendering() async throws {
        try await withTemporaryPDF { output in
            let html = """
            <html>
            <head><title>Test</title></head>
            <body>
                <h1>Simple Text</h1>
                <p>No images here, just plain text content.</p>
            </body>
            </html>
            """

            let result = try await pdf.render.client.html(html, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "Text-only PDF should be created")
        }
    }

    @Test("iOS respects MainActor isolation")
    func iOSMainActorIsolation() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let output = tempDir.appendingPathComponent("test-mainactor.pdf")
        defer { try? FileManager.default.removeItem(at: output) }

        @MainActor
        func renderOnMainActor() async throws -> URL {
            let html = "<html><body><h1>MainActor Test</h1></body></html>"
            return try await pdf.render.client.html(html, to: output)
        }

        let result = try await renderOnMainActor()
        #expect(FileManager.default.fileExists(atPath: result.path), "PDF from MainActor should be created")
    }

    /// Verify UIMarkupTextPrintFormatter image rendering capability
    ///
    /// **Current Result**: UIMarkupTextPrintFormatter CANNOT render images.
    /// This test programmatically verifies that images are NOT rendered by comparing
    /// file sizes of text-only vs text-with-image PDFs. If Apple ever adds image
    /// support to UIMarkupTextPrintFormatter, this test will fail and alert us
    /// that we can simplify the iOS implementation.
    @Test("UIMarkupTextPrintFormatter cannot render images")
    func printFormatterCannotRenderImages() async throws {
        try await withTemporaryDirectory { tempDir in
            // Load test image
            let base64PNG = try TestImages.loadBase64(named: "coenttb", extension: "png", from: .module)

            // PDF 1: Text-only baseline
            let textOnlyHTML = TestHTML.custom(
                title: "Text Only",
                body: """
                <h1>Test Document</h1>
                <p>This is a test document with some text content.</p>
                <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
                <p>No images in this document.</p>
                """,
                css: "body { font-family: Arial; padding: 20px; }"
            )

            // PDF 2: Same text PLUS an image tag
            let withImageHTML = TestHTML.custom(
                title: "With Image Tag",
                body: """
                <h1>Test Document</h1>
                <p>This is a test document with some text content.</p>
                <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
                <p>No images in this document.</p>
                <img src="data:image/png;base64,\(base64PNG)" alt="Test" style="width: 200px; height: 200px;">
                """,
                css: "body { font-family: Arial; padding: 20px; }"
            )

            // Generate both PDFs using PrintFormatter only
            let textOnlyOutput = tempDir.appendingPathComponent("text-only.pdf")
            let withImageOutput = tempDir.appendingPathComponent("with-image.pdf")

            _ = try await iOSPrintFormatterRenderer.renderPDF(html: textOnlyHTML, to: textOnlyOutput)
            _ = try await iOSPrintFormatterRenderer.renderPDF(html: withImageHTML, to: withImageOutput)

            // Get file sizes
            let textOnlySize = try FileManager.default.attributesOfItem(atPath: textOnlyOutput.path)[.size] as! Int64
            let withImageSize = try FileManager.default.attributesOfItem(atPath: withImageOutput.path)[.size] as! Int64

            // Calculate size difference
            let sizeDifference = abs(withImageSize - textOnlySize)
            let percentDifference = (Double(sizeDifference) / Double(textOnlySize)) * 100

            // If images were rendered, the PDF with the image would be significantly larger
            // (at least 10KB+ for even a small PNG). We allow for small variations due to
            // metadata differences, but any difference over 5% likely indicates image rendering.
            let maxAllowedDifferencePercent = 5.0

            if percentDifference > maxAllowedDifferencePercent {
                Issue.record(
                    """
                    UIMarkupTextPrintFormatter appears to render images (size increased \(String(format: "%.1f", percentDifference))%). \
                    Consider removing the dual-path iOS implementation.
                    """
                )
            }

            // Test expectation: Images should NOT be rendered (file sizes should be similar)
            #expect(
                percentDifference <= maxAllowedDifferencePercent,
                """
                UIMarkupTextPrintFormatter should NOT render images. \
                If this test fails, Apple may have added image support, and we can simplify the iOS implementation.
                """
            )
        }
    }
    #endif

    #if os(macOS)
    @Test(
        "macOS uses NSPrintOperation for paginated mode",
        .dependency(\.pdf.render.configuration.paginationMode, .paginated)
    )
    func macOSPaginatedRendering() async throws {
        try await withTemporaryPDF { output in
            // Long content to trigger pagination
            let items = (1...100).map { "<p style='margin: 20px 0;'>Item \($0)</p>" }.joined()
            let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Test</title></head>
            <body>\(items)</body>
            </html>
            """

            let result = try await pdf.render.client.html(html, to: output)

            guard let pdfDoc = PDFDocument(url: result) else {
                throw NSError(domain: "Failed to load PDF", code: -1)
            }

            // macOS NSPrintOperation should create proper multi-page PDF
            #expect(pdfDoc.pageCount > 1, "macOS paginated mode should create multiple pages")

            // Verify all pages have standard dimensions (not continuous)
            for i in 0..<pdfDoc.pageCount {
                if let page = pdfDoc.page(at: i) {
                    let bounds = page.bounds(for: .mediaBox)
                    #expect(abs(bounds.height - 841.89) < 1.0, "Page \(i) should have standard A4 height")
                }
            }
        }
    }

    @Test(
        "macOS uses WKWebView.createPDF for continuous mode",
        .dependency(\.pdf.render.configuration.paginationMode, .continuous)
    )
    func macOSContinuousRendering() async throws {
        try await withTemporaryPDF { output in
            // Long content
            let items = (1...100).map { "<p style='margin: 20px 0;'>Item \($0)</p>" }.joined()
            let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Test</title></head>
            <body>\(items)</body>
            </html>
            """

            let result = try await pdf.render.client.html(html, to: output)

            guard let pdfDoc = PDFDocument(url: result) else {
                throw NSError(domain: "Failed to load PDF", code: -1)
            }

            // macOS continuous mode creates single tall page
            #expect(pdfDoc.pageCount == 1, "macOS continuous mode should create single page")

            if let page = pdfDoc.page(at: 0) {
                let bounds = page.bounds(for: .mediaBox)
                #expect(bounds.height > 1000, "Continuous page should be tall, got \(bounds.height)")
            }
        }
    }

    #endif

    // Shared tests with platform-aware expectations

    // MARK: - Concurrency Limits

    @Test("High concurrency is allowed (no artificial limits)")
    func testHighConcurrencyAllowed() async throws {
        await withTemporaryDirectory { dir in
            #if os(macOS)
            let highConcurrency = 100  // Well above old limit of 16
            #else
            let highConcurrency = 20   // Well above old limit of 8
            #endif

            // This should NOT throw - limits are removed
            await withDependencies {
                $0.pdf.render.configuration.concurrency = .fixed(highConcurrency)
            } operation: {
                @Dependency(\.pdf) var configuredPDF

                let html = "<html><body>Test</body></html>"
                let output = dir.appendingPathComponent("test.pdf")

                // Should succeed without throwing
                do {
                    _ = try await configuredPDF.render(html: html, to: output)
                    // Success - no error thrown
                    #expect(FileManager.default.fileExists(atPath: output.path))
                } catch {
                    Issue.record("Should not throw error for high concurrency, got: \(error)")
                }
            }
        }
    }

    @Test("Automatic concurrency uses optimal defaults")
    func testAutomaticConcurrencyRespectsPlatform() async throws {
        try await withTemporaryPDF { output in
            // Use automatic concurrency
            try await withDependencies {
                $0.pdf.render.configuration.concurrency = .automatic
            } operation: {
                @Dependency(\.pdf) var configuredPDF

                let html = "<html><body>Test</body></html>"

                // Should not throw - automatic should calculate safe value
                let result = try await configuredPDF.render(html: html, to: output)

                #expect(FileManager.default.fileExists(atPath: result.path))
            }
        }
    }

    @Test("Capability error messages are informative")
    func testCapabilityErrorMessages() {
        let error = PrintingError.capabilityUnavailable(
            capability: "concurrency=32",
            platform: "iOS",
            reason: "Platform maximum is 8. Requested 32 concurrent operations."
        )

        let description = error.errorDescription ?? ""
        let failureReason = error.failureReason ?? ""
        let recoverySuggestion = error.recoverySuggestion ?? ""

        #expect(description.contains("iOS"))
        #expect(description.contains("concurrency=32"))
        #expect(failureReason.count > 0)
        #expect(recoverySuggestion.contains("reduce") || recoverySuggestion.contains("platform"))
    }

    @Test("Page count extraction works on both platforms")
    func pageCountExtraction() async throws {
        try await withTemporaryPDF { output in
            // Multi-page content
            let items = (1...100).map { "<p style='margin: 20px 0;'>Item \($0)</p>" }.joined()
            let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Test</title></head>
            <body>\(items)</body>
            </html>
            """

            let result = try await withDependencies {
                $0.pdf.render.configuration.paginationMode = .paginated
            } operation: {
                try await pdf.render.client.html(html, to: output)
            }

            guard let pdfDoc = PDFDocument(url: result) else {
                throw NSError(domain: "Failed to load PDF", code: -1)
            }

            // Both platforms should correctly extract page count
            let pageCount = pdfDoc.pageCount
            #expect(pageCount > 0, "Should extract page count from PDF")

            #if os(macOS)
            // macOS with NSPrintOperation should create multiple pages
            #expect(pageCount > 1, "macOS paginated should create multiple pages")
            #else
            // iOS behavior: WebView-based pagination may differ
            // Just verify we got a valid PDF
            #expect(pageCount >= 1, "iOS should create valid PDF")
            #endif
        }
    }
}
