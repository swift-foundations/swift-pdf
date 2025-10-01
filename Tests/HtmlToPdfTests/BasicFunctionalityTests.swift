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
            $0.pdfConfiguration = .default
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
            $0.pdfConfiguration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = String.html
            let directory = URL.output()
            let filename = "test-document"

            defer {
                try? FileManager.default.removeItem(at: directory)
            }

            let result = try await pdf.renderWithTitle(html, filename, directory)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF with correct filename should exist")
        }
    }

    @Test("Generate PDF with custom configuration")
    func testCustomConfiguration() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdfConfiguration.paperSize = .a4.landscape
            $0.pdfConfiguration.margins = .wide
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

    @Test("Generate 3 PDFs from strings")
    func testSmallBatchFromStrings() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdfConfiguration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let count = 3
            let htmls = [String](repeating: .html, count: count)
            let output = URL.output()

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let urls = try await pdf.renderBatchSync(htmls, output)

            #expect(urls.count == count, "Should create \(count) PDF files")

            // Verify each file has content
            for url in urls {
                let data = try Data(contentsOf: url)
                #expect(data.count > 1000, "Each PDF should have content")
            }
        }
    }

    @Test("Generate 5 PDFs from Documents")
    func testSmallBatchFromDocuments() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdfConfiguration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let count = 5
            let output = URL.output()

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let documents = (1...count).map { i in
                PDF.Document(
                    html: String.html,
                    title: "doc-\(i)",
                    in: output
                )
            }

            var resultCount = 0
            for try await _ in try await pdf.renderDocuments(documents) {
                resultCount += 1
            }

            #expect(resultCount == count, "Should create \(count) PDF files")

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == count, "Should have \(count) files in directory")
        }
    }

    // MARK: - Content Variety Tests

    @Test("Generate PDF with complex HTML")
    func testComplexHTML() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdfConfiguration = .default
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
}
