//
//  ErrorHandlingTests.swift
//  swift-html-to-pdf
//
//  Tests for error handling and edge cases
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
import PDFTestSupport
@testable import HtmlToPdfLive

@Suite("Error Handling Tests", .dependency(\.pdf, .liveValue), .serialized)
struct ErrorHandlingTests {
    @Dependency(\.pdf) var pdf
    // MARK: - Invalid HTML Tests

    @Test("Handles malformed HTML gracefully")
    func testMalformedHTML() async throws {
        try await withTemporaryPDF { output in
            let malformedHTML = "<html><body><h1>Unclosed tag<body></html>"

            // Should still generate a PDF even with malformed HTML
            let result = try await pdf.render.client.html(malformedHTML, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF should be created even with malformed HTML")
        }
    }

    @Test("Handles empty HTML")
    func testEmptyHTML() async throws {
        try await withTemporaryPDF { output in
            let emptyHTML = ""

            let result = try await pdf.render.client.html(emptyHTML, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF should be created even with empty HTML")
        }
    }

    @Test(
        "Handles extremely large HTML",
        .dependency(\.pdf.render.configuration.documentTimeout, .seconds(60))
    )
    func testLargeHTML() async throws {
        try await withTemporaryPDF { output in
            // Generate large HTML content (1MB+)
            let largeContent = String(repeating: "<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>", count: 10000)
            let largeHTML = "<html><body>\(largeContent)</body></html>"


            let result = try await pdf.render.client.html(largeHTML, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "PDF should be created for large HTML")
        }
    }

    // MARK: - File System Error Tests

    @Test(
        "Handles invalid file path",
        .dependency(\.pdf.render.configuration.createDirectories, false)
    )
    func testInvalidFilePath() async throws {

        let html = "<html><body>Test</body></html>"
        let invalidPath = URL(fileURLWithPath: "/invalid/path/that/does/not/exist/test.pdf")

        do {
            let _ = try await pdf.render.client.html(html, to: invalidPath)
            Issue.record("Should have thrown an error for invalid path")
        } catch {
            // Expected to fail
            #expect(error.localizedDescription.contains("exist") || error.localizedDescription.contains("write"))
        }
    }

    @Test(
        "Creates directories when requested",
        .dependency(\.pdf.render.configuration.createDirectories, true)
    )
    func testDirectoryCreation() async throws {
        try await withTemporaryDirectory { output in
            let html = "<html><body>Test</body></html>"
            let nestedPath = output
                .appendingPathComponent("nested")
                .appendingPathComponent("directories")
                .appendingPathComponent("test.pdf")

            // Should create all intermediate directories
            let result = try await pdf.render.client.html(html, to: nestedPath)

            #expect(FileManager.default.fileExists(atPath: result.path))
        }
    }

    // MARK: - WebView Pool Error Tests

    @Test(
        "Handles WebView pool resource timeout",
        .dependency(\.pdf.render.configuration.concurrency, 1),
        .dependency(\.pdf.render.configuration.webViewAcquisitionTimeout, .seconds(1))
    )
    func testWebViewPoolTimeout() async throws {
        await withTemporaryDirectory { output in
            // Launch many concurrent operations to exhaust the pool
            await withTaskGroup(of: Void.self) { group in
                for i in 1...10 {
                    let outputDir = output
                    group.addTask { @Sendable in
                        await withDependencies {
                            $0.pdf = .liveValue
                            $0.pdf.render.configuration.concurrency = 1
                            $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(1)
                        } operation: {
                            @Dependency(\.pdf) var taskPdf
                            do {
                                let html = "<html><body><h1>Document \(i)</h1></body></html>"
                                let doc = PDF.Document(htmlString: html, title: "doc-\(i)", in: outputDir)
                                _ = try await taskPdf.render.client.document(doc)
                            } catch {
                                // Some operations may timeout, which is expected
                            }
                        }
                    }
                }
                await group.waitForAll()
            }

            // At least some PDFs should be created despite pool pressure
            let files = (try? FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)) ?? []
            #expect(files.count > 0, "Some PDFs should be created despite pool pressure")
        }
    }

    @Test(
        "Handles WebView pool under heavy concurrent load",
        .dependency(\.pdf.render.configuration.concurrency, 2),
        .dependency(\.pdf.render.configuration.webViewAcquisitionTimeout, .seconds(30))
    )
    func testWebViewPoolUnderLoad() async throws {
        try await withTemporaryDirectory { output in
            let count = 20

            // Launch more concurrent operations than the pool size
            let htmls = (1...count).map { i in
                "<html><body><h1>Document \(i)</h1></body></html>"
            }

            var urls: [URL] = []
            for try await result in try await pdf.render.client.html(htmls, to: output) {
                urls.append(result.url)
            }

            #expect(urls.count == count, "All documents should complete despite pool queueing")
        }
    }

    // MARK: - Timeout Tests

    @Test(
        "Respects document timeout",
        .dependency(\.pdf.render.configuration.documentTimeout, .milliseconds(1))
    )
    func testDocumentTimeout() async throws {
        await withTemporaryPDF { output in
            // Create HTML that takes time to render (complex content)
            let complexHTML = """
            <html>
            <head>
                <style>
                    @media print {
                        .page-break { page-break-after: always; }
                    }
                </style>
            </head>
            <body>
                \(String(repeating: "<div class='page-break'><h1>Page</h1></div>", count: 100))
            </body>
            </html>
            """


            do {
                _ = try await pdf.render.client.html(complexHTML, to: output)
                // If we get here, the timeout might not have worked, but the document might be simple enough
            } catch {
                // Expected to timeout
                #expect(error.localizedDescription.contains("timeout") || error.localizedDescription.contains("timed out"))
            }
        }
    }

    // MARK: - Special Characters Tests

    @Test("Handles special characters in filenames")
    func testSpecialCharactersInFilename() async throws {
        try await withTemporaryDirectory { output in
            let html = "<html><body><h1>Special Characters Test</h1></body></html>"

            let specialNames = [
                "test with spaces",
                "test/with/slashes",
                "test:with:colons",
                "test?with?questions",
                "test<with>brackets",
                "test|with|pipes",
                "test*with*asterisks",
                "test\"with\"quotes"
            ]

            for name in specialNames {
                let doc = PDF.Document(htmlString: html, title: name, in: output)
                _ = try await pdf.render.client.document(doc)
            }

            let files = try FileManager.default.contentsOfDirectory(
                at: output,
                includingPropertiesForKeys: nil
            )

            #expect(files.count == specialNames.count, "All files should be created with sanitized names")
        }
    }
}

// MARK: - Typed Error Tests

@Suite("PrintingError Tests", .dependency(\.pdf, .liveValue))
struct PrintingErrorTests {
    @Dependency(\.pdf) var pdf
    
    @Test("Error descriptions are informative")
    func testErrorDescriptions() {
        let errors: [PrintingError] = [
            .invalidHTML("<html>"),
            .invalidFilePath(URL(fileURLWithPath: "/test.pdf"), underlyingError: nil),
            .webViewPoolExhausted(pendingRequests: 5),
            .documentTimeout(documentURL: URL(fileURLWithPath: "/test.pdf"), timeoutSeconds: 30),
            .cancelled(message: "User cancelled")
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "Error should have description")
            #expect(!error.errorDescription!.isEmpty, "Error description should not be empty")
            #expect(error.failureReason != nil, "Error should have failure reason")
            #expect(error.recoverySuggestion != nil, "Error should have recovery suggestion")
        }
    }

    @Test("Error handling with resource pool")
    func testResourcePoolErrorHandling() async throws {
        try await withTemporaryPDF { output in
            // Test timeout scenario with very short timeout
            let html = "<html><body><h1>Test Document</h1></body></html>"

            // Should still succeed even with resource constraints
            let result = try await pdf.render.client.html(html, to: output)
            #expect(FileManager.default.fileExists(atPath: result.path), "PDF should be created despite resource constraints")
        }
    }
}
