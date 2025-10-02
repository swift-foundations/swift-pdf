//
//  BasicFunctionalityTests.swift
//  swift-html-to-pdf
//
//  Basic PDF generation functionality tests
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
@testable import HtmlToPdf

@Suite("Basic Functionality", .dependency(\.pdf, .liveValue), .serialized)
struct BasicFunctionalityTests {
    @Dependency(\.pdf) var pdf
    // MARK: - Single Document Tests

    @Test("Generate single PDF from HTML string")
    func testSinglePDFGeneration() async throws {

        let html = String.html
        let output = URL.output().appendingPathComponent("single.pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let result = try await pdf.render.client.html(html, output)

        #expect(FileManager.default.fileExists(atPath: result.path), "PDF should be created")

        let pdfData = try Data(contentsOf: result)
        #expect(pdfData.count > 1000, "PDF should have substantial content")
    }

    @Test("Generate PDF with title")
    func testPDFWithTitle() async throws {

        let html = String.html
        let directory = URL.output()
        let filename = "test-document"

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let doc = PDF.Document(htmlString: html, title: filename, in: directory)
        let result = try await pdf.render.client.document(doc)

        #expect(FileManager.default.fileExists(atPath: result.path), "PDF with correct filename should exist")
    }

    @Test(
        "Generate PDF with custom configuration",
        .dependency(\.pdf.render.configuration.paperSize, .a4.landscape),
        .dependency(\.pdf.render.configuration.margins, .wide)
    )
    func testCustomConfiguration() async throws {

        let html = String.html
        let output = URL.output().appendingPathComponent("custom.pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let result = try await pdf.render.client.html(html, output)

        #expect(FileManager.default.fileExists(atPath: result.path), "PDF with custom config should be created")
    }

    // MARK: - Small Batch Tests

    @Test("Generate small batch from strings and documents")
    func testSmallBatch() async throws {

        let count = 5
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Test batch from strings
        let htmls = [String](repeating: .html, count: count)
        var urls: [URL] = []
        for try await result in try await pdf.render.client.html(htmls, to: output) {
            urls.append(result.url)
        }

        #expect(urls.count == count, "Should create \(count) PDF files from strings")

        // Verify each file has content
        for url in urls {
            let data = try Data(contentsOf: url)
            #expect(data.count > 1000, "Each PDF should have content")
        }

        // Clean up for documents test
        try FileManager.default.removeItem(at: output)

        // Test batch from documents
        let documents = (1...count).map { i in
            PDF.Document(
                htmlString: String.html,
                title: "doc-\(i)",
                in: output
            )
        }

        var resultCount = 0
        for try await _ in try await pdf.render.client.documents(documents) {
            resultCount += 1
        }

        #expect(resultCount == count, "Should create \(count) PDF files from documents")

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count, "Should have \(count) files in directory")
    }

    // MARK: - Content Variety Tests

    @Test("Generate PDF with complex HTML")
    func testComplexHTML() async throws {

        let html = String.html2
        let output = URL.output().appendingPathComponent("complex.pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let result = try await pdf.render.client.html(html, output)

        #expect(FileManager.default.fileExists(atPath: result.path), "Complex HTML PDF should be created")

        let pdfData = try Data(contentsOf: result)
        #expect(pdfData.count > 5000, "Complex PDF should have substantial content")
    }

    // MARK: - Missing API Coverage

    @Test("renderToData returns PDF data")
    func testRenderToData() async throws {

        let html = String.html
        let data = try await pdf.render.client.data(html)

        #expect(data.count > 1000, "PDF data should have substantial content")
        // PDF files start with "%PDF" (0x25 0x50 0x44 0x46)
        #expect(data.starts(with: [0x25, 0x50, 0x44, 0x46]), "Should start with %PDF magic bytes")
    }

    @Test("capabilities returns platform info")
    func testCapabilities() throws {

        let caps = pdf.render.client.capabilities()
        #if os(macOS)
        #expect(caps.supportsWebViewPooling == true, "macOS should support WebView pooling")
        #expect(caps.supportsBackgroundRendering == true, "macOS should support background rendering")
        #expect(caps.maxConcurrentOperations > 0, "Should have max concurrent operations")
        #else
        #expect(caps.supportsWebViewPooling == true, "iOS should support WebView pooling")
        #expect(caps.supportsBackgroundRendering == false, "iOS should not support background rendering")
        #expect(caps.maxConcurrentOperations > 0, "Should have max concurrent operations")
        #endif
    }

    // MARK: - Configuration Coverage

    @Test(
        "baseURL configuration with external resources",
        .dependency(\.pdf.render.configuration.baseURL, URL(string: "https://example.com"))
    )
    func testBaseURLConfiguration() async throws {

        let html = """
        <html>
        <head>
            <style>body { color: red; }</style>
        </head>
        <body>
            <h1>Test with baseURL</h1>
        </body>
        </html>
        """
        let output = URL.output().appendingPathComponent("baseurl-test.pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let result = try await pdf.render.client.html(html, output)

        #expect(FileManager.default.fileExists(atPath: result.path), "PDF with baseURL should be created")
    }

    @Test(
        "US Letter paper size",
        .dependency(\.pdf.render.configuration.paperSize, .letter)
    )
    func testUSLetterPaperSize() async throws {

        let html = String.html
        let output = URL.output().appendingPathComponent("us-letter.pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let result = try await pdf.render.client.html(html, output)

        #expect(FileManager.default.fileExists(atPath: result.path), "US Letter PDF should be created")
    }

    @Test(
        "A3 paper size",
        .dependency(\.pdf.render.configuration.paperSize, .a3)
    )
    func testA3PaperSize() async throws {

        let html = String.html
        let output = URL.output().appendingPathComponent("a3.pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let result = try await pdf.render.client.html(html, output)

        #expect(FileManager.default.fileExists(atPath: result.path), "A3 PDF should be created")
    }

    @Test(
        "Minimal margins preset",
        .dependency(\.pdf.render.configuration.margins, .minimal)
    )
    func testMinimalMargins() async throws {

        let html = String.html
        let output = URL.output().appendingPathComponent("minimal-margins.pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let result = try await pdf.render.client.html(html, output)

        #expect(FileManager.default.fileExists(atPath: result.path), "PDF with minimal margins should be created")
    }
}
