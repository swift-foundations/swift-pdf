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
import PDFTestSupport
@testable import HtmlToPdfLive

@Suite(
    "Basic Functionality",
    .serialized
)
struct BasicFunctionalityTests {
    @Dependency(\.pdf) var pdf
    // MARK: - Single Document Tests

    @Test("Generate single PDF from HTML string")
    func testSinglePDFGeneration() async throws {
        try await withTemporaryPDF { output in
            let result = try await pdf.render.client.html(TestHTML.simple, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF should be created")

            let pdfData = try Data(contentsOf: result)
            #expect(pdfData.count > 1000, "PDF should have substantial content")
        }
    }

    @Test("Generate PDF with title")
    func testPDFWithTitle() async throws {
        try await withTemporaryDirectory { directory in
            let html = TestHTML.simple
            let filename = "test-document"

            let doc = PDF.Document(htmlString: html, title: filename, in: directory)
            let result = try await pdf.render.client.document(doc)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF with correct filename should exist")
        }
    }

    @Test(
        "Generate PDF with custom configuration",
        .dependency(\.pdf.render.configuration.paperSize, .a4.landscape),
        .dependency(\.pdf.render.configuration.margins, .wide)
    )
    func testCustomConfiguration() async throws {
        try await withTemporaryPDF { output in
            let result = try await pdf.render.client.html(TestHTML.simple, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF with custom config should be created")
        }
    }

    // MARK: - Small Batch Tests

    @Test("Generate small batch from strings and documents")
    func testSmallBatch() async throws {
        try await withTemporaryDirectory { output in
            let count = 5

            // Test batch from strings
            let htmls = [String](repeating: TestHTML.simple, count: count)
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
                    htmlString: TestHTML.simple,
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
    }

    // MARK: - Content Variety Tests

    @Test("Generate PDF with complex HTML")
    func testComplexHTML() async throws {
        try await withTemporaryPDF { output in
            let result = try await pdf.render.client.html(TestHTML.items(50), to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "Complex HTML PDF should be created")

            let pdfData = try Data(contentsOf: result)
            #expect(pdfData.count > 5000, "Complex PDF should have substantial content")
        }
    }

    // MARK: - Missing API Coverage

    @Test("renderToData returns PDF data")
    func testRenderToData() async throws {
        let html = TestHTML.simple
        let data = try await pdf.render.client.data(html)

        #expect(data.count > 1000, "PDF data should have substantial content")
        // PDF files start with "%PDF" (0x25 0x50 0x44 0x46)
        #expect(data.starts(with: [0x25, 0x50, 0x44, 0x46]), "Should start with %PDF magic bytes")
    }

    // MARK: - Configuration Coverage

    @Test(
        "baseURL configuration with external resources",
        .dependency(\.pdf.render.configuration.baseURL, URL(string: "https://example.com"))
    )
    func testBaseURLConfiguration() async throws {
        try await withTemporaryPDF { output in
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

            let result = try await pdf.render.client.html(html, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF with baseURL should be created")
        }
    }

    @Test(
        "US Letter paper size",
        .dependency(\.pdf.render.configuration.paperSize, .letter)
    )
    func testUSLetterPaperSize() async throws {
        try await withTemporaryPDF { output in
            let result = try await pdf.render.client.html(TestHTML.simple, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "US Letter PDF should be created")
        }
    }

    @Test(
        "A3 paper size",
        .dependency(\.pdf.render.configuration.paperSize, .a3)
    )
    func testA3PaperSize() async throws {
        try await withTemporaryPDF { output in
            let result = try await pdf.render.client.html(TestHTML.simple, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "A3 PDF should be created")
        }
    }

    @Test(
        "Minimal margins preset",
        .dependency(\.pdf.render.configuration.margins, .minimal)
    )
    func testMinimalMargins() async throws {
        try await withTemporaryPDF { output in
            let result = try await pdf.render.client.html(TestHTML.simple, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF with minimal margins should be created")
        }
    }
}
