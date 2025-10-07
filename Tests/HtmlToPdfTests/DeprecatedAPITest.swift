//
//  DeprecatedAPITest.swift
//  swift-html-to-pdf
//
//  Test that v0.5.x API still works (with deprecation warnings)
//

import Testing
import Foundation
@testable import HtmlToPdf

@Suite("Deprecated API Compatibility")
struct DeprecatedAPITest {

    @Test("String.print(to:) works with deprecation warning")
    func stringPrintToURL() async throws {
        let html = "<html><body><h1>Test</h1></body></html>"
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("deprecated-test-\(UUID()).pdf")

        // This should compile with a deprecation warning but still work
        try await html.print(to: testFile)

        #expect(FileManager.default.fileExists(atPath: testFile.path))

        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("String.print(title:to:) works with deprecation warning")
    func stringPrintWithTitle() async throws {
        let html = "<html><body><h1>Test</h1></body></html>"
        let tempDir = FileManager.default.temporaryDirectory

        // This should compile with a deprecation warning but still work
        try await html.print(title: "test-invoice", to: tempDir)

        let expectedFile = tempDir.appendingPathComponent("test-invoice.pdf")
        #expect(FileManager.default.fileExists(atPath: expectedFile.path))

        // Cleanup
        try? FileManager.default.removeItem(at: expectedFile)
    }

    @Test("Sequence.print works with deprecation warning")
    func sequencePrint() async throws {
        let html = [
            "<html><body><h1>Page 1</h1></body></html>",
            "<html><body><h1>Page 2</h1></body></html>"
        ]

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("deprecated-batch-\(UUID())")

        // This should compile with a deprecation warning but still work
        try await html.print(to: tempDir)

        // Check files exist
        let file1 = tempDir.appendingPathComponent("1.pdf")
        let file2 = tempDir.appendingPathComponent("2.pdf")

        #expect(FileManager.default.fileExists(atPath: file1.path))
        #expect(FileManager.default.fileExists(atPath: file2.path))

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Old configuration types work")
    func oldConfigurationTypes() async throws {
        // PDFConfiguration type alias should work
        let _: PDFConfiguration = .a4

        // PrintingConfiguration type alias should work
        let _: PrintingConfiguration = .default

        // Document type alias should work
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("doc-test-\(UUID()).pdf")
        let _: Document = OldDocument(
            fileUrl: tempFile,
            html: "<html><body>Test</body></html>"
        )
    }
}
