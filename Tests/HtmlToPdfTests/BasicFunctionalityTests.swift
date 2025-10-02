//
//  BasicFunctionalityTests.swift
//  swift-html-to-pdf
//
//  Basic PDF generation functionality tests
//

import Testing
import Foundation
import Dependencies
@testable import HtmlToPdf

@Suite("Basic Functionality", .serialized)
struct BasicFunctionalityTests {

    // MARK: - Single Document Tests

    @Test("Generate single PDF from HTML string")
    func testSinglePDFGeneration() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = String.html
            let output = URL.output().appendingPathComponent("single.pdf")

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let result = try await pdf.render(html, output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF should be created")

            let pdfData = try Data(contentsOf: result)
            #expect(pdfData.count > 1000, "PDF should have substantial content")
        }
    }

    @Test("Generate PDF with title")
    func testPDFWithTitle() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = String.html
            let directory = URL.output()
            let filename = "test-document"

            defer {
                try? FileManager.default.removeItem(at: directory)
            }

            let result = try await pdf.render(html, title: filename, in: directory)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF with correct filename should exist")
        }
    }

    @Test("Generate PDF with custom configuration")
    func testCustomConfiguration() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.configuration.paperSize = .a4.landscape
            $0.pdf.configuration.margins = .wide
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = String.html
            let output = URL.output().appendingPathComponent("custom.pdf")

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let result = try await pdf.render(html, output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF with custom config should be created")
        }
    }

    // MARK: - Small Batch Tests

    @Test("Generate small batch from strings and documents")
    func testSmallBatch() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let count = 5
            let output = URL.output()

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            // Test batch from strings
            let htmls = [String](repeating: .html, count: count)
            let urls = try await pdf.renderBatchSync(htmls, output)

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
            for try await _ in try await pdf.render(documents) {
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
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = String.html2
            let output = URL.output().appendingPathComponent("complex.pdf")

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let result = try await pdf.render(html, output)

            #expect(FileManager.default.fileExists(atPath: result.path), "Complex HTML PDF should be created")

            let pdfData = try Data(contentsOf: result)
            #expect(pdfData.count > 5000, "Complex PDF should have substantial content")
        }
    }

    // MARK: - Missing API Coverage

    @Test("renderToData returns PDF data")
    func testRenderToData() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = String.html
            let data = try await pdf.renderToData(html)

            #expect(data.count > 1000, "PDF data should have substantial content")
            // PDF files start with "%PDF" (0x25 0x50 0x44 0x46)
            #expect(data.starts(with: [0x25, 0x50, 0x44, 0x46]), "Should start with %PDF magic bytes")
        }
    }

    @Test("capabilities returns platform info")
    func testCapabilities() throws {
        try withDependencies {
            $0.pdf = .liveValue
        } operation: {
            @Dependency(\.pdf) var pdf

            let caps = pdf.capabilities()
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
    }

    // MARK: - Configuration Coverage

    @Test("baseURL configuration with external resources")
    func testBaseURLConfiguration() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.configuration = .default
            $0.pdf.configuration.baseURL = URL(string: "https://example.com")
        } operation: {
            @Dependency(\.pdf) var pdf

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

            let result = try await pdf.render(html, output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF with baseURL should be created")
        }
    }

    @Test("US Letter paper size")
    func testUSLetterPaperSize() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.configuration = .default
            $0.pdf.configuration.paperSize = .letter
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = String.html
            let output = URL.output().appendingPathComponent("us-letter.pdf")

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let result = try await pdf.render(html, output)

            #expect(FileManager.default.fileExists(atPath: result.path), "US Letter PDF should be created")
        }
    }

    @Test("A3 paper size")
    func testA3PaperSize() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.configuration = .default
            $0.pdf.configuration.paperSize = .a3
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = String.html
            let output = URL.output().appendingPathComponent("a3.pdf")

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let result = try await pdf.render(html, output)

            #expect(FileManager.default.fileExists(atPath: result.path), "A3 PDF should be created")
        }
    }

    @Test("Minimal margins preset")
    func testMinimalMargins() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.configuration = .default
            $0.pdf.configuration.margins = .minimal
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = String.html
            let output = URL.output().appendingPathComponent("minimal-margins.pdf")

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let result = try await pdf.render(html, output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF with minimal margins should be created")
        }
    }
}
