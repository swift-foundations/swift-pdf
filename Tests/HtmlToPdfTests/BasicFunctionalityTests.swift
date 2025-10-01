//
//  BasicFunctionalityTests.swift
//  swift-html-to-pdf
//
//  Basic PDF generation functionality tests
//

import Testing
import Foundation
@testable import HtmlToPdf

@Suite("Basic Functionality", .serialized)
struct BasicFunctionalityTests {

    // MARK: - Single Document Tests

    @Test("Generate single PDF from HTML string")
    func testSinglePDFGeneration() async throws {
        let html = String.html
        let output = URL.output().appendingPathComponent("single.pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        try await html.print(to: output, configuration: .a4)

        #expect(FileManager.default.fileExists(atPath: output.path), "PDF should be created")

        let pdfData = try Data(contentsOf: output)
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

        try await html.print(title: filename, to: directory, configuration: .a4)

        let expectedFile = directory.appendingPathComponent(filename).appendingPathExtension("pdf")
        #expect(FileManager.default.fileExists(atPath: expectedFile.path), "PDF with correct filename should exist")
    }

    @Test("Generate PDF with custom configuration")
    func testCustomConfiguration() async throws {
        let html = String.html
        let output = URL.output().appendingPathComponent("custom.pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let config = PDFConfiguration.a4.with(margins: .wide).landscape()
        try await html.print(to: output, configuration: config)

        #expect(FileManager.default.fileExists(atPath: output.path), "PDF with custom config should be created")
    }

    // MARK: - Small Batch Tests

    @Test("Generate 3 PDFs from strings")
    func testSmallBatchFromStrings() async throws {
        let count = 3
        let htmls = [String](repeating: .html, count: count)
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        try await htmls.print(to: output, configuration: .a4)

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count, "Should create \(count) PDF files")

        // Verify each file has content
        for file in files {
            let data = try Data(contentsOf: file)
            #expect(data.count > 1000, "Each PDF should have content")
        }
    }

    @Test("Generate 5 PDFs from Documents")
    func testSmallBatchFromDocuments() async throws {
        let count = 5
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let documents = (1...count).map { i in
            Document(
                fileUrl: output.appendingPathComponent("doc-\(i).pdf"),
                html: String.html
            )
        }

        try await documents.print(configuration: .a4)

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count, "Should create \(count) PDF files")
    }

    // MARK: - Content Variety Tests

    @Test("Generate PDF with complex HTML")
    func testComplexHTML() async throws {
        let html = String.html2
        let output = URL.output().appendingPathComponent("complex.pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        try await html.print(to: output, configuration: .a4)

        #expect(FileManager.default.fileExists(atPath: output.path), "Complex HTML PDF should be created")

        let pdfData = try Data(contentsOf: output)
        #expect(pdfData.count > 5000, "Complex PDF should have substantial content")
    }

//    @Test("Generate PDF with embedded image")
//    func testEmbeddedImage() async throws {
//        let html = "<html><body><h1>Test</h1>\(String.img)</body></html>"
//        let output = URL.output().appendingPathComponent("image.pdf")
//
//        defer {
//            try? FileManager.default.removeItem(at: output)
//        }
//
//        try await html.print(to: output, configuration: .a4)
//
//        #expect(FileManager.default.fileExists(atPath: output.path), "PDF with image should be created")
//    }
}
