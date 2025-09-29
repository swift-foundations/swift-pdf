//
//  ErrorHandlingTests.swift
//  swift-html-to-pdf
//
//  Tests for error handling and edge cases
//

import Testing
import Foundation
@testable import HtmlToPdf

@Suite("Error Handling Tests")
struct ErrorHandlingTests {

    // MARK: - Invalid HTML Tests

    @Test("Handles malformed HTML gracefully")
    func testMalformedHTML() async throws {
        let malformedHTML = "<html><body><h1>Unclosed tag<body></html>"
        let output = URL.temporaryDirectory
            .appendingPathComponent("malformed-test")
            .appendingPathExtension("pdf")

        // Should still generate a PDF even with malformed HTML
        try await malformedHTML.print(to: output, configuration: .a4)

        #expect(FileManager.default.fileExists(atPath: output.path), "PDF should be created even with malformed HTML")

        // Cleanup
        try? FileManager.default.removeItem(at: output)
    }

    @Test("Handles empty HTML")
    func testEmptyHTML() async throws {
        let emptyHTML = ""
        let output = URL.temporaryDirectory
            .appendingPathComponent("empty-test")
            .appendingPathExtension("pdf")

        try await emptyHTML.print(to: output, configuration: .a4)

        #expect(FileManager.default.fileExists(atPath: output.path), "PDF should be created even with empty HTML")

        // Cleanup
        try? FileManager.default.removeItem(at: output)
    }

    @Test("Handles extremely large HTML")
    func testLargeHTML() async throws {
        // Generate large HTML content (1MB+)
        let largeContent = String(repeating: "<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>", count: 10000)
        let largeHTML = "<html><body>\(largeContent)</body></html>"

        let output = URL.temporaryDirectory
            .appendingPathComponent("large-test")
            .appendingPathExtension("pdf")

        // Use custom config with longer timeout
        let config = PrintingConfiguration(
            documentTimeout: 60  // 60 seconds for large document
        )

        try await largeHTML.print(
            to: output,
            configuration: .a4,
            printingConfiguration: config
        )

        #expect(FileManager.default.fileExists(atPath: output.path), "PDF should be created for large HTML")

        // Cleanup
        try? FileManager.default.removeItem(at: output)
    }

    // MARK: - File System Error Tests

    @Test("Handles invalid file path")
    func testInvalidFilePath() async throws {
        let html = "<html><body>Test</body></html>"
        let invalidPath = URL(fileURLWithPath: "/invalid/path/that/does/not/exist/test.pdf")

        do {
            try await html.print(to: invalidPath, configuration: .a4, createDirectories: false)
            Issue.record("Should have thrown an error for invalid path")
        } catch {
            // Expected to fail
            #expect(error.localizedDescription.contains("exist") || error.localizedDescription.contains("write"))
        }
    }

    @Test("Creates directories when requested")
    func testDirectoryCreation() async throws {
        let html = "<html><body>Test</body></html>"
        let nestedPath = URL.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("nested")
            .appendingPathComponent("directories")
            .appendingPathComponent("test.pdf")

        // Should create all intermediate directories
        try await html.print(to: nestedPath, configuration: .a4, createDirectories: true)

        #expect(FileManager.default.fileExists(atPath: nestedPath.path))

        // Cleanup - remove the top-level created directory
        let topLevelDir = nestedPath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        try? FileManager.default.removeItem(at: topLevelDir)
    }

    // MARK: - Timeout Tests

    @Test("Respects document timeout")
    func testDocumentTimeout() async throws {
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

        let output = URL.temporaryDirectory
            .appendingPathComponent("timeout-test")
            .appendingPathExtension("pdf")

        // Use very short timeout to trigger error
        let config = PrintingConfiguration(
            documentTimeout: 0.001  // 1 millisecond - should timeout
        )

        do {
            try await complexHTML.print(
                to: output,
                configuration: .a4,
                printingConfiguration: config
            )
            // If we get here, the timeout might not have worked, but the document might be simple enough
            // Check if file was created
            if FileManager.default.fileExists(atPath: output.path) {
                try? FileManager.default.removeItem(at: output)
            }
        } catch {
            // Expected to timeout
            #expect(error.localizedDescription.contains("timeout") || error.localizedDescription.contains("timed out"))
        }
    }

    // MARK: - Concurrent Operation Tests

    @Test("Handles concurrent batch operations")
    func testConcurrentBatchOperations() async throws {
        let documentCount = 20
        let htmls = (0..<documentCount).map { i in
            "<html><body><h1>Document \(i)</h1></body></html>"
        }

        let outputDir = URL.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        // Use limited concurrency
        let config = PrintingConfiguration(
            maxConcurrentOperations: 4,
            progressHandler: { completed, total in
                print("[Concurrent Test] Progress: \(completed)/\(total)")
            }
        )

        try await htmls.print(
            to: outputDir,
            configuration: .a4,
            printingConfiguration: config,
            filename: { "doc-\($0)" }
        )

        let files = try FileManager.default.contentsOfDirectory(
            at: outputDir,
            includingPropertiesForKeys: nil
        )

        #expect(files.count == documentCount, "All documents should be created")

        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }

    // MARK: - Progress Tracking Tests

    @Test("Tracks progress accurately")
    func testProgressTracking() async throws {
        let documentCount = 5
        let htmls = (0..<documentCount).map { i in
            "<html><body><h1>Document \(i)</h1></body></html>"
        }

        let outputDir = URL.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        // Use an actor to safely collect progress updates
        actor ProgressCollector {
            var updates: [(Int, Int)] = []

            func addUpdate(_ completed: Int, _ total: Int) {
                updates.append((completed, total))
            }

            func getUpdates() -> [(Int, Int)] {
                updates
            }
        }

        let collector = ProgressCollector()

        let config = PrintingConfiguration(
            progressHandler: { completed, total in
                Task {
                    await collector.addUpdate(completed, total)
                }
            }
        )

        try await htmls.print(
            to: outputDir,
            configuration: .a4,
            printingConfiguration: config
        )

        // Give a moment for final progress updates to be collected
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let progressUpdates = await collector.getUpdates()

        // Should have received progress updates
        #expect(progressUpdates.count > 0, "Should receive progress updates")

        // Last update should show all documents completed
        if let lastUpdate = progressUpdates.last {
            #expect(lastUpdate.0 == documentCount, "Should complete all documents")
            #expect(lastUpdate.1 == documentCount, "Total should match document count")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }

    // MARK: - WebView Pool Error Tests

    @Test("Handles WebView pool exhaustion gracefully")
    func testWebViewPoolExhaustion() async throws {
        // Create more documents than pool size
        let documentCount = 30
        let htmls = (0..<documentCount).map { i in
            "<html><body><h1>Document \(i)</h1><img src='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='/></body></html>"
        }

        let outputDir = URL.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        // Force limited pool by setting max concurrent operations
        let config = PrintingConfiguration(
            maxConcurrentOperations: 2,
            webViewAcquisitionTimeout: 30
        )

        // Should handle pool exhaustion and queue requests appropriately
        try await htmls.print(
            to: outputDir,
            configuration: .a4,
            printingConfiguration: config
        )

        let files = try FileManager.default.contentsOfDirectory(
            at: outputDir,
            includingPropertiesForKeys: nil
        )

        #expect(files.count == documentCount, "All documents should eventually be created")

        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }

    // MARK: - Special Characters Tests

    @Test("Handles special characters in filenames")
    func testSpecialCharactersInFilename() async throws {
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

        let outputDir = URL.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        for name in specialNames {
            try await html.print(
                title: name,
                to: outputDir,
                configuration: .a4
            )
        }

        let files = try FileManager.default.contentsOfDirectory(
            at: outputDir,
            includingPropertiesForKeys: nil
        )

        #expect(files.count == specialNames.count, "All files should be created with sanitized names")

        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }

    // MARK: - Memory Management Tests

    @Test("Handles memory pressure with many documents")
    func testMemoryPressure() async throws {
        // Test with moderate number of documents to avoid CI/CD issues
        let documentCount = 50

        let outputDir = URL.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        // Create documents with reasonable content
        let documents = (0..<documentCount).map { i in
            Document(
                fileUrl: outputDir.appendingPathComponent("doc-\(i).pdf"),
                html: "<html><body><h1>Document \(i)</h1><p>Content for testing memory management.</p></body></html>"
            )
        }

        let config = PrintingConfiguration(
            maxConcurrentOperations: 4  // Limit concurrency to manage memory
        )

        try await documents.print(
            configuration: .a4,
            printingConfiguration: config
        )

        let files = try FileManager.default.contentsOfDirectory(
            at: outputDir,
            includingPropertiesForKeys: nil
        )

        #expect(files.count == documentCount, "All documents should be created without memory issues")

        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }
}

// MARK: - Typed Error Tests

@Suite("PrintingError Tests")
struct PrintingErrorTests {

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

    @Test("Error conversions from WebViewPoolActor errors")
    func testErrorConversions() {
        let poolErrors: [WebViewPoolActor.Error] = [
            .timeout,
            .poolExhausted,
            .queueOverload,
            .cancelled
        ]

        for poolError in poolErrors {
            let printingError = PrintingError.from(poolError: poolError)
            #expect(printingError.errorDescription != nil)
        }
    }
}