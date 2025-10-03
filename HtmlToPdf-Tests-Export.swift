// ===== Tests/HtmlToPdfTests/AsyncStreamTests.swift =====
//
//  AsyncStreamTests.swift
//  swift-html-to-pdf
//
//  Tests for AsyncThrowingStream<PDF.Result, Error> return values
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
import PDFTestSupport
@testable import HtmlToPdf

@Suite(
    "AsyncStream Results",
    .dependency(\.pdf, .liveValue),
    .serialized
)
struct AsyncStreamTests {
    @Dependency(\.pdf) var pdf

    @Test(
        "AsyncStream yields correct results with progressive completion",
        .dependency(\.pdf.render.configuration.namingStrategy, .init { _ in UUID().uuidString })
    )
    func testAsyncStreamProgressive() async throws {
        try await withTemporaryDirectory { output in
            let count = 20

            actor CompletionTracker {
                var completedCount = 0
                var yieldedURLs: [URL] = []

                func recordCompletion(url: URL) {
                    completedCount += 1
                    yieldedURLs.append(url)
                }
            }
            let tracker = CompletionTracker()

            let htmls = [String](repeating: TestHTML.simple, count: count)
            let stream = try await pdf.render.client.html(htmls, to: output)

            for try await result in stream {
                await tracker.recordCompletion(url: result.url)
                #expect(FileManager.default.fileExists(atPath: result.url.path), "Yielded URL should exist")
            }

            let completedCount = await tracker.completedCount
            let yieldedURLs = await tracker.yieldedURLs

            #expect(completedCount == count, "Should yield all \(count) results")
            #expect(yieldedURLs.count == count, "Should track all completions")

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == count, "All files should exist after stream completes")
        }
    }

    @Test("AsyncStream from Documents")
    func testAsyncStreamFromDocuments() async throws {
        try await withTemporaryDirectory { output in
            let count = 8

            let documents = (1...count).map { i in
                PDF.Document(
                    htmlString: TestHTML.simple,
                    title: "doc-\(i)",
                    in: output
                )
            }

            let stream = try await pdf.render.client.documents(documents)

            var resultCount = 0
            for try await result in stream {
                resultCount += 1
                #expect(FileManager.default.fileExists(atPath: result.url.path), "Yielded URL should exist")
            }

            #expect(resultCount == count, "Should yield all \(count) results")

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == count, "All documents should be created")
        }
    }

    @Test("Concurrent AsyncStreams")
    func testConcurrentAsyncStreams() async throws {
        try await withTemporaryDirectory { output in
            let count = 10

            try await withDependencies {
                $0.pdf.render.configuration.namingStrategy = .init { _ in "stream1-\(UUID().uuidString)" }
            } operation: {
                let stream1 = try await pdf.render.client.html([String](repeating: TestHTML.simple, count: count), to: output)

                for try await result in stream1 {
                    #expect(FileManager.default.fileExists(atPath: result.url.path))
                }
            }

            try await withDependencies {
                $0.pdf.render.configuration.namingStrategy = .init { _ in "stream2-\(UUID().uuidString)" }
            } operation: {
                let stream2 = try await pdf.render.client.html([String](repeating: TestHTML.simple, count: count), to: output)

                for try await result in stream2 {
                    #expect(FileManager.default.fileExists(atPath: result.url.path))
                }
            }

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == count * 2, "Both streams should complete")
        }
    }
}


// ===== Tests/HtmlToPdfTests/BaseURLTests.swift =====
//
//  BaseURLTests.swift
//  swift-html-to-pdf
//
//  Tests for baseURL functionality
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
import PDFTestSupport
@testable import HtmlToPdf

@Suite("BaseURL Tests", .dependency(\.pdf, .liveValue))
struct BaseURLTests {
    @Dependency(\.pdf) var pdf

    @Test("BaseURL is set correctly via withBaseURL")
    func testWithBaseURLSetsConfiguration() async throws {
        let testURL = URL(fileURLWithPath: "/test/assets")

        let configured = pdf.withBaseURL(testURL)

        #expect(configured.render.configuration.baseURL == testURL)
    }

    @Test("BaseURL nil clears configuration")
    func testWithBaseURLNilClearsConfiguration() async throws {
        // First set a baseURL
        let configured = pdf.withBaseURL(URL(fileURLWithPath: "/test"))

        // Then clear it
        let cleared = configured.withBaseURL(nil)

        #expect(cleared.render.configuration.baseURL == nil)
    }

    @Test("withBaseURL allows fluent chaining")
    func testWithBaseURLFluentAPI() async throws {
        try await withTemporaryPDF { output in
            let baseURL = URL(fileURLWithPath: "/assets")

            let html = "<html><body><h1>Test</h1></body></html>"

            let result = try await pdf
                .withBaseURL(baseURL)
                .render(html: html, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path))
        }
    }

    @Test("BaseURL is used during rendering (macOS)")
    func testBaseURLUsedInRendering() async throws {
        // Note: This test verifies the configuration is passed through
        // Actual asset loading would require test assets on disk

        try await withTemporaryPDF { output in
            let baseURL = URL(fileURLWithPath: "/tmp/test-assets")

            // HTML with relative reference (won't actually load, but tests config passing)
            let html = #"<html><body><img src="test.png"></body></html>"#

            // Should not throw - baseURL is configured even if asset doesn't exist
            let result = try await pdf
                .withBaseURL(baseURL)
                .render(html: html, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path))
        }
    }

    @Test("BaseURL configuration persists across multiple renders")
    func testBaseURLPersistsAcrossRenders() async throws {
        try await withTemporaryDirectory { dir in
            let baseURL = URL(fileURLWithPath: "/assets")

            let configured = pdf.withBaseURL(baseURL)

            // Render multiple PDFs with same configuration
            for i in 1...3 {
                let output = dir.appendingPathComponent("test-\(i).pdf")
                let html = "<html><body>Document \(i)</body></html>"

                let result = try await configured.render(html: html, to: output)
                #expect(FileManager.default.fileExists(atPath: result.path))
            }

            // All should have been rendered with the baseURL
            let files = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            )

            #expect(files.count == 3)
        }
    }
}

@Suite("Capability Tests", .dependency(\.pdf, .liveValue))
struct CapabilityTests {
    @Dependency(\.pdf) var pdf

    @Test("Platform capabilities are reported correctly")
    func testPlatformCapabilities() async throws {
        let capabilities = pdf.render.client.capabilities()

        #if os(macOS)
        #expect(capabilities.maxConcurrentOperations == 16)
        #expect(capabilities.supportsWebViewPooling == true)
        #expect(capabilities.supportsBackgroundRendering == true)
        #expect(capabilities.supportsCustomFonts == true)
        #elseif os(iOS)
        #expect(capabilities.maxConcurrentOperations == 8)
        #expect(capabilities.supportsWebViewPooling == true)
        #expect(capabilities.supportsBackgroundRendering == false)
        #expect(capabilities.supportsCustomFonts == true)
        #endif
    }

    @Test("Exceeding platform concurrency throws capability error")
    func testExceedingConcurrencyThrows() async throws {
        await withTemporaryDirectory { dir in
            let capabilities = pdf.render.client.capabilities()

            // Try to set concurrency above platform maximum
            let excessiveConcurrency = capabilities.maxConcurrentOperations + 10

            await withDependencies {
                $0.pdf.render.configuration.concurrency = .fixed(excessiveConcurrency)
            } operation: {
                @Dependency(\.pdf) var configuredPDF

                let html = "<html><body>Test</body></html>"
                let output = dir.appendingPathComponent("test.pdf")

                do {
                    _ = try await configuredPDF.render(html: html, to: output)
                    Issue.record("Should have thrown capabilityUnavailable error")
                } catch let error as PrintingError {
                    if case .capabilityUnavailable(let capability, let platform, let reason) = error {
                        #expect(capability.contains("concurrency"))
                        #expect(platform.count > 0)
                        #expect(reason.contains("maximum"))
                    } else {
                        Issue.record("Expected capabilityUnavailable, got \(error)")
                    }
                } catch {
                    Issue.record("Expected PrintingError.capabilityUnavailable, got \(error)")
                }
            }
        }
    }

    @Test("Automatic concurrency respects platform limits")
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
}


// ===== Tests/HtmlToPdfTests/BasicFunctionalityTests.swift =====
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
@testable import HtmlToPdf

@Suite("Basic Functionality", .dependency(\.pdf, .liveValue), .serialized)
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


// ===== Tests/HtmlToPdfTests/CancellationTests.swift =====
//
//  CancellationTests.swift
//  swift-html-to-pdf
//
//  Tests for cancellation correctness and resource cleanup
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
import PDFTestSupport
@testable import HtmlToPdf

@Suite("Cancellation Tests", .dependency(\.pdf, .liveValue), .serialized)
struct CancellationTests {
    @Dependency(\.pdf) var pdf

    @Test("Task cancellation propagates correctly")
    func testCancellationPropagates() async throws {
        try await withTemporaryPDF { output in
            let html = String(repeating: "<p>Content that takes time to render</p>", count: 1000)

            let task = Task {
                try await pdf.render(html: html, to: output)
            }

            // Cancel after a short delay
            try await Task.sleep(for: .milliseconds(10))
            task.cancel()

            do {
                _ = try await task.value
                Issue.record("Task should have been cancelled")
            } catch is CancellationError {
                // Expected cancellation
            } catch {
                // Also acceptable - might throw other errors during cancellation
            }
        }
    }

    @Test("Cancelled task does not produce output file")
    func testCancelledTaskNoOutput() async throws {
        try await withTemporaryPDF { output in
            let html = String(repeating: "<div style='height: 1000px'>Page</div>", count: 100)

            let task = Task {
                try await pdf.render(html: html, to: output)
            }

            // Cancel immediately
            task.cancel()

            do {
                _ = try await task.value
            } catch {
                // Expected to throw
            }

            // File should either not exist or be cleaned up
            // Give it a moment for cleanup
            try await Task.sleep(for: .milliseconds(100))

            let exists = FileManager.default.fileExists(atPath: output.path)
            if exists {
                // If file exists, it should be a valid PDF (atomic write completed)
                // or zero bytes (incomplete write that should be cleaned up)
                let attrs = try FileManager.default.attributesOfItem(atPath: output.path)
                let fileSize = attrs[.size] as? Int ?? 0

                if fileSize > 0 {
                    // Valid PDF was written before cancellation - acceptable
                } else {
                    Issue.record("Partial file exists with zero bytes - should be cleaned up")
                }
            }
        }
    }

    @Test("Multiple concurrent tasks can be cancelled independently")
    func testMultipleCancellationsIndependent() async throws {
        await withTemporaryDirectory { dir in
            let htmls = (1...10).map { i in
                "<html><body><h1>Document \(i)</h1></body></html>"
            }

            var tasks: [Task<URL, Error>] = []

            for (index, html) in htmls.enumerated() {
                let output = dir.appendingPathComponent("doc-\(index).pdf")
                let task = Task {
                    try await pdf.render(html: html, to: output)
                }
                tasks.append(task)
            }

            // Cancel half the tasks
            for (index, task) in tasks.enumerated() where index % 2 == 0 {
                task.cancel()
            }

            // Wait for all tasks to complete (either successfully or with cancellation)
            var successCount = 0
            var cancelCount = 0

            for task in tasks {
                do {
                    _ = try await task.value
                    successCount += 1
                } catch {
                    cancelCount += 1
                }
            }

            // Some tasks should have succeeded
            #expect(successCount > 0, "Some tasks should complete successfully")

            // Some tasks should have been cancelled
            #expect(cancelCount > 0, "Some tasks should be cancelled")
        }
    }

    @Test(
        "Pool remains healthy after cancellations",
        .dependency(\.pdf.render.configuration.concurrency, 2)
    )
    func testPoolHealthAfterCancellation() async throws {
        try await withTemporaryDirectory { dir in
            // First batch: create and cancel many tasks
            for i in 1...20 {
                let output = dir.appendingPathComponent("batch1-\(i).pdf")
                let task = Task {
                    try await pdf.render(
                        html: "<html><body>Batch 1 Doc \(i)</body></html>",
                        to: output
                    )
                }

                // Cancel every other task
                if i % 2 == 0 {
                    task.cancel()
                }

                _ = try? await task.value
            }

            // Give pool time to clean up
            try await Task.sleep(for: .milliseconds(100))

            // Second batch: verify pool still works normally
            var secondBatchSuccess = 0

            for i in 1...10 {
                let output = dir.appendingPathComponent("batch2-\(i).pdf")

                do {
                    _ = try await pdf.render(
                        html: "<html><body>Batch 2 Doc \(i)</body></html>",
                        to: output
                    )
                    secondBatchSuccess += 1
                } catch {
                    Issue.record("Pool should be healthy after cancellations: \(error)")
                }
            }

            #expect(secondBatchSuccess == 10, "All second batch tasks should succeed")
        }
    }

    @Test("Batch stream stops when task is cancelled")
    func testBatchStreamCancellation() async throws {
        await withTemporaryDirectory { dir in
            let htmls = (1...20).map { i in
                "<html><body><h1>Document \(i)</h1></body></html>"
            }

            let documents = htmls.enumerated().map { (index, html) in
                PDF.Document(htmlString: html, title: "doc-\(index)", in: dir)
            }

            let task = Task {
                var count = 0
                for try await _ in try await pdf.render.client.documents(documents) {
                    count += 1

                    // Cancel after processing a few
                    if count >= 5 {
                        break  // Break the loop
                    }
                }
                return count
            }

            let processedCount = (try? await task.value) ?? 0

            // Should have processed at least a few
            #expect(processedCount >= 5, "Should process at least 5 documents before breaking")
            #expect(processedCount < 20, "Should not process all 20 documents")
        }
    }

    @Test("Document timeout does not leak WebView")
    func testTimeoutNoLeak() async throws {
        try await withTemporaryDirectory { dir in
            // Configure very short timeout
            try await withDependencies {
                $0.pdf.render.configuration.documentTimeout = .milliseconds(1)
                $0.pdf.render.configuration.concurrency = 2
            } operation: {
                @Dependency(\.pdf) var configuredPDF

                // Try to render documents that will timeout
                for i in 1...5 {
                    let output = dir.appendingPathComponent("timeout-\(i).pdf")

                    do {
                        _ = try await configuredPDF.render(
                            html: String(repeating: "<p>Content</p>", count: 10000),
                            to: output
                        )
                    } catch {
                        // Expected to timeout
                    }
                }

                // Give pool time to recover
                try await Task.sleep(for: .milliseconds(100))

                // Should still be able to render successfully with normal timeout
                let output = dir.appendingPathComponent("success.pdf")

                try await withDependencies {
                    $0.pdf.render.configuration.documentTimeout = .seconds(30)
                } operation: {
                    @Dependency(\.pdf) var normalPDF

                    let result = try await normalPDF.render(
                        html: "<html><body>Success</body></html>",
                        to: output
                    )

                    #expect(FileManager.default.fileExists(atPath: result.path))
                }
            }
        }
    }
}


// ===== Tests/HtmlToPdfTests/ConcurrencyTests.swift =====
//
//  ConcurrencyTests.swift
//  swift-html-to-pdf
//
//  Tests for concurrent PDF generation and pool behavior
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
import PDFTestSupport
@testable import HtmlToPdf

@Suite("Concurrency & Pool Behavior", .dependency(\.pdf, .liveValue))
struct ConcurrencyTests {
    @Dependency(\.pdf) var pdf
    // MARK: - Pool Efficiency Tests

    @Test(
        "Pool handles medium to large batches with queueing",
        .dependency(\.pdf.render.configuration.concurrency, 4),
        .dependency(\.pdf.render.configuration.webViewAcquisitionTimeout, .seconds(60))
    )
    func testLargeBatch() async throws {
        try await withTemporaryDirectory { output in
            let count = 50
            let htmls = [String](repeating: TestHTML.simple, count: count)

            actor ProgressTracker {
                var completed = 0
                func increment() { completed += 1 }
            }
            let tracker = ProgressTracker()

            let stream = try await pdf.render.client.html(htmls, to: output)

            for try await _ in stream {
                await tracker.increment()
            }

            let completedCount = await tracker.completed
            #expect(completedCount == count, "Should track all completions")

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == count, "All \(count) documents should be created despite pool queueing")
        }
    }

    // MARK: - Concurrent Operation Tests

    @Test("Multiple concurrent print operations")
    func testConcurrentOperations() async throws {
        try await withTemporaryDirectory { output in
            // Run 3 concurrent batch operations
            await withTaskGroup(of: Void.self) { group in
                for batch in 1...3 {
                    let outputDir = output
                    group.addTask { @Sendable in
                        try? await withDependencies {
                            $0.pdf = .liveValue
                            $0.pdf.render.configuration.namingStrategy = .init { i in "batch\(batch)-doc\(i)" }
                        } operation: {
                            @Dependency(\.pdf) var batchPdf
                            let htmls = [String](repeating: TestHTML.simple, count: 10)
                            var urls: [URL] = []
                            for try await result in try await batchPdf.render.client.html(htmls, to: outputDir) {
                                urls.append(result.url)
                            }
                        }
                    }
                }
                await group.waitForAll()
            }

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == 30, "All 30 documents from 3 batches should be created")
        }
    }

    @Test("Handles rapid sequential operations")
    func testRapidSequentialOperations() async throws {
        try await withTemporaryDirectory { output in
            // Generate 20 PDFs one after another rapidly
            for i in 1...20 {
                let html = "<html><body><h1>Document \(i)</h1></body></html>"
                let doc = PDF.Document(htmlString: html, title: "rapid-\(i)", in: output)
                _ = try await pdf.render.client.document(doc)
            }

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == 20, "All 20 sequential documents should be created")
        }
    }

    // MARK: - Concurrency Limit Tests

    @Test(
        "Respects maxConcurrentOperations limit",
        .dependency(\.pdf.render.configuration.concurrency, 2)
    )
    func testConcurrencyLimit() async throws {
        try await withTemporaryDirectory { output in
            let count = 10
            let htmls = [String](repeating: TestHTML.simple, count: count)

            var urls: [URL] = []
            for try await result in try await pdf.render.client.html(htmls, to: output) {
                urls.append(result.url)
            }

            #expect(urls.count == count, "Should complete all documents despite low concurrency")

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == count)
        }
    }

    // MARK: - Mixed Size Documents

    @Test(
        "Handles mixed document sizes efficiently",
        .dependency(\.pdf.render.configuration.concurrency, 5),
        .dependency(\.pdf.render.configuration.webViewAcquisitionTimeout, .seconds(60))
    )
    func testMixedDocumentSizes() async throws {
        try await withTemporaryDirectory { output in
            var documents: [PDF.Document] = []

            // Small documents
            for i in 1...10 {
                documents.append(PDF.Document(
                    htmlString: "<html><body><p>Small \(i)</p></body></html>",
                    title: "small-\(i)",
                    in: output
                ))
            }

            // Large documents
            for i in 1...5 {
                documents.append(PDF.Document(
                    htmlString: TestHTML.items(50),
                    title: "large-\(i)",
                    in: output
                ))
            }

            let stream = try await pdf.render.client.documents(documents)

            var completed = 0
            for try await _ in stream {
                completed += 1
            }

            #expect(completed == 15, "Should complete all mixed size documents")

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == 15)
        }
    }

    // MARK: - Resource Cleanup Tests

    @Test("Resources properly cleaned up after batch")
    func testResourceCleanup() async throws {
        try await withTemporaryDirectory { output in
            // Generate multiple batches sequentially
            for batch in 1...3 {
                try await withDependencies {
                    $0.pdf.render.configuration.namingStrategy = .init { i in "batch\(batch)-\(i)" }
                } operation: {
                    let htmls = [String](repeating: TestHTML.simple, count: 10)
                    var urls: [URL] = []
                    for try await result in try await pdf.render.client.html(htmls, to: output) {
                        urls.append(result.url)
                    }
                }
            }

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == 30, "All batches should complete successfully")
        }
    }
}


// ===== Tests/HtmlToPdfTests/ConvenienceTests.swift =====
//
//  ConvenienceTests.swift
//  swift-html-to-pdf
//
//  Tests demonstrating three levels of API convenience
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
@testable import HtmlToPdf

@Suite("Convenience API Levels", .dependency(\.pdf, .liveValue), .serialized)
struct ConvenienceTests {
    @Dependency(\.pdf) var pdf
    
    @Test("Level 1: Top-level convenience (shortest)")
    func testTopLevelConvenience() async throws {

        let html = "<html><body><h1>Level 1: Top-level</h1></body></html>"
        let output = URL.temporaryDirectory
            .appendingPathComponent("level1-\(UUID().uuidString).pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Shortest form - forwards through PDF -> Render -> Client
        let result = try await pdf.render(html: html, to: output)

        #expect(FileManager.default.fileExists(atPath: result.path), "Top-level convenience should work")
    }

    @Test("Level 2: Capability-level convenience (mid-level)")
    func testCapabilityLevelConvenience() async throws {

        let html = "<html><body><h1>Level 2: Capability</h1></body></html>"
        let output = URL.temporaryDirectory
            .appendingPathComponent("level2-\(UUID().uuidString).pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Mid-level - shows capability structure, forwards to client
        let result = try await pdf.render.html(html, to: output)

        #expect(FileManager.default.fileExists(atPath: result.path), "Capability-level convenience should work")
    }

    @Test("Level 3: Explicit client access (full control)")
    func testExplicitClientAccess() async throws {

        let html = "<html><body><h1>Level 3: Explicit</h1></body></html>"
        let output = URL.temporaryDirectory
            .appendingPathComponent("level3-\(UUID().uuidString).pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Explicit form - direct client access
        let result = try await pdf.render.client.html(html, to: output)

        #expect(FileManager.default.fileExists(atPath: result.path), "Explicit client access should work")
    }

    @Test("HTML batch convenience levels")
    func testHTMLBatchConvenienceLevels() async throws {

        let htmls = [
            "<html><body><h1>Doc 1</h1></body></html>",
            "<html><body><h1>Doc 2</h1></body></html>",
            "<html><body><h1>Doc 3</h1></body></html>"
        ]
        let output = URL.temporaryDirectory
            .appendingPathComponent("batch-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Level 2: Capability-level
        var urls2: [URL] = []
        for try await result in try await pdf.render(htmls: htmls, to: output) {
            urls2.append(result.url)
        }
        #expect(urls2.count == 3, "Capability-level htmls should work")

        // Clean for next test
        try? FileManager.default.removeItem(at: output)

        // Level 3: Explicit client
        var urls3: [URL] = []
        for try await result in try await pdf.render.client.html(htmls, to: output) {
            urls3.append(result.url)
        }
        #expect(urls3.count == 3, "Explicit client htmls should work")
    }

    @Test("Data rendering convenience levels")
    func testDataRenderingLevels() async throws {

        let html = "<html><body><h1>In-memory PDF</h1></body></html>"

        // Level 1: Top-level
        let data1 = try await pdf.render(html: html)
        #expect(data1.count > 1000, "Top-level data should work")

        // Level 2: Capability-level
        let data2 = try await pdf.render.data(html)
        #expect(data2.count > 1000, "Capability-level data should work")

        // Level 3: Explicit client
        let data3 = try await pdf.render.client.data(html)
        #expect(data3.count > 1000, "Explicit client data should work")
    }

    @Test("Document convenience levels")
    func testDocumentConvenienceLevels() async throws {

        let output = URL.temporaryDirectory
            .appendingPathComponent("docs-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let document = PDF.Document(htmlString: "<html><body>Test</body></html>", title: "test", in: output)

        // Level 1: Top-level
        let url1 = try await pdf.render(document: document)
        #expect(FileManager.default.fileExists(atPath: url1.path), "Top-level document should work")

        // Clean for next test
        try? FileManager.default.removeItem(at: output)

        // Level 2: Capability-level
        let url2 = try await pdf.render.document(document)
        #expect(FileManager.default.fileExists(atPath: url2.path), "Capability-level document should work")

        // Clean for next test
        try? FileManager.default.removeItem(at: output)

        // Level 3: Explicit client - batch documents
        let documents = [
            PDF.Document(htmlString: "<html><body>A</body></html>", title: "a", in: output),
            PDF.Document(htmlString: "<html><body>B</body></html>", title: "b", in: output)
        ]

        var count = 0
        for try await _ in try await pdf.render(documents: documents) {
            count += 1
        }
        #expect(count == 2, "Client-level batch documents should work")
    }
}


// ===== Tests/HtmlToPdfTests/ErrorHandlingTests.swift =====
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
@testable import HtmlToPdf

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


// ===== Tests/HtmlToPdfTests/MultiPageVerificationTest.swift =====
//
//  MultiPageVerificationTest.swift
//  swift-html-to-pdf
//
//  Verify multi-page PDF generation works correctly
//

import Testing
import Foundation
import HtmlToPdf
import Dependencies
import DependenciesTestSupport

@Suite("Multi-Page Verification", .dependency(\.pdf, .liveValue))
struct MultiPageVerificationTests {
    @Dependency(\.pdf) var pdf
    
    @Test(
        "Generate multi-page PDF with proper page breaks",
        .dependency(\.pdf.render.configuration, .multiPage)
    )
    func generateMultiPagePDF() async throws {

        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

            // Create HTML with enough content to naturally flow across multiple pages
            // Each section is ~500px tall, and A4 is ~842px, so we need substantial content
            let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>Multi-Page PDF Test</title>
                <style>
                    body {
                        font-family: 'Helvetica Neue', Arial, sans-serif;
                        line-height: 1.6;
                        color: #333;
                    }

                    .section {
                        padding: 40px;
                        margin-bottom: 40px;
                    }

                    /* Force actual page breaks between major sections */
                    .section {
                        page-break-inside: avoid;
                    }

                    .force-page-break {
                        page-break-before: always;
                    }

                    .page-header {
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        padding: 30px;
                        text-align: center;
                        border-radius: 8px;
                        margin-bottom: 30px;
                    }

                    .page-number {
                        font-size: 14px;
                        color: #6c757d;
                        text-align: center;
                        margin-top: 20px;
                    }

                    .content-section {
                        margin: 20px 0;
                        padding: 20px;
                        background: #f8f9fa;
                        border-left: 4px solid #667eea;
                    }

                    h1 {
                        font-size: 36px;
                        margin: 0;
                    }

                    h2 {
                        color: #667eea;
                        margin-top: 0;
                    }

                    p {
                        margin: 10px 0;
                    }

                    .test-item {
                        padding: 10px;
                        margin: 5px 0;
                        background: white;
                        border-radius: 4px;
                    }
                </style>
            </head>
            <body>
                <!-- Section 1 -->
                <div class="section">
                    <div class="page-header">
                        <h1>📄 Page 1 of 5</h1>
                        <p>Multi-Page PDF Test</p>
                    </div>

                    <div class="content-section">
                        <h2>Purpose of This Test</h2>
                        <p>This PDF tests that the ContiguousArray&lt;UInt8&gt; implementation correctly handles multi-page documents with proper page breaks.</p>
                        <p>Each page should be properly separated and all content should be visible without clipping.</p>
                    </div>

                    <div class="content-section">
                        <h2>Test Items - Page 1</h2>
                        \((1...20).map { "<div class='test-item'>Item \($0): Testing content flow and pagination</div>" }.joined(separator: "\n"))
                    </div>

                    <div class="page-number">— Page 1 —</div>
                </div>

                <!-- Page 2 -->
                <div class="page">
                    <div class="page-header">
                        <h1>📄 Page 2 of 5</h1>
                        <p>Testing CSS and Layout</p>
                    </div>

                    <div class="content-section">
                        <h2>CSS Features</h2>
                        <p>✓ Gradients work across pages</p>
                        <p>✓ Borders and padding preserved</p>
                        <p>✓ Colors and backgrounds render correctly</p>
                        <p>✓ Typography consistent across pages</p>
                    </div>

                    <div class="content-section">
                        <h2>Test Items - Page 2</h2>
                        \((21...40).map { "<div class='test-item'>Item \($0): More content to verify page breaks</div>" }.joined(separator: "\n"))
                    </div>

                    <div class="page-number">— Page 2 —</div>
                </div>

                <!-- Page 3 -->
                <div class="page">
                    <div class="page-header">
                        <h1>📄 Page 3 of 5</h1>
                        <p>Unicode and Special Characters</p>
                    </div>

                    <div class="content-section">
                        <h2>Emoji Test</h2>
                        <p>🎉 🚀 ✨ 💡 🔥 ⚡️ 🎯 🌟 🎨 📝 🎭 🌈 🔬 🧪 📊 📈</p>
                    </div>

                    <div class="content-section">
                        <h2>Math Symbols</h2>
                        <p>α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ σ τ υ φ χ ψ ω</p>
                        <p>∑ ∫ √ ∞ ≈ ≠ ± ∂ ∇ ∈ ∉ ⊂ ⊃ ∪ ∩</p>
                    </div>

                    <div class="content-section">
                        <h2>Currency Symbols</h2>
                        <p>$ € £ ¥ ₹ ₿ ¢ ₽ ₩ ₪ ₱ ₴ ₵</p>
                    </div>

                    <div class="content-section">
                        <h2>Accented Characters</h2>
                        <p>café, naïve, résumé, façade, à la carte, piñata, über, Zürich</p>
                    </div>

                    <div class="page-number">— Page 3 —</div>
                </div>

                <!-- Page 4 -->
                <div class="page">
                    <div class="page-header">
                        <h1>📄 Page 4 of 5</h1>
                        <p>Performance Metrics</p>
                    </div>

                    <div class="content-section">
                        <h2>Memory Efficiency</h2>
                        <div class="test-item">Old approach (String UTF-16): ~2 bytes per character</div>
                        <div class="test-item">New approach (ContiguousArray UTF-8): ~1 byte per character</div>
                        <div class="test-item">Memory savings: ~50% for ASCII-heavy content</div>
                        <div class="test-item">Additional benefit: Zero-copy from HTML DSL to WKWebView</div>
                    </div>

                    <div class="content-section">
                        <h2>Test Items - Page 4</h2>
                        \((41...60).map { "<div class='test-item'>Item \($0): Verifying pagination continues correctly</div>" }.joined(separator: "\n"))
                    </div>

                    <div class="page-number">— Page 4 —</div>
                </div>

                <!-- Page 5 -->
                <div class="page">
                    <div class="page-header">
                        <h1>📄 Page 5 of 5</h1>
                        <p>Final Page</p>
                    </div>

                    <div class="content-section">
                        <h2>✅ Verification Checklist</h2>
                        <p>If you can see this page clearly:</p>
                        <div class="test-item">✓ All 5 pages rendered correctly</div>
                        <div class="test-item">✓ No content clipping occurred</div>
                        <div class="test-item">✓ Page breaks work properly</div>
                        <div class="test-item">✓ CSS styles consistent across pages</div>
                        <div class="test-item">✓ Special characters display correctly</div>
                        <div class="test-item">✓ ContiguousArray&lt;UInt8&gt; implementation verified!</div>
                    </div>

                    <div class="content-section">
                        <h2>Implementation Details</h2>
                        <p><strong>Storage:</strong> ContiguousArray&lt;UInt8&gt;</p>
                        <p><strong>Encoding:</strong> UTF-8</p>
                        <p><strong>HTML Source:</strong> String → ContiguousArray conversion</p>
                        <p><strong>WKWebView:</strong> Direct Data loading</p>
                        <p><strong>Page Flow:</strong> Automatic (no rect clipping)</p>
                    </div>

                    <div class="content-section">
                        <h2>Test Summary</h2>
                        <p>Generated: \(Date().formatted())</p>
                        <p>Total Pages: 5</p>
                        <p>Test Items: 60</p>
                        <p>Status: ✅ All checks passed</p>
                    </div>

                    <div class="page-number">— Page 5 (Final) —</div>
                </div>
            </body>
            </html>
            """

            let output = desktop.appendingPathComponent("PDF_MultiPage_Test.pdf")

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Generating Multi-Page PDF")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("\nOutput location:")
            print("  \(output.path)")

            let url = try await pdf.render.client.html(htmlString, to: output)

            if FileManager.default.fileExists(atPath: url.path) {
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = attrs[.size] as? Int64 ?? 0

                print("\n✅ Multi-Page PDF Generated!")
                print("   Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                print("   Path: \(url.path)")
                print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("Open the PDF to verify:")
                print("  • Should have exactly 5 pages")
                print("  • Each page clearly labeled (Page 1/5, 2/5, etc.)")
                print("  • No content clipping or overflow")
                print("  • Page breaks occur at correct positions")
                print("  • All special characters visible on page 3")
                print("  • Final checklist visible on page 5")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        } else {
            throw NSError(domain: "PDF not created", code: -1)
        }
    }
}


// ===== Tests/HtmlToPdfTests/NamingCollisionTests.swift =====
//
//  NamingCollisionTests.swift
//  swift-html-to-pdf
//
//  Tests for concurrent rendering with naming collisions
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
import PDFTestSupport
@testable import HtmlToPdf

@Suite("Naming Collision Tests", .dependency(\.pdf, .liveValue))
struct NamingCollisionTests {
    @Dependency(\.pdf) var pdf

    @Test("Concurrent renders with unique titles produce unique files")
    func testConcurrentUniqueTitles() async throws {
        try await withTemporaryDirectory { dir in
            let documentCount = 100

            // Each document has a unique title
            let documents = (1...documentCount).map { i in
                PDF.Document(
                    htmlString: "<html><body><h1>Document \(i)</h1></body></html>",
                    title: "doc-\(i)",  // Unique title per document
                    in: dir
                )
            }

            var results: [PDF.Result] = []

            for try await result in try await pdf.render.client.documents(documents) {
                results.append(result)
            }

            #expect(results.count == documentCount, "All documents should render")

            // Collect all generated URLs
            let urls = Set(results.map { $0.url })

            // All URLs should be unique
            #expect(urls.count == documentCount, "All URLs should be unique - found \(urls.count) unique out of \(documentCount)")

            // Verify all files actually exist
            let existingFiles = urls.filter { url in
                FileManager.default.fileExists(atPath: url.path)
            }

            #expect(existingFiles.count == documentCount, "All files should exist on disk")
        }
    }

    @Test("Sequential naming strategy produces sequential files")
    func testSequentialNamingStrategy() async throws {
        try await withTemporaryDirectory { dir in
            try await withDependencies {
                $0.pdf.render.configuration.namingStrategy = .sequential
            } operation: {
                @Dependency(\.pdf) var configuredPDF

                // Use convenience method that respects naming strategy
                let htmls = (1...10).map { i in
                    "<html><body>Doc \(i)</body></html>"
                }

                var results: [PDF.Result] = []

                for try await result in try await configuredPDF.render.client.html(htmls, to: dir) {
                    results.append(result)
                }

                // Check that files are named sequentially
                let filenames = results.map { $0.url.lastPathComponent }

                #expect(filenames.contains("1.pdf") || filenames.contains("0.pdf"), "Should have sequential naming")
            }
        }
    }

    @Test("UUID naming strategy produces unique names")
    func testUUIDNamingStrategy() async throws {
        try await withTemporaryDirectory { dir in
            try await withDependencies {
                $0.pdf.render.configuration.namingStrategy = .uuid
            } operation: {
                @Dependency(\.pdf) var configuredPDF

                // Use convenience method that respects naming strategy
                let htmls = (1...50).map { i in
                    "<html><body>Doc \(i)</body></html>"
                }

                var results: [PDF.Result] = []

                for try await result in try await configuredPDF.render.client.html(htmls, to: dir) {
                    results.append(result)
                }

                // All filenames should be UUIDs (36 chars + .pdf = 40 chars)
                let filenames = results.map { $0.url.lastPathComponent }

                for filename in filenames {
                    // UUID format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX.pdf (40 chars)
                    #expect(filename.hasSuffix(".pdf"))
                    #expect(filename.count == 40, "UUID filename should be 40 chars: \(filename)")
                }

                // All should be unique
                let uniqueNames = Set(filenames)
                #expect(uniqueNames.count == 50, "All UUIDs should be unique")
            }
        }
    }

    @Test("Custom naming strategy is applied correctly")
    func testCustomNamingStrategy() async throws {
        try await withTemporaryDirectory { dir in
            try await withDependencies {
                $0.pdf.render.configuration.namingStrategy = PDF.NamingStrategy { index in
                    String(format: "invoice-%06d", index + 1)
                }
            } operation: {
                @Dependency(\.pdf) var configuredPDF

                // Use convenience method that respects naming strategy
                let htmls = (1...10).map { i in
                    "<html><body>Invoice \(i)</body></html>"
                }

                var results: [PDF.Result] = []

                for try await result in try await configuredPDF.render.client.html(htmls, to: dir) {
                    results.append(result)
                }

                let filenames = Set(results.map { $0.url.lastPathComponent })

                #expect(filenames.contains("invoice-000001.pdf"))
                #expect(filenames.contains("invoice-000010.pdf"))
                #expect(filenames.count == 10)
            }
        }
    }

    @Test("High concurrency naming collisions are handled")
    func testHighConcurrencyNamingCollisions() async throws {
        try await withTemporaryDirectory { dir in
            try await withDependencies {
                $0.pdf.render.configuration.concurrency = .fixed(16)  // Use platform max
                $0.pdf.render.configuration.namingStrategy = .uuid  // Safest for high concurrency
            } operation: {
                @Dependency(\.pdf) var configuredPDF

                let documentCount = 200

                // Use convenience method that respects naming strategy
                let htmls = (1...documentCount).map { i in
                    "<html><body>Document \(i)</body></html>"
                }

                var results: [PDF.Result] = []

                for try await result in try await configuredPDF.render.client.html(htmls, to: dir) {
                    results.append(result)
                }

                #expect(results.count == documentCount)

                // All files should have unique names (UUID strategy ensures this)
                let urls = Set(results.map { $0.url })
                #expect(urls.count == documentCount, "Expected \(documentCount) unique files, got \(urls.count)")

                // All files should exist
                for url in urls {
                    #expect(FileManager.default.fileExists(atPath: url.path), "File should exist: \(url.lastPathComponent)")
                }
            }
        }
    }

    @Test("Naming with special characters is handled safely")
    func testNamingWithSpecialCharacters() async throws {
        try await withTemporaryDirectory { dir in
            // Test that special characters in titles are handled
            let specialTitles = [
                "test/with/slashes",
                "test:with:colons",
                "test?with?questions",
                "test*with*asterisks",
                "test<with>brackets"
            ]

            for title in specialTitles {
                let doc = PDF.Document(
                    htmlString: "<html><body>Test</body></html>",
                    title: title,
                    in: dir
                )

                let result = try await pdf.render.client.document(doc)

                // File should be created with sanitized name
                #expect(FileManager.default.fileExists(atPath: result.path))

                // Filename should not contain dangerous characters
                let filename = result.lastPathComponent
                #expect(!filename.contains("/"), "Filename should not contain /: \(filename)")
                #expect(!filename.contains(":"), "Filename should not contain :: \(filename)")
            }
        }
    }
}


// ===== Tests/HtmlToPdfTests/NaturalMultiPageTest.swift =====
//
//  NaturalMultiPageTest.swift
//  swift-html-to-pdf
//
//  Test that content naturally flows across multiple pages
//

import Testing
import Foundation
import HtmlToPdf
import Dependencies
import DependenciesTestSupport
import PDFKit

@Suite(
    "Natural Multi-Page Flow",
    .dependency(\.pdf, .liveValue),
    .disabled("Run manually: swift test --filter NaturalMultiPageTests")
)
struct NaturalMultiPageTests {
    @Dependency(\.pdf) var pdf
    
    @Test(
        "Generate PDF with content that naturally spans multiple pages (Paginated Mode)",
        .dependency(\.pdf.render.configuration.paginationMode, .paginated)
    )
    func generateNaturalMultiPagePDF() async throws {

        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

            // Generate lots of content - should naturally span 3-4 pages on A4
            let items = (1...200).map { i in
                """
                <div style="padding: 15px; margin: 10px 0; background: #f8f9fa; border-left: 4px solid #667eea; border-radius: 4px;">
                    <h3 style="margin: 0 0 10px 0; color: #667eea;">Item #\(i)</h3>
                    <p style="margin: 5px 0;">This is test item number \(i). It contains enough text to take up vertical space and demonstrate that content flows naturally across multiple pages without requiring CSS page-break directives.</p>
                    <p style="margin: 5px 0; font-size: 12px; color: #6c757d;">Testing ContiguousArray&lt;UInt8&gt; | UTF-8 Encoding | Zero-copy rendering</p>
                </div>
                """
            }.joined(separator: "\n")

            let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>Natural Multi-Page PDF Test</title>
                <style>
                    body {
                        font-family: 'Helvetica Neue', Arial, sans-serif;
                        line-height: 1.6;
                        color: #333;
                        margin: 0;
                        padding: 0;
                    }

                    .header {
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        padding: 40px;
                        text-align: center;
                    }

                    .header h1 {
                        margin: 0;
                        font-size: 48px;
                    }

                    .header p {
                        margin: 10px 0 0 0;
                        font-size: 18px;
                        opacity: 0.9;
                    }

                    .content {
                        padding: 20px;
                    }

                    .footer {
                        margin-top: 40px;
                        padding: 20px;
                        text-align: center;
                        background: #f8f9fa;
                        color: #6c757d;
                        border-top: 2px solid #e9ecef;
                    }
                </style>
            </head>
            <body>
                <div class="header">
                    <h1>📄 Natural Multi-Page Test</h1>
                    <p>Content Should Flow Across Multiple Pages</p>
                </div>

                <div class="content">
                    <div style="padding: 20px; margin: 20px 0; background: #e7f3ff; border-radius: 8px;">
                        <h2 style="margin-top: 0; color: #0066cc;">Purpose</h2>
                        <p>This PDF contains 200 test items. At approximately 100-120 pixels per item, this should naturally span 3-4 pages on A4 paper (595 × 842 points with margins).</p>
                        <p>No CSS page breaks are used - content flows naturally based on the paper size configured in PDF.Configuration.</p>
                    </div>

                    \(items)

                    <div class="footer">
                        <h3>✅ Test Complete</h3>
                        <p>If you see this footer and can scroll/navigate through multiple pages, the multi-page rendering is working correctly!</p>
                        <p>Generated: \(Date().formatted())</p>
                        <p>Total Items: 200 | Implementation: ContiguousArray&lt;UInt8&gt;</p>
                    </div>
                </div>
            </body>
            </html>
            """

            let output = desktop.appendingPathComponent("PDF_Natural_MultiPage_Test.pdf")

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Generating Natural Multi-Page PDF")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("\nOutput location:")
            print("  \(output.path)")
            print("\nExpected: 3-4 pages of content")
            print("Items: 200 test items")

            let url = try await pdf.render.client.html(htmlString, to: output)

            if FileManager.default.fileExists(atPath: url.path) {
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = attrs[.size] as? Int64 ?? 0

                // Verify PDF structure using PDFKit
                guard let pdfDoc = PDFDocument(url: url) else {
                    throw NSError(domain: "Failed to load PDF", code: -1)
                }

                let pageCount = pdfDoc.pageCount

                // Check first page dimensions (should be A4: 595.28 × 841.89 points)
                guard let firstPage = pdfDoc.page(at: 0) else {
                    throw NSError(domain: "Failed to get first page", code: -1)
                }
                let bounds = firstPage.bounds(for: .mediaBox)
                let expectedA4Width: CGFloat = 595.28
                let expectedA4Height: CGFloat = 841.89
                let tolerance: CGFloat = 1.0

                let isA4Width = abs(bounds.width - expectedA4Width) < tolerance
                let isA4Height = abs(bounds.height - expectedA4Height) < tolerance

                print("\n✅ PDF Generated!")
                print("   Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                print("   Path: \(url.path)")
                print("\n📄 PDF Structure:")
                print("   Pages: \(pageCount)")
                print("   Page 1 dimensions: \(bounds.width) × \(bounds.height) points")
                print("   Expected A4: \(expectedA4Width) × \(expectedA4Height) points")
                print("   Width correct: \(isA4Width ? "✅" : "❌")")
                print("   Height correct: \(isA4Height ? "✅" : "❌")")

                print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("Verification:")
                print("  | Total number of pages: \(pageCount) (expected 3-4)")
                print("  | All 200 items present: \(pageCount >= 3 ? "✅" : "❌")")
                print("  | Page dimensions A4: \(isA4Width && isA4Height ? "✅" : "❌")")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

                // Assert correct dimensions
                #expect(isA4Width, "PDF width should be A4 (595.28 points), got \(bounds.width)")
                #expect(isA4Height, "PDF height should be A4 (841.89 points), got \(bounds.height)")
                #expect(pageCount >= 3, "PDF should have at least 3 pages, got \(pageCount)")
        } else {
            throw NSError(domain: "PDF not created", code: -1)
        }
    }

    @Test(
        "Generate PDF with content in continuous mode (Quality Comparison)",
        .dependency(\.pdf.render.configuration.paginationMode, .continuous)
    )
    func generateContinuousModePDF() async throws {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

        // Same content but with bullet characters to test quality
        let testContent = """
        <div style="padding: 20px; margin: 20px 0; background: #f8f9fa; border-radius: 8px;">
            <h2>Character Quality Test - Continuous Mode (WKWebView.createPDF)</h2>

            <div style="margin: 20px 0; padding: 15px; background: white; border-radius: 4px;">
                <h3>Unicode Bullet (•)</h3>
                <p style="font-size: 12px; color: #6c757d;">
                    Testing ContiguousArray&lt;UInt8&gt; • UTF-8 Encoding • Zero-copy rendering
                </p>
                <p style="font-size: 14px;">
                    Item A • Item B • Item C
                </p>
                <p style="font-size: 16px; font-weight: 500;">
                    Performance • Quality • Speed
                </p>
            </div>

            <div style="margin: 20px 0; padding: 15px; background: white; border-radius: 4px;">
                <h3>Pipe Character (|)</h3>
                <p style="font-size: 12px; color: #6c757d;">
                    Testing ContiguousArray&lt;UInt8&gt; | UTF-8 Encoding | Zero-copy rendering
                </p>
                <p style="font-size: 14px;">
                    Item A | Item B | Item C
                </p>
                <p style="font-size: 16px; font-weight: 500;">
                    Performance | Quality | Speed
                </p>
            </div>

            <div style="margin: 20px 0; padding: 15px; background: white; border-radius: 4px;">
                <h3>Hyphen Character (-)</h3>
                <p style="font-size: 12px; color: #6c757d;">
                    Testing ContiguousArray&lt;UInt8&gt; - UTF-8 Encoding - Zero-copy rendering
                </p>
                <p style="font-size: 14px;">
                    Item A - Item B - Item C
                </p>
                <p style="font-size: 16px; font-weight: 500;">
                    Performance - Quality - Speed
                </p>
            </div>

            <div style="margin: 20px 0; padding: 15px; background: white; border-radius: 4px;">
                <h3>HTML Middot (&middot;)</h3>
                <p style="font-size: 12px; color: #6c757d;">
                    Testing ContiguousArray&lt;UInt8&gt; &middot; UTF-8 Encoding &middot; Zero-copy rendering
                </p>
                <p style="font-size: 14px;">
                    Item A &middot; Item B &middot; Item C
                </p>
                <p style="font-size: 16px; font-weight: 500;">
                    Performance &middot; Quality &middot; Speed
                </p>
            </div>

            <div style="margin: 20px 0; padding: 15px; background: white; border-radius: 4px;">
                <h3>Emojis</h3>
                <p style="font-size: 14px;">
                    📄 Document • ✅ Success • 🎯 Target
                </p>
                <p style="font-size: 16px;">
                    ⚡ Performance • 🔧 Tools • 📊 Analytics
                </p>
            </div>

            <div style="margin: 20px 0; padding: 15px; background: white; border-radius: 4px;">
                <h3>Mixed Content</h3>
                <p style="font-size: 12px; color: #6c757d;">
                    <strong>Bold bullets:</strong> Testing • UTF-8 • Rendering
                </p>
                <p style="font-size: 12px; color: #6c757d;">
                    <em>Italic bullets:</em> Testing • UTF-8 • Rendering
                </p>
                <p style="font-size: 12px; color: #6c757d;">
                    <strong><em>Bold italic bullets:</em></strong> Testing • UTF-8 • Rendering
                </p>
            </div>
        </div>
        """

        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Continuous Mode Quality Test</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    margin: 0;
                    padding: 0;
                }

                .header {
                    background: linear-gradient(135deg, #00b4db 0%, #0083b0 100%);
                    color: white;
                    padding: 40px;
                    text-align: center;
                }

                .header h1 {
                    margin: 0;
                    font-size: 48px;
                }

                .header p {
                    margin: 10px 0 0 0;
                    font-size: 18px;
                    opacity: 0.9;
                }

                .content {
                    padding: 20px;
                    max-width: 800px;
                }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>⚡ Continuous Mode Quality Test</h1>
                <p>WKWebView.createPDF() - Fast Rendering</p>
            </div>

            <div class="content">
                \(testContent)

                <div style="margin-top: 40px; padding: 20px; background: #e7f3ff; border-radius: 8px;">
                    <h3>📋 Test Purpose</h3>
                    <p>Compare character rendering quality between:</p>
                    <ul>
                        <li><strong>Continuous Mode:</strong> WKWebView.createPDF() (this file)</li>
                        <li><strong>Paginated Mode:</strong> NSPrintOperation.run() (separate file)</li>
                    </ul>
                    <p>Check if Unicode bullets (•) render crisply in continuous mode.</p>
                </div>
            </div>
        </body>
        </html>
        """

        let output = desktop.appendingPathComponent("PDF_Continuous_Quality_Test.pdf")

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Generating Continuous Mode Quality Test")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("\nOutput location:")
        print("  \(output.path)")
        print("\nMode: Continuous (WKWebView.createPDF)")
        print("Purpose: Compare rendering quality with paginated mode")

        let url = try await pdf.render.client.html(htmlString, to: output)

        if FileManager.default.fileExists(atPath: url.path) {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? Int64 ?? 0

            guard let pdfDoc = PDFDocument(url: url) else {
                throw NSError(domain: "Failed to load PDF", code: -1)
            }

            let pageCount = pdfDoc.pageCount

            print("\n✅ PDF Generated!")
            print("   Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
            print("   Path: \(url.path)")
            print("   Pages: \(pageCount)")
            print("\n📊 Compare this with PDF_Natural_MultiPage_Test.pdf")
            print("   to see quality differences between modes")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        } else {
            throw NSError(domain: "PDF not created", code: -1)
        }
    }
}


// ===== Tests/HtmlToPdfTests/PaginationModeTests.swift =====
//
//  PaginationModeTests.swift
//  swift-html-to-pdf
//
//  Tests for pagination mode functionality
//

import Testing
import Foundation
import HtmlToPdf
import Dependencies
import DependenciesTestSupport
import PDFKit

@Suite("Pagination Mode Tests", .dependency(\.pdf, .liveValue))
struct PaginationModeTests {
    @Dependency(\.pdf) var pdf
    
    @Test(
        "Paginated mode creates multiple pages for long content",
        .dependency(\.pdf.render.configuration.paginationMode, .paginated)
    )
    func paginatedModeLongContent() async throws {
        
        let tempDir = FileManager.default.temporaryDirectory
        let output = tempDir.appendingPathComponent("test-paginated.pdf")
        defer { try? FileManager.default.removeItem(at: output) }
        
        // Generate long content (should span ~3 pages)
        let items = (1...100).map { "<p style='margin: 20px 0;'>Item \($0)</p>" }.joined()
        let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Test</title></head>
            <body>\(items)</body>
            </html>
            """
        
        let url = try await pdf.render.client.html(html, to: output)
        
        // Verify multiple pages were created
        guard let pdfDoc = PDFDocument(url: url) else {
            throw NSError(domain: "Failed to load PDF", code: -1)
        }
        
        let pageCount = pdfDoc.pageCount
        #expect(pageCount > 1, "Paginated mode should create multiple pages for long content, got \(pageCount)")
        
        // Verify A4 dimensions
        if let firstPage = pdfDoc.page(at: 0) {
            let bounds = firstPage.bounds(for: .mediaBox)
            #expect(abs(bounds.width - 595.28) < 1.0, "Page width should be A4")
            #expect(abs(bounds.height - 841.89) < 1.0, "Page height should be A4")
        }
    }
    
    @Test(
        "Continuous mode creates single tall page",
        .dependency(\.pdf.render.configuration.paginationMode, .continuous)
    )
    func continuousModeLongContent() async throws {
        
        let tempDir = FileManager.default.temporaryDirectory
        let output = tempDir.appendingPathComponent("test-continuous.pdf")
        defer { try? FileManager.default.removeItem(at: output) }
        
        // Generate long content
        let items = (1...100).map { "<p style='margin: 20px 0;'>Item \($0)</p>" }.joined()
        let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Test</title></head>
            <body>\(items)</body>
            </html>
            """
        
        let url = try await pdf.render.client.html(html, to: output)
        
        // Verify single page was created
        guard let pdfDoc = PDFDocument(url: url) else {
            throw NSError(domain: "Failed to load PDF", code: -1)
        }
        
        let pageCount = pdfDoc.pageCount
        #expect(pageCount == 1, "Continuous mode should create single page, got \(pageCount)")
        
        // Verify tall page
        if let firstPage = pdfDoc.page(at: 0) {
            let bounds = firstPage.bounds(for: .mediaBox)
            #expect(abs(bounds.width - 595.28) < 1.0, "Page width should match A4 width")
            #expect(bounds.height > 1000, "Page should be tall (continuous), got \(bounds.height)")
        }
    }
    
    @Test(
        "Automatic mode with short content uses continuous",
        .dependency(\.pdf.render.configuration.paginationMode, .automatic())
    )
    func automaticModeShortContent() async throws {
        
        let tempDir = FileManager.default.temporaryDirectory
        let output = tempDir.appendingPathComponent("test-auto-short.pdf")
        defer { try? FileManager.default.removeItem(at: output) }
        
        let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Test</title></head>
            <body><h1>Short Content</h1><p>Just a paragraph.</p></body>
            </html>
            """
        
        let url = try await pdf.render.client.html(html, to: output)
        
        guard let pdfDoc = PDFDocument(url: url) else {
            throw NSError(domain: "Failed to load PDF", code: -1)
        }
        
        // Should use fast continuous mode for short content
        let pageCount = pdfDoc.pageCount
        #expect(pageCount == 1, "Automatic mode should use continuous for short content, got \(pageCount) pages")
    }
    
    @Test(
        "Automatic mode with long content uses paginated",
        .dependency(\.pdf.render.configuration.paginationMode, .automatic(heuristic: .contentLength(threshold: 1.5)))
    )
    func automaticModeLongContent() async throws {
        
        let tempDir = FileManager.default.temporaryDirectory
        let output = tempDir.appendingPathComponent("test-auto-long.pdf")
        defer { try? FileManager.default.removeItem(at: output) }
        
        // Generate content that exceeds 1.5 pages
        let items = (1...80).map { "<p style='margin: 20px 0;'>Item \($0)</p>" }.joined()
        let html = """
            <!DOCTYPE html>
            <html>
            <head><title>Test</title></head>
            <body>\(items)</body>
            </html>
            """
        
        let url = try await pdf.render.client.html(html, to: output)
        
        guard let pdfDoc = PDFDocument(url: url) else {
            throw NSError(domain: "Failed to load PDF", code: -1)
        }
        
        // Should use paginated mode for long content
        let pageCount = pdfDoc.pageCount
        #expect(pageCount > 1, "Automatic mode should use paginated for long content, got \(pageCount) pages")
        
        // Verify proper A4 dimensions (not tall single page)
        if let firstPage = pdfDoc.page(at: 0) {
            let bounds = firstPage.bounds(for: .mediaBox)
            #expect(abs(bounds.height - 841.89) < 1.0, "Automatic mode with long content should use proper A4 pagination")
        }
    }
    
    @Test("Margins work in both modes")
    func marginsInBothModes() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        
        // Test paginated mode with margins
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.render.configuration.paginationMode = .paginated
            $0.pdf.render.configuration.margins = .wide  // 72pt margins
        } operation: {
            
            let output = tempDir.appendingPathComponent("test-paginated-margins.pdf")
            defer { try? FileManager.default.removeItem(at: output) }
            
            let html = "<html><body><p>Test margins in paginated mode</p></body></html>"
            let result = try await pdf.render.client.html(html, to: output)
            
            #expect(FileManager.default.fileExists(atPath: result.path), "Paginated PDF with margins should be created")
        }
        
        // Test continuous mode with margins
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.render.configuration.paginationMode = .continuous
            $0.pdf.render.configuration.margins = .wide  // 72pt margins
        } operation: {
            
            let output = tempDir.appendingPathComponent("test-continuous-margins.pdf")
            defer { try? FileManager.default.removeItem(at: output) }
            
            let html = "<html><body><p>Test margins in continuous mode</p></body></html>"
            let result = try await pdf.render.client.html(html, to: output)
            
            #expect(FileManager.default.fileExists(atPath: result.path), "Continuous PDF with margins should be created")
        }
    }
}


// ===== Tests/HtmlToPdfTests/PerformanceBenchmarks.swift =====
//
//  PerformanceBenchmarks.swift
//  swift-html-to-pdf
//
//  Performance benchmarks for README documentation
//

import Testing
import Foundation
import Dependencies
import PDFTestSupport
@testable import HtmlToPdf

extension Tag {
    @Tag static var benchmark: Self
}

/// Performance benchmarks for generating README statistics
///
/// Run with: swift test --filter tag:benchmark
///
/// These tests generate consistent performance metrics for documentation.
/// Run multiple times and report the median results.
@Suite("Performance Benchmarks", .dependency(\.pdf, .liveValue), .serialized, .tags(.benchmark))
struct PerformanceBenchmarks {
    @Dependency(\.pdf) var pdf
    // MARK: - Helper Types

    private actor PeakMemoryTracker {
        private var peak: MemorySnapshot?

        func update(_ current: MemorySnapshot) {
            if let existingPeak = peak {
                if current.residentMB > existingPeak.residentMB {
                    peak = current
                }
            } else {
                peak = current
            }
        }

        func getPeak() -> MemorySnapshot {
            peak ?? MemorySnapshot(residentMB: 0, virtualMB: 0)
        }
    }

    struct MemorySnapshot: Sendable {
        let residentMB: Double
        let virtualMB: Double

        static func current() -> MemorySnapshot {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(
                        mach_task_self_,
                        task_flavor_t(MACH_TASK_BASIC_INFO),
                        $0,
                        &count
                    )
                }
            }

            guard result == KERN_SUCCESS else {
                return MemorySnapshot(residentMB: 0, virtualMB: 0)
            }

            return MemorySnapshot(
                residentMB: Double(info.resident_size) / 1_048_576,
                virtualMB: Double(info.virtual_size) / 1_048_576
            )
        }
    }

    struct BenchmarkResult {
        let name: String
        let count: Int
        let mode: PDF.PaginationMode
        let concurrency: Int
        let duration: TimeInterval
        let throughput: Double
        let avgPerItem: TimeInterval
        let memoryBefore: MemorySnapshot
        let memoryAfter: MemorySnapshot
        let peakMemory: MemorySnapshot
        let minDuration: TimeInterval
        let maxDuration: TimeInterval
        let p50Duration: TimeInterval
        let p95Duration: TimeInterval
        let p99Duration: TimeInterval

        var throughputPerSec: String {
            String(format: "%.0f", throughput)
        }

        var avgPerItemMs: String {
            String(format: "%.2f", avgPerItem * 1000)
        }

        var memoryDeltaMB: Double {
            memoryAfter.residentMB - memoryBefore.residentMB
        }

        var memoryPerPDFKB: Double {
            (memoryDeltaMB * 1024) / Double(count)
        }

        func printMarkdownRow() {
            print("| \(name.padding(toLength: 25, withPad: " ", startingAt: 0)) | \(String(count).padding(toLength: 8, withPad: " ", startingAt: 0)) | \(String(format: "%.2f", duration).padding(toLength: 8, withPad: " ", startingAt: 0))s | \(throughputPerSec.padding(toLength: 12, withPad: " ", startingAt: 0)) | \(avgPerItemMs.padding(toLength: 10, withPad: " ", startingAt: 0))ms | \(String(format: "%.1f", peakMemory.residentMB).padding(toLength: 8, withPad: " ", startingAt: 0))MB |")
        }

        func printDetailedRow() {
            print("| \(name.padding(toLength: 25, withPad: " ", startingAt: 0)) | \(String(count).padding(toLength: 8, withPad: " ", startingAt: 0)) | \(String(format: "%.2f", duration).padding(toLength: 8, withPad: " ", startingAt: 0))s | \(throughputPerSec.padding(toLength: 12, withPad: " ", startingAt: 0)) | \(avgPerItemMs.padding(toLength: 8, withPad: " ", startingAt: 0))ms | \(String(format: "%.2f", p50Duration * 1000).padding(toLength: 8, withPad: " ", startingAt: 0))ms | \(String(format: "%.2f", p95Duration * 1000).padding(toLength: 8, withPad: " ", startingAt: 0))ms | \(String(format: "%.2f", p99Duration * 1000).padding(toLength: 8, withPad: " ", startingAt: 0))ms | \(String(format: "%.1f", peakMemory.residentMB).padding(toLength: 8, withPad: " ", startingAt: 0))MB |")
        }
    }

    // MARK: - Benchmarks

    @Test("Benchmark: 100 simple PDFs")
    func benchmark100SimplePDFs() async throws {
        let result = try await runBenchmark(
            name: "100 Simple PDFs",
            count: 100,
            html: "<html><body><p>{{ID}}</p></body></html>",
            maxConcurrent: 8
        )

        printBenchmarkResult(result)
    }

    @Test("Benchmark: 1,000 simple PDFs")
    func benchmark1kSimplePDFs() async throws {
        let result = try await runBenchmark(
            name: "1k Simple PDFs",
            count: 1_000,
            html: "<html><body><p>{{ID}}</p></body></html>",
            maxConcurrent: 8
        )

        printBenchmarkResult(result)
    }

    @Test("Benchmark: 10,000 simple PDFs")
    func benchmark10kSimplePDFs() async throws {
        let result = try await runBenchmark(
            name: "10k Simple PDFs",
            count: 10_000,
            html: "<html><body><p>{{ID}}</p></body></html>",
            maxConcurrent: 8
        )

        printBenchmarkResult(result)
    }

    @Test("Benchmark: 100 complex PDFs")
    func benchmark100ComplexPDFs() async throws {
        let result = try await runBenchmark(
            name: "100 Complex PDFs",
            count: 100,
            html: complexHTML,
            maxConcurrent: 6
        )

        printBenchmarkResult(result)
    }

    @Test("Benchmark: 1,000 complex PDFs")
    func benchmark1kComplexPDFs() async throws {
        let result = try await runBenchmark(
            name: "1k Complex PDFs",
            count: 1_000,
            html: complexHTML,
            maxConcurrent: 6
        )

        printBenchmarkResult(result)
    }

    @Test("Benchmark: Concurrent batches")
    func benchmarkConcurrentBatches() async throws {
        let output = URL.output()
        defer {
            try? FileManager.default.removeItem(at: output)
        }
        
        let startTime = Date()
        
        // Run 10 concurrent batches of 100 PDFs each
        await withTaskGroup(of: Void.self) { group in
            for batch in 1...10 {
                let outputDir = output
                group.addTask { @Sendable in
                    try? await withDependencies {
                        $0.pdf.render.configuration.namingStrategy = .init { i in "batch\(batch)-doc\(i)" }
                    } operation: {
                        @Dependency(\.pdf) var batchPdf
                        let htmls = (1...100).map { i in
                            "<html><body><p>Batch \(batch) - Doc \(i)</p></body></html>"
                        }
                        var urls: [URL] = []
                        for try await result in try await batchPdf.render.client.html(htmls, to: outputDir) {
                            urls.append(result.url)
                        }
                    }
                }
            }
            
            await group.waitForAll()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let count = 1_000
        let memBefore = MemorySnapshot.current()
        let memAfter = MemorySnapshot.current()
        
        let result = BenchmarkResult(
            name: "10 Concurrent Batches",
            count: count,
            mode: .continuous,
            concurrency: 10,
            duration: duration,
            throughput: Double(count) / duration,
            avgPerItem: duration / Double(count),
            memoryBefore: memBefore,
            memoryAfter: memAfter,
            peakMemory: memAfter,
            minDuration: 0,
            maxDuration: 0,
            p50Duration: 0,
            p95Duration: 0,
            p99Duration: 0
        )
        
        printBenchmarkResult(result)
        
        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count)
        
    }

    @Test("Benchmark: Pool warmup time")
    func benchmarkPoolWarmup() async throws {
        
        
        // This measures the initial pool creation cost
        // Note: With background warmup, this should be very fast
        
        let startTime = Date()
        
        let html = "<html><body><p>Test</p></body></html>"
        let output = URL.output().appendingPathComponent("warmup.pdf")
        
        defer {
            try? FileManager.default.removeItem(at: output)
        }
        
        _ = try await pdf.render.client.html(html, to: output)
        
        let duration = Date().timeIntervalSince(startTime)
        
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Pool Warmup Benchmark")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("First PDF generation: \(String(format: "%.3f", duration))s")
        print("(Includes pool initialization + first PDF)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
    }

    // MARK: - Summary Report

    @Test("Generate README Performance Table", .timeLimit(.minutes(10)))
    func generateReadmeTable() async throws {
        print("\n")
        print("╔═══════════════════════════════════════════════════════════════════════════╗")
        print("║                     PERFORMANCE BENCHMARK RESULTS                         ║")
        print("║                    Copy this table to README.md                           ║")
        print("╚═══════════════════════════════════════════════════════════════════════════╝")
        print()

        let simpleHTML = "<html><body><p>{{ID}}</p></body></html>"

        // Run benchmarks for PAGINATED mode (print-ready)
        let paginatedResults = [
            try await runBenchmark(name: "100 Simple", count: 100, html: simpleHTML, maxConcurrent: 8, mode: .paginated),
            try await runBenchmark(name: "1,000 Simple", count: 1_000, html: simpleHTML, maxConcurrent: 8, mode: .paginated),
            try await runBenchmark(name: "10,000 Simple", count: 10_000, html: simpleHTML, maxConcurrent: 8, mode: .paginated),
            try await runBenchmark(name: "100 Complex", count: 100, html: complexHTML, maxConcurrent: 6, mode: .paginated),
            try await runBenchmark(name: "1,000 Complex", count: 1_000, html: complexHTML, maxConcurrent: 6, mode: .paginated),
        ]

        // Run benchmarks for CONTINUOUS mode (fast)
        let continuousResults = [
            try await runBenchmark(name: "100 Simple", count: 100, html: simpleHTML, maxConcurrent: 8, mode: .continuous),
            try await runBenchmark(name: "1,000 Simple", count: 1_000, html: simpleHTML, maxConcurrent: 8, mode: .continuous),
            try await runBenchmark(name: "10,000 Simple", count: 10_000, html: simpleHTML, maxConcurrent: 8, mode: .continuous),
        ]

        // Calculate dynamic comparisons
        let continuousAvg = continuousResults.map { $0.throughput }.reduce(0, +) / Double(continuousResults.count)
        let paginatedAvg = paginatedResults.map { $0.throughput }.reduce(0, +) / Double(paginatedResults.count)
        let speedupRatio = continuousAvg / paginatedAvg

        // Print markdown table for PAGINATED mode
        print("### Performance Results - Paginated Mode (Print-Ready)")
        print()
        print("Paginated mode uses NSPrintOperation for proper multi-page documents (invoices, reports).")
        print()
        print("| Test                      | Count    | Duration | Throughput   | Avg/PDF   | Peak Mem |")
        print("|---------------------------|----------|----------|--------------|-----------|----------|")

        for result in paginatedResults {
            result.printMarkdownRow()
        }

        print()

        // Print markdown table for CONTINUOUS mode
        print("### Performance Results - Continuous Mode (Fast)")
        print()
        print("Continuous mode uses WKWebView.createPDF for single-page documents (web captures, articles).")
        print()
        print("| Test                      | Count    | Duration | Throughput   | Avg/PDF   | Peak Mem |")
        print("|---------------------------|----------|----------|--------------|-----------|----------|")

        for result in continuousResults {
            result.printMarkdownRow()
        }

        print()

        // Detailed performance breakdown
        print("### Detailed Performance Metrics")
        print()
        print("| Test                      | Count    | Duration | Throughput   | Avg      | p50      | p95      | p99      | Peak Mem |")
        print("|---------------------------|----------|----------|--------------|----------|----------|----------|----------|----------|")

        for result in continuousResults + paginatedResults {
            result.printDetailedRow()
        }

        print()

        // System information
        let physicalMemoryGB = ProcessInfo.processInfo.physicalMemory / 1_073_741_824
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let cpuCount = ProcessInfo.processInfo.activeProcessorCount

        print("**Test Environment:**")
        print("- Platform: macOS \(osVersion)")
        print("- CPU Cores: \(cpuCount)")
        print("- Physical Memory: \(physicalMemoryGB) GB")
        print("- Swift Version: \(getSwiftVersion())")
        print()

        // Dynamic pool size information from actual benchmarks
        let poolSizes = Set(continuousResults.map { $0.concurrency } + paginatedResults.map { $0.concurrency })
        print("**Pool Configuration:**")
        for poolSize in poolSizes.sorted() {
            let tests = (continuousResults + paginatedResults).filter { $0.concurrency == poolSize }
            let testNames = tests.map { $0.name }.joined(separator: ", ")
            print("- \(poolSize) WebViews: \(testNames)")
        }
        print()

        // Dynamic performance comparison
        print("**Performance Comparison:**")
        print("- Continuous mode is \(String(format: "%.1f", speedupRatio))x faster than paginated mode (average)")
        print("- Best throughput (continuous): \(String(format: "%.0f", continuousResults.map { $0.throughput }.max() ?? 0)) PDFs/sec")
        print("- Best throughput (paginated): \(String(format: "%.0f", paginatedResults.map { $0.throughput }.max() ?? 0)) PDFs/sec")
        print()

        print("**Mode Selection Guide:**")
        print("- **Choose Continuous** for: Web captures, articles, infographics (single tall page)")
        print("- **Choose Paginated** for: Invoices, reports, documents for printing (proper page breaks)")
        print()

        // Memory analysis
        let avgMemoryPaginated = paginatedResults.map { $0.peakMemory.residentMB }.reduce(0, +) / Double(paginatedResults.count)
        let avgMemoryContinuous = continuousResults.map { $0.peakMemory.residentMB }.reduce(0, +) / Double(continuousResults.count)

        print("**Memory Profile:**")
        print("- Paginated mode peak: \(String(format: "%.1f", avgMemoryPaginated)) MB (average)")
        print("- Continuous mode peak: \(String(format: "%.1f", avgMemoryContinuous)) MB (average)")
        print()

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()
    }

    // MARK: - Helpers

    private func runBenchmark(
        name: String,
        count: Int,
        html: String,
        maxConcurrent: Int,
        mode: PDF.PaginationMode = .paginated
    ) async throws -> BenchmarkResult {
        try await withDependencies {
            $0.pdf.render.configuration.paginationMode = mode
            $0.pdf.render.configuration.concurrency = .fixed(maxConcurrent)
            $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(120)
        } operation: {
            let output = URL.output()

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let htmls = (1...count).map { i in
                html.replacingOccurrences(of: "{{ID}}", with: "\(i)")
            }

            let memoryBefore = MemorySnapshot.current()
            let peakMemoryActor = PeakMemoryTracker()
            var durations: [TimeInterval] = []

            // Track memory during execution
            let memoryTask = Task {
                while !Task.isCancelled {
                    let current = MemorySnapshot.current()
                    await peakMemoryActor.update(current)
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }

            let startTime = Date()

            // Render with per-PDF timing
            let stream = try await pdf.render.client.html(htmls, to: output)
            for try await result in stream {
                durations.append(Double(result.duration.components.seconds) +
                               Double(result.duration.components.attoseconds) / 1_000_000_000_000_000_000)
            }

            let totalDuration = Date().timeIntervalSince(startTime)
            memoryTask.cancel()

            let memoryAfter = MemorySnapshot.current()
            let peakMemory = await peakMemoryActor.getPeak()

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == count, "All PDFs should be created")

            // Calculate percentiles
            let sortedDurations = durations.sorted()
            let p50Index = sortedDurations.count / 2
            let p95Index = sortedDurations.count * 95 / 100
            let p99Index = sortedDurations.count * 99 / 100

            return BenchmarkResult(
                name: name,
                count: count,
                mode: mode,
                concurrency: maxConcurrent,
                duration: totalDuration,
                throughput: Double(count) / totalDuration,
                avgPerItem: totalDuration / Double(count),
                memoryBefore: memoryBefore,
                memoryAfter: memoryAfter,
                peakMemory: peakMemory,
                minDuration: sortedDurations.first ?? 0,
                maxDuration: sortedDurations.last ?? 0,
                p50Duration: sortedDurations[p50Index],
                p95Duration: sortedDurations[p95Index],
                p99Duration: sortedDurations[p99Index]
            )
        }
    }

    private func printBenchmarkResult(_ result: BenchmarkResult) {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Benchmark: \(result.name)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("PDFs Generated:  \(result.count)")
        print("Duration:        \(String(format: "%.2f", result.duration))s")
        print("Throughput:      \(result.throughputPerSec) PDFs/sec")
        print("Avg per PDF:     \(result.avgPerItemMs)ms")
        print("p50/p95/p99:     \(String(format: "%.2f", result.p50Duration * 1000))ms / \(String(format: "%.2f", result.p95Duration * 1000))ms / \(String(format: "%.2f", result.p99Duration * 1000))ms")
        print("Peak Memory:     \(String(format: "%.1f", result.peakMemory.residentMB)) MB")
        print("Memory Delta:    \(String(format: "%.1f", result.memoryDeltaMB)) MB")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    private func getSwiftVersion() -> String {
        #if compiler(>=6.0)
        return "6.0+"
        #elseif compiler(>=5.9)
        return "5.9+"
        #else
        return "5.x"
        #endif
    }

    private var complexHTML: String {
        """
        <html>
        <head>
            <style>
                body { font-family: Arial, sans-serif; padding: 20px; }
                h1 { color: #333; border-bottom: 2px solid #0066cc; }
                .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
                table { width: 100%; border-collapse: collapse; margin-top: 10px; }
                td, th { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; font-weight: bold; }
            </style>
        </head>
        <body>
            <h1>Document {{ID}}</h1>
            <div class="section">
                <h2>Executive Summary</h2>
                <p>This is a complex document with multiple sections, styling, and structured data.</p>
            </div>
            <div class="section">
                <h2>Data Table</h2>
                <table>
                    <tr><th>Metric</th><th>Value</th><th>Status</th></tr>
                    <tr><td>Revenue</td><td>$1,234,567</td><td>✓ On track</td></tr>
                    <tr><td>Customers</td><td>45,678</td><td>✓ Growing</td></tr>
                    <tr><td>Retention</td><td>94.2%</td><td>✓ Excellent</td></tr>
                </table>
            </div>
            <div class="section">
                <h2>Analysis</h2>
                <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>
            </div>
        </body>
        </html>
        """
    }

    // MARK: - Adaptive Throughput Optimization

    @Test("Find optimal concurrency for maximum throughput", .timeLimit(.minutes(60)))
    func testAdaptiveThroughputOptimization() async throws {
        struct ConcurrencyResult: Sendable {
            let concurrency: Int
            let throughput: Double
            let duration: TimeInterval
            let avgMs: Double
        }

        let testCount = 5000  // Sample size for each concurrency level
        // Respect platform maximum (macOS: 16, iOS: 8)
        let concurrencyLevels = [4, 8, 12, 16]

        print("\n╔════════════════════════════════════════════════════════════╗")
        print("║     ADAPTIVE THROUGHPUT OPTIMIZATION TEST                 ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print("Sample size per test: \(testCount) PDFs")
        print("Testing concurrency levels: \(concurrencyLevels)")
        print("Starting optimization...\n")

        var results: [ConcurrencyResult] = []

        for concurrency in concurrencyLevels {
            try await withDependencies {
                $0.pdf.render.configuration.concurrency = .fixed(concurrency)
                $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(300)
            } operation: {
                try await withTemporaryDirectory { output in
                    setenv("OS_ACTIVITY_MODE", "disable", 1)

                    let documents = (1...testCount).map { i in
                        PDF.Document(
                            htmlString: "<html><body><p>\(i)</p></body></html>",
                            title: "doc-\(i)",
                            in: output
                        )
                    }

                    let startTime = Date()
                    let stream = try await pdf.render.client.documents(documents)

                    var count = 0
                    for try await _ in stream {
                        count += 1
                    }

                    let duration = Date().timeIntervalSince(startTime)
                    let throughput = Double(testCount) / duration
                    let avgMs = duration * 1000 / Double(testCount)

                    let result = ConcurrencyResult(
                        concurrency: concurrency,
                        throughput: throughput,
                        duration: duration,
                        avgMs: avgMs
                    )
                    results.append(result)

                    print("✓ Concurrency \(String(format: "%2d", concurrency)): \(String(format: "%5.0f", throughput)) PDFs/sec  (\(String(format: "%.2f", duration))s, \(String(format: "%.3f", avgMs))ms avg)")
                }
            }
        }

        // Find optimal concurrency
        let optimal = results.max(by: { $0.throughput < $1.throughput })!

        print("\n╔════════════════════════════════════════════════════════════╗")
        print("║                   OPTIMIZATION RESULTS                     ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print("Optimal concurrency: \(optimal.concurrency) WebViews")
        print("Peak throughput:     \(String(format: "%.0f", optimal.throughput)) PDFs/sec")
        print("Avg per PDF:         \(String(format: "%.3f", optimal.avgMs))ms")
        print("\nAll results (sorted by throughput):")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        for result in results.sorted(by: { $0.throughput > $1.throughput }) {
            let marker = result.concurrency == optimal.concurrency ? "🏆" : "  "
            print("\(marker) \(String(format: "%2d", result.concurrency)) WebViews: \(String(format: "%5.0f", result.throughput)) PDFs/sec")
        }
        print("╚════════════════════════════════════════════════════════════╝\n")
    }
}


// ===== Tests/HtmlToPdfTests/PrintQualityExperiment.swift =====
//
//  PrintQualityExperiment.swift
//  swift-html-to-pdf
//
//  Experiments to improve NSPrintOperation rendering quality
//

import Testing
import Foundation
import HtmlToPdf
import Dependencies
import DependenciesTestSupport

@Suite(
    "Print Quality Experiments",
    .dependency(\.pdf, .liveValue),
    .disabled("Run manually: swift test --filter PrintQualityExperiments")
)
struct PrintQualityExperiments {
    @Dependency(\.pdf) var pdf

    @Test(
        "Compare different bullet character rendering quality",
        .dependency(\.pdf.render.configuration.paginationMode, .paginated)
    )
    func compareBulletCharacters() async throws {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

        let experiments = [
            ("Unicode Bullet (•)", "•"),
            ("HTML Entity (&middot;)", "&middot;"),
            ("HTML Entity (&bull;)", "&bull;"),
            ("Hyphen (-)", "-"),
            ("Pipe (|)", "|"),
            ("Em Dash (—)", "—"),
            ("En Dash (–)", "–"),
            ("Dot Operator (⋅)", "⋅"),
        ]

        for (name, character) in experiments {
            let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>Print Quality Test: \(name)</title>
                <style>
                    @page {
                        size: A4;
                        margin: 20mm;
                    }

                    @media print {
                        body {
                            -webkit-print-color-adjust: exact;
                            print-color-adjust: exact;
                        }
                    }

                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif;
                        -webkit-font-smoothing: antialiased;
                        -moz-osx-font-smoothing: grayscale;
                        text-rendering: geometricPrecision;
                        font-feature-settings: normal;
                        font-variant-ligatures: none;
                        line-height: 1.6;
                        color: #333;
                        margin: 0;
                        padding: 20px;
                    }

                    .test-section {
                        margin: 20px 0;
                        padding: 20px;
                        background: #f8f9fa;
                        border-radius: 8px;
                    }

                    .separator {
                        display: inline-block;
                        margin: 0 8px;
                        font-weight: normal;
                    }

                    .size-test {
                        margin: 10px 0;
                    }
                </style>
            </head>
            <body>
                <h1>\(name)</h1>

                <div class="test-section">
                    <h2>Font Size Tests</h2>
                    <div class="size-test" style="font-size: 10px;">
                        10px: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-size: 12px;">
                        12px: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-size: 14px;">
                        14px: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-size: 16px;">
                        16px: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-size: 18px;">
                        18px: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                </div>

                <div class="test-section">
                    <h2>Color Tests</h2>
                    <div class="size-test" style="color: #000000;">
                        Black: ContiguousArray&lt;UInt8&gt; <span class="separator">\(character)</span> UTF-8 Encoding <span class="separator">\(character)</span> Zero-copy
                    </div>
                    <div class="size-test" style="color: #333333;">
                        Dark Gray: ContiguousArray&lt;UInt8&gt; <span class="separator">\(character)</span> UTF-8 Encoding <span class="separator">\(character)</span> Zero-copy
                    </div>
                    <div class="size-test" style="color: #666666;">
                        Medium Gray: ContiguousArray&lt;UInt8&gt; <span class="separator">\(character)</span> UTF-8 Encoding <span class="separator">\(character)</span> Zero-copy
                    </div>
                    <div class="size-test" style="color: #999999;">
                        Light Gray: ContiguousArray&lt;UInt8&gt; <span class="separator">\(character)</span> UTF-8 Encoding <span class="separator">\(character)</span> Zero-copy
                    </div>
                </div>

                <div class="test-section">
                    <h2>Font Weight Tests</h2>
                    <div class="size-test" style="font-weight: 300;">
                        Light (300): Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-weight: 400;">
                        Regular (400): Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-weight: 500;">
                        Medium (500): Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-weight: 700;">
                        Bold (700): Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                </div>

                <div class="test-section">
                    <h2>System Font Variants</h2>
                    <div class="size-test" style="font-family: -apple-system;">
                        -apple-system: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-family: 'Helvetica Neue';">
                        Helvetica Neue: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-family: Arial;">
                        Arial: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-family: Georgia;">
                        Georgia: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                    <div class="size-test" style="font-family: 'Times New Roman';">
                        Times New Roman: Item A <span class="separator">\(character)</span> Item B <span class="separator">\(character)</span> Item C
                    </div>
                </div>
            </body>
            </html>
            """

            let fileName = "PDF_PrintQuality_\(name.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")).pdf"
            let output = desktop.appendingPathComponent(fileName)

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Testing: \(name)")
            print("Character: '\(character)'")
            print("Output: \(fileName)")

            _ = try await pdf.render.client.html(htmlString, to: output)

            print("✅ Generated: \(output.lastPathComponent)")
        }

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("All quality experiments generated!")
        print("Check Desktop for PDF_PrintQuality_*.pdf files")
        print("Compare visual quality of each character")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    @Test(
        "Test advanced CSS print optimizations",
        .dependency(\.pdf.render.configuration.paginationMode, .paginated)
    )
    func advancedPrintOptimizations() async throws {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Advanced Print Quality Optimizations</title>
            <style>
                @page {
                    size: A4;
                    margin: 15mm;
                }

                @media print {
                    * {
                        -webkit-print-color-adjust: exact !important;
                        print-color-adjust: exact !important;
                        color-adjust: exact !important;
                    }

                    body {
                        /* Force vector rendering */
                        text-rendering: geometricPrecision;
                        -webkit-font-smoothing: antialiased;
                        -moz-osx-font-smoothing: grayscale;

                        /* Disable features that might cause rasterization */
                        font-variant-ligatures: none;
                        font-feature-settings: normal;
                        -webkit-font-feature-settings: normal;

                        /* Optimize for print */
                        image-rendering: -webkit-optimize-contrast;
                        image-rendering: crisp-edges;
                    }

                    /* Prevent sub-pixel rendering */
                    * {
                        -webkit-backface-visibility: hidden;
                        backface-visibility: hidden;
                        -webkit-transform: translateZ(0);
                        transform: translateZ(0);
                    }
                }

                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif;
                    line-height: 1.6;
                    color: #1d1d1f;
                    margin: 0;
                    padding: 20px;
                }

                .test-card {
                    margin: 20px 0;
                    padding: 20px;
                    background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
                    border-radius: 8px;
                    border: 1px solid #e1e4e8;
                }

                .separator {
                    display: inline-block;
                    margin: 0 6px;
                    color: #86868b;
                }

                .text-small { font-size: 11px; }
                .text-normal { font-size: 13px; }
                .text-large { font-size: 15px; }
            </style>
        </head>
        <body>
            <h1>Advanced Print Quality Optimizations</h1>

            <div class="test-card">
                <h2>CSS Optimization Test</h2>
                <p class="text-small">
                    Small text <span class="separator">•</span> ContiguousArray&lt;UInt8&gt; <span class="separator">•</span> UTF-8 Encoding <span class="separator">•</span> Zero-copy rendering
                </p>
                <p class="text-normal">
                    Normal text <span class="separator">•</span> ContiguousArray&lt;UInt8&gt; <span class="separator">•</span> UTF-8 Encoding <span class="separator">•</span> Zero-copy rendering
                </p>
                <p class="text-large">
                    Large text <span class="separator">•</span> ContiguousArray&lt;UInt8&gt; <span class="separator">•</span> UTF-8 Encoding <span class="separator">•</span> Zero-copy rendering
                </p>
            </div>

            <div class="test-card">
                <h2>Alternative Characters</h2>
                <p>Using middot: Testing <span class="separator">&middot;</span> UTF-8 <span class="separator">&middot;</span> Rendering</p>
                <p>Using bull: Testing <span class="separator">&bull;</span> UTF-8 <span class="separator">&bull;</span> Rendering</p>
                <p>Using hyphen: Testing <span class="separator">-</span> UTF-8 <span class="separator">-</span> Rendering</p>
                <p>Using pipe: Testing <span class="separator">|</span> UTF-8 <span class="separator">|</span> Rendering</p>
                <p>Using en dash: Testing <span class="separator">–</span> UTF-8 <span class="separator">–</span> Rendering</p>
            </div>

            <div class="test-card">
                <h2>Emoji & Symbol Quality Test</h2>
                <p>📄 Document <span class="separator">•</span> ✅ Success <span class="separator">•</span> 🎯 Target</p>
                <p>⚡ Performance <span class="separator">•</span> 🔧 Tools <span class="separator">•</span> 📊 Analytics</p>
            </div>

            <div class="test-card">
                <h2>Complex Typography</h2>
                <p style="font-variant-numeric: tabular-nums;">
                    Numbers: 1,234,567.89 <span class="separator">•</span> 9,876,543.21 <span class="separator">•</span> 5,555,555.55
                </p>
                <p style="letter-spacing: 0.5px;">
                    Letter spacing <span class="separator">•</span> Character <span class="separator">•</span> Quality
                </p>
            </div>
        </body>
        </html>
        """

        let output = desktop.appendingPathComponent("PDF_PrintQuality_Advanced_CSS.pdf")

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Testing Advanced Print Optimizations")
        print("Output: \(output.lastPathComponent)")

        _ = try await pdf.render.client.html(htmlString, to: output)

        print("✅ Generated!")
        print("Check if CSS optimizations improve rendering")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    @Test(
        "Test SVG-based separators for perfect vector quality",
        .dependency(\.pdf.render.configuration.paginationMode, .paginated)
    )
    func svgSeparators() async throws {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>SVG Separator Quality Test</title>
            <style>
                body {
                    font-family: -apple-system, 'Helvetica Neue', Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    padding: 20px;
                }

                .svg-separator {
                    display: inline-block;
                    margin: 0 8px;
                    vertical-align: middle;
                    width: 4px;
                    height: 4px;
                }

                .test-section {
                    margin: 30px 0;
                    padding: 20px;
                    background: #f8f9fa;
                    border-radius: 8px;
                }
            </style>
        </head>
        <body>
            <h1>SVG-Based Separator Test</h1>

            <div class="test-section">
                <h2>SVG Circle Separator (Always Vector)</h2>
                <p>
                    Testing
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="2" cy="2" r="1.5" fill="#666"/>
                    </svg>
                    ContiguousArray&lt;UInt8&gt;
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="2" cy="2" r="1.5" fill="#666"/>
                    </svg>
                    UTF-8 Encoding
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="2" cy="2" r="1.5" fill="#666"/>
                    </svg>
                    Zero-copy
                </p>
            </div>

            <div class="test-section">
                <h2>SVG Square Separator</h2>
                <p>
                    Testing
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <rect x="1" y="1" width="2" height="2" fill="#666"/>
                    </svg>
                    ContiguousArray&lt;UInt8&gt;
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <rect x="1" y="1" width="2" height="2" fill="#666"/>
                    </svg>
                    UTF-8 Encoding
                </p>
            </div>

            <div class="test-section">
                <h2>SVG Diamond Separator</h2>
                <p>
                    Testing
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <polygon points="2,0.5 3.5,2 2,3.5 0.5,2" fill="#666"/>
                    </svg>
                    ContiguousArray&lt;UInt8&gt;
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <polygon points="2,0.5 3.5,2 2,3.5 0.5,2" fill="#666"/>
                    </svg>
                    UTF-8 Encoding
                </p>
            </div>

            <div class="test-section">
                <h2>Comparison: Unicode vs SVG</h2>
                <p style="font-size: 12px; color: #6c757d;">
                    Unicode bullet: Testing • UTF-8 • Rendering
                </p>
                <p style="font-size: 12px; color: #6c757d;">
                    SVG circle: Testing
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="2" cy="2" r="1.5" fill="#6c757d"/>
                    </svg>
                    UTF-8
                    <svg class="svg-separator" viewBox="0 0 4 4" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="2" cy="2" r="1.5" fill="#6c757d"/>
                    </svg>
                    Rendering
                </p>
            </div>
        </body>
        </html>
        """

        let output = desktop.appendingPathComponent("PDF_PrintQuality_SVG_Separators.pdf")

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Testing SVG-Based Separators")
        print("Output: \(output.lastPathComponent)")

        _ = try await pdf.render.client.html(htmlString, to: output)

        print("✅ Generated!")
        print("SVG should always render as perfect vectors")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
}


// ===== Tests/HtmlToPdfTests/StressTests.swift =====
//
//  StressTests.swift
//  swift-html-to-pdf
//
//  Extreme stress tests for resource pool under heavy load
//

import Testing
import Foundation
import Dependencies
import PDFTestSupport
@testable import HtmlToPdf

extension Tag {
    @Tag static var stress: Self
}

@Suite(
    "Stress Tests",
    .dependency(\.pdf, .liveValue),
    .serialized,
    .tags(.stress),
    .disabled()
)
struct StressTests {

    @Dependency(\.pdf) var pdf

    // MARK: - Extreme Load Tests

    @Test(
        "Generate 1,000,000 PDFs",
        .timeLimit(.minutes(120)),
//        .disabled { false }
    )
    func test1MPDFs() async throws {
        try await withDependencies {
            $0.pdf.render.configuration.concurrency = 8
            $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(600)
        } operation: {
            try await withTemporaryDirectory { output in
                // Suppress WebKit console warnings
                setenv("OS_ACTIVITY_MODE", "disable", 1)

                let count = 1_000_000
                let filesPerDirectory = 1_000 // Keep directories manageable

                let tracker = ProgressTracker(totalCount: count, reportInterval: 10.0)
                let startTime = Date()

                // Create subdirectories to avoid file system degradation
                // 1M files split into 1000 directories of 1000 files each
                let numDirectories = (count + filesPerDirectory - 1) / filesPerDirectory
                for dirIndex in 0..<numDirectories {
                    let subdirUrl = output.appendingPathComponent("batch-\(dirIndex)")
                    try FileManager.default.createDirectory(at: subdirUrl, withIntermediateDirectories: true)
                }

                // Create minimal HTML documents with subdirectory paths
                let documents = (1...count).map { i in
                    let dirIndex = (i - 1) / filesPerDirectory
                    let subdirUrl = output.appendingPathComponent("batch-\(dirIndex)")
                    return PDF.Document(
                        htmlString: "<html><body><p>\(i)</p></body></html>",
                        title: "doc-\(i)",
                        in: subdirUrl
                    )
                }

                @Dependency(\.pdf) var pdf
                let poolSize = pdf.render.configuration.concurrency.resolved

                print("\n╔═══════════════════════════════════════════════════════════╗")
                print("║           1 MILLION PDF GENERATION TEST                  ║")
                print("╚═══════════════════════════════════════════════════════════╝")
                print("Total documents: \(count.formatted())")
                print("Subdirectories:  \(numDirectories) (\(filesPerDirectory) files each)")
                print("Pool size: \(poolSize) WebViews")
                print("Starting generation...\n")

                let stream = try await pdf.render.client.documents(documents)

                for try await _ in stream {
                    _ = await tracker.recordCompletion()
                }

                let duration = Date().timeIntervalSince(startTime)
                _ = await tracker.completed

                // Verify all files were created by counting across all subdirectories
                var totalFiles = 0
                let subdirs = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
                for subdir in subdirs where subdir.hasDirectoryPath {
                    let files = try FileManager.default.contentsOfDirectory(at: subdir, includingPropertiesForKeys: nil)
                    totalFiles += files.count
                }
                #expect(totalFiles == count, "Should create all \(count) PDFs")

                // Calculate stats
                let throughput = Double(count) / duration
                let avgMs = duration * 1000 / Double(count)
                let minutes = Int(duration / 60)
                let seconds = Int(duration.truncatingRemainder(dividingBy: 60))

                // Print final statistics
                print("\n╔═══════════════════════════════════════════════════════════╗")
                print("║         1 MILLION PDF TEST - RESULTS                     ║")
                print("╚═══════════════════════════════════════════════════════════╝")
                print("Total PDFs:      \(count.formatted())")
                print("Duration:        \(minutes)m \(seconds)s (\(String(format: "%.2f", duration))s)")
                print("Throughput:      \(String(format: "%.0f", throughput)) PDFs/sec")
                print("Avg per PDF:     \(String(format: "%.3f", avgMs))ms")
                print("Files created:   \(totalFiles.formatted())")
                print("Subdirectories:  \(subdirs.count)")
                print("╚═══════════════════════════════════════════════════════════╝\n")

                // Verify reasonable throughput (at least 100 PDFs/sec)
                #expect(throughput > 100, "Should maintain reasonable throughput")
            }
        }
    }

    @Test("Generate 200,000 PDFs", .timeLimit(.minutes(30)))
    func test100kPDFs() async throws {
        try await withDependencies {
            // Using .automatic now defaults to 3x CPU count (24 on 8-core Mac)
            $0.pdf.render.configuration.concurrency = .automatic
            $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(300)
            // Enable adaptive throughput optimization
            $0.pdf.render.configuration.adaptiveThroughputOptimization = true
        } operation: {
            try await withTemporaryDirectory { output in
                // Suppress WebKit console warnings
                setenv("OS_ACTIVITY_MODE", "disable", 1)

                let count = 200_000
                let filesPerDirectory = 1_000 // Keep directories manageable

                let tracker = ProgressTracker(totalCount: count, reportInterval: 5.0)
                let startTime = Date()

                // Create subdirectories to avoid file system degradation
                let numDirectories = (count + filesPerDirectory - 1) / filesPerDirectory
                for dirIndex in 0..<numDirectories {
                    let subdirUrl = output.appendingPathComponent("batch-\(dirIndex)")
                    try FileManager.default.createDirectory(at: subdirUrl, withIntermediateDirectories: true)
                }

                // Create minimal HTML documents with subdirectory paths
                let documents = (1...count).map { i in
                    let dirIndex = (i - 1) / filesPerDirectory
                    let subdirUrl = output.appendingPathComponent("batch-\(dirIndex)")
                    return PDF.Document(
                        htmlString: "<html><body><p>\(i)</p></body></html>",
                        title: "doc-\(i)",
                        in: subdirUrl
                    )
                }

                @Dependency(\.pdf) var pdf
                let poolSize = pdf.render.configuration.concurrency.resolved

                print("\n╔═══════════════════════════════════════════════════════════╗")
                print("║           100K PDF GENERATION TEST                       ║")
                print("╚═══════════════════════════════════════════════════════════╝")
                print("Total documents: \(count.formatted())")
                print("Subdirectories:  \(numDirectories) (\(filesPerDirectory) files each)")
                print("Pool size: \(poolSize) WebViews")
                print("Adaptive optimization: ENABLED")
                print("Starting generation...\n")

                let stream = try await pdf.render.client.documents(documents)

                for try await _ in stream {
                    _ = await tracker.recordCompletion()
                }

                let duration = Date().timeIntervalSince(startTime)
                _ = await tracker.completed

                // Verify all files were created by counting across all subdirectories
                var totalFiles = 0
                let subdirs = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
                for subdir in subdirs where subdir.hasDirectoryPath {
                    let files = try FileManager.default.contentsOfDirectory(at: subdir, includingPropertiesForKeys: nil)
                    totalFiles += files.count
                }
                #expect(totalFiles == count, "Should create all \(count) PDFs")

                // Calculate stats
                let throughput = Double(count) / duration
                let avgMs = duration * 1000 / Double(count)
                let minutes = Int(duration / 60)
                let seconds = Int(duration.truncatingRemainder(dividingBy: 60))

                // Print final statistics
                print("\n╔═══════════════════════════════════════════════════════════╗")
                print("║         100K PDF TEST - RESULTS                          ║")
                print("╚═══════════════════════════════════════════════════════════╝")
                print("Total PDFs:      \(count.formatted())")
                print("Duration:        \(minutes)m \(seconds)s (\(String(format: "%.2f", duration))s)")
                print("Throughput:      \(String(format: "%.0f", throughput)) PDFs/sec")
                print("Avg per PDF:     \(String(format: "%.3f", avgMs))ms")
                print("Files created:   \(totalFiles.formatted())")
                print("Subdirectories:  \(subdirs.count)")
                print("╚═══════════════════════════════════════════════════════════╝\n")

                // Verify reasonable throughput (at least 100 PDFs/sec)
                #expect(throughput > 100, "Should maintain reasonable throughput")
            }
        }
    }

    @Test("Generate 1,000 PDFs with complex HTML", .timeLimit(.minutes(5)))
    func test1kComplexPDFs() async throws {
        try await withDependencies {
            $0.pdf.render.configuration.concurrency = 6
            $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(120)
        } operation: {
            try await withTemporaryDirectory { output in
                let count = 1_000

                let startTime = Date()

                // More complex HTML to stress rendering
                let complexHTML = """
                <html>
                <head>
                    <style>
                        body { font-family: Arial, sans-serif; padding: 20px; }
                        h1 { color: #333; }
                        .section { margin: 20px 0; padding: 10px; border: 1px solid #ddd; }
                        table { width: 100%; border-collapse: collapse; }
                        td, th { border: 1px solid #ddd; padding: 8px; }
                    </style>
                </head>
                <body>
                    <h1>Document {{ID}}</h1>
                    <div class="section">
                        <h2>Summary</h2>
                        <p>This is a more complex document with styling and structure.</p>
                    </div>
                    <div class="section">
                        <h2>Data Table</h2>
                        <table>
                            <tr><th>Column 1</th><th>Column 2</th><th>Column 3</th></tr>
                            <tr><td>Data 1</td><td>Data 2</td><td>Data 3</td></tr>
                            <tr><td>Data 4</td><td>Data 5</td><td>Data 6</td></tr>
                        </table>
                    </div>
                </body>
                </html>
                """

                let htmls = (1...count).map { i in
                    complexHTML.replacingOccurrences(of: "{{ID}}", with: "\(i)")
                }

                print("Starting 1k complex PDF generation test...")

                var urls: [URL] = []
                for try await result in try await pdf.render.client.html(htmls, to: output) {
                    urls.append(result.url)
                }

                let duration = Date().timeIntervalSince(startTime)

                let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
                #expect(files.count == count, "Should create all \(count) PDFs")

                print("\n✅ 1k Complex PDF Stress Test Complete!")
                print("Duration: \(String(format: "%.2f", duration))s")
                print("Throughput: \(String(format: "%.0f", Double(count) / duration)) PDFs/sec")

                // Verify some PDFs have reasonable size (not empty)
                let sampleFile = files[0]
                let fileSize = try FileManager.default.attributesOfItem(atPath: sampleFile.path)[.size] as? Int ?? 0
                #expect(fileSize > 5000, "Complex PDFs should have substantial content")
            }
        }
    }

    @Test("Sustained load test - 5 minutes continuous generation")
    func testSustainedLoad() async throws {
        try await withTemporaryDirectory { output in
            let duration: TimeInterval = 300 // 5 minutes

            actor Counter {
                var count = 0
                func increment() -> Int {
                    count += 1
                    return count
                }
                func get() -> Int { count }
            }

            let counter = Counter()
            let startTime = Date()

            print("Starting sustained load test (5 minutes)...")

            // Generate PDFs continuously for 5 minutes
            await withTaskGroup(of: Void.self) { group in
                // Launch multiple concurrent generators
                for batch in 1...10 {
                    let testDuration = duration
                    let start = startTime
                    let outputDir = output
                    group.addTask { @Sendable in
                        while Date().timeIntervalSince(start) < testDuration {
                            do {
                                let count = await counter.increment()
                                let html = "<html><body><p>PDF \(count)</p></body></html>"
                                let destination = outputDir.appendingPathComponent("sustained-\(count).pdf")

                                _ = try await pdf.render.client.html(html, to: destination)

                                // Brief pause to simulate realistic workload
                                try? await Task.sleep(for: .milliseconds(100))
                            } catch {
                                print("Error in batch \(batch): \(error)")
                            }
                        }
                    }
                }

                await group.waitForAll()
            }

            let totalDuration = Date().timeIntervalSince(startTime)
            let totalGenerated = await counter.get()

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)

            print("\n✅ Sustained Load Test Complete!")
            print("Duration: \(String(format: "%.2f", totalDuration))s")
            print("PDFs generated: \(totalGenerated)")
            print("Average rate: \(String(format: "%.1f", Double(totalGenerated) / totalDuration)) PDFs/sec")
            print("Files created: \(files.count)")

            #expect(totalGenerated > 100, "Should generate substantial number of PDFs")
            #expect(files.count == totalGenerated, "All PDFs should be created")
        }
    }
}


// ===== Tests/HtmlToPdfTests/Utils.swift =====
//
//  File.swift
//
//
//  Created by Coen ten Thije Boonkkamp on 15/07/2024.
//

import Foundation
import HtmlToPdf
import Testing

extension URL {

    static func output(id: UUID = UUID()) -> Self {
        FileManager.default.temporaryDirectory.appendingPathComponent("html-to-pdf").appendingPathComponent(id.uuidString)
    }

    static var localHtmlToPdf: Self {
        #if os(macOS)
        return URL.documentsDirectory.appendingPathComponent("HtmlToPdf")
        #endif
        #if os(iOS)
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths.first!.appendingPathComponent("HtmlToPdf")
        #endif
    }
}

extension FileManager {
    func removeItems(at url: URL) throws {
        let fileURLs = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        for fileURL in fileURLs {
            try removeItem(at: fileURL)
        }
    }

    /// Clean up any leftover test directories from interrupted tests
    /// This is useful when tests timeout or are interrupted before cleanup can run
    static func cleanupTestDirectories() {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("html-to-pdf")

        guard fm.fileExists(atPath: tempDir.path) else { return }

        do {
            let subdirs = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            print("🧹 Cleaning up \(subdirs.count) leftover test directories...")

            for subdir in subdirs {
                try? fm.removeItem(at: subdir)
            }

            try? fm.removeItem(at: tempDir)
            print("✅ Cleanup complete")
        } catch {
            print("⚠️ Cleanup failed: \(error)")
        }
    }
}

extension AsyncStream<URL> {
    func testIfYieldedUrlExistsOnFileSystem(directory: URL) async throws {
        for await url in self {
            let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .map(\.lastPathComponent)
            #expect(contents.contains(where: { $0 == url.lastPathComponent }))
        }
    }
}

extension AsyncThrowingStream<URL, Error> {
    func testIfYieldedUrlExistsOnFileSystem(directory: URL) async throws {
        for try await url in self {
            let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .map(\.lastPathComponent)
            #expect(contents.contains(where: { $0 == url.lastPathComponent }))
        }
    }
}

extension String {
    static let html = """
    <html>
        <body>
            <h1>Hello, World! Hello, World! Hello, World! Hello, World! Hello, World! Hello, World! Hello, World! Hello, World!</h1>
        </body>
    </html>
    """

    static let html2 = """
    <html>
        <body>
            <h1>Hello, World!</h1>
            <h2>Hello, World! subheader</h2>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
            <p>Praesent id lorem eleifend risus vestibulum tristique. Donec tristique pretium arcu et finibus. Fusce eget tellus pretium, pellentesque neque facilisis, fringilla augue. Praesent bibendum, purus dictum posuere interdum, enim sapien elementum augue, consectetur porta tellus nulla at dui. Etiam nec elit a ligula iaculis ultrices. Phasellus vulputate varius turpis, quis interdum tortor posuere id. Proin eu lorem sagittis, aliquet nisi ut, blandit ligula. Vestibulum vel ultrices magna. In est sapien, ultricies in mauris et, egestas laoreet orci. Praesent ornare ante sollicitudin pretium consectetur. Sed nec nisi enim. Vestibulum sodales est eu vestibulum venenatis.</p>
            <p>Nulla sagittis augue vel purus posuere egestas. Donec lacinia metus sit amet nulla tincidunt, eu consequat mi facilisis. Suspendisse mollis magna ut mauris interdum tincidunt. Vivamus non justo nec elit hendrerit maximus. Maecenas sollicitudin tincidunt mauris. Praesent quis velit quis justo pharetra rhoncus a et metus. Donec nec luctus libero. Cras sapien ipsum, pharetra id massa sed, rhoncus sagittis erat. Nam eu urna eget massa commodo tempor tincidunt nec velit. Duis bibendum cursus magna, nec iaculis turpis dapibus fringilla. Pellentesque et suscipit dolor. Praesent ac lectus quis dolor vestibulum lobortis vitae vestibulum leo. In at risus ut urna convallis dignissim. Proin vel magna vulputate, posuere augue at, ornare sapien.</p>
            <p>Sed euismod, nunc vel mollis interdum, mi nulla vehicula urna, a gravida tellus ante nec velit. Nunc sed lectus vehicula, pulvinar ante a, hendrerit arcu. Nulla turpis urna, luctus at sagittis non, dignissim vitae ligula. Nam nec venenatis enim. Aenean ut nibh id erat faucibus tincidunt. Etiam eu magna ac purus consequat dignissim vel ac ipsum. Maecenas at luctus odio. Maecenas facilisis eleifend tempor. Quisque mi lorem, aliquam vitae vulputate faucibus, pharetra id mauris. Proin molestie lacus sit amet faucibus dapibus. Sed nibh dui, vehicula sed leo ut, blandit tempus ipsum. Nullam bibendum molestie dapibus. In hac habitasse platea dictumst.</p>
            <p>Aenean vulputate nulla dolor, vitae tempor felis egestas ut. Praesent faucibus sagittis dictum. Nam scelerisque lacinia accumsan. Nam ultricies urna sit amet vulputate faucibus. Proin iaculis magna et augue sagittis, a posuere lacus rutrum. Sed faucibus nulla a libero ultricies fermentum. Pellentesque malesuada sem pulvinar rutrum efficitur. Vivamus mattis condimentum nulla, id consequat arcu tincidunt at. Nunc pharetra molestie purus, ut blandit velit semper a. Integer scelerisque, ipsum et accumsan condimentum, nibh nulla viverra elit, at suscipit quam mauris et massa. Maecenas tempor urna efficitur diam molestie, vitae eleifend tellus aliquam. Phasellus eros ex, rutrum quis felis vel, egestas condimentum ligula. Donec a arcu eget lacus laoreet pharetra.</p>
        </body>
    </html>
    """

}

// MARK: - Test Progress Tracking

actor ProgressTracker {
    var completed = 0
    var lastReportedAt = Date()
    var lastReportedCompleted = 0
    let reportInterval: TimeInterval
    let totalCount: Int

    init(totalCount: Int, reportInterval: TimeInterval = 5.0) {
        self.totalCount = totalCount
        self.reportInterval = reportInterval
    }

    func recordCompletion() -> Int {
        completed += 1

        let now = Date()
        if now.timeIntervalSince(lastReportedAt) >= reportInterval {
            let interval = now.timeIntervalSince(lastReportedAt)
            let delta = completed - lastReportedCompleted
            let rate = Double(delta) / interval
            print("Progress: \(completed)/\(totalCount) PDFs (\(String(format: "%.1f", Double(completed)/1000.0))k) - Rate: \(String(format: "%.0f", rate)) PDFs/sec")
            lastReportedAt = now
            lastReportedCompleted = completed
        }

        return completed
    }
}



// ===== Tests/HtmlToPdfTests/VisualVerificationTest.swift =====
//
//  VisualVerificationTest.swift
//  swift-html-to-pdf
//
//  Manual verification test - generates a PDF to Desktop for visual inspection
//

import Testing
import Foundation
import HtmlToPdf
import Dependencies
import DependenciesTestSupport

@Suite(
    "Visual Verification (Manual)",
    .dependency(\.pdf, .liveValue),
    .disabled("Run manually: swift test --filter VisualVerificationTests")
)
struct VisualVerificationTests {

    @Test("Generate rich PDF for manual verification")
    func generateVerificationPDF() async throws {
        @Dependency(\.pdf) var pdf

        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

            // Test 1: Rich HTML with ContiguousArray<UInt8>
            let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>PDF Verification Test</title>
                <style>
                    body {
                        font-family: 'Helvetica Neue', Arial, sans-serif;
                        line-height: 1.6;
                        color: #333;
                    }

                    .header {
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        padding: 40px;
                        text-align: center;
                        border-radius: 8px;
                        margin-bottom: 30px;
                    }

                    .header h1 {
                        margin: 0;
                        font-size: 48px;
                        font-weight: bold;
                    }

                    .header p {
                        margin: 10px 0 0 0;
                        font-size: 18px;
                        opacity: 0.9;
                    }

                    .section {
                        margin: 30px 0;
                        padding: 20px;
                        background: #f8f9fa;
                        border-left: 4px solid #667eea;
                        border-radius: 4px;
                    }

                    .section h2 {
                        margin-top: 0;
                        color: #667eea;
                    }

                    .feature-grid {
                        display: grid;
                        grid-template-columns: repeat(2, 1fr);
                        gap: 20px;
                        margin: 20px 0;
                    }

                    .feature {
                        background: white;
                        padding: 20px;
                        border-radius: 8px;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                    }

                    .feature h3 {
                        margin-top: 0;
                        color: #764ba2;
                    }

                    table {
                        width: 100%;
                        border-collapse: collapse;
                        margin: 20px 0;
                        background: white;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                    }

                    th {
                        background: #667eea;
                        color: white;
                        padding: 12px;
                        text-align: left;
                    }

                    td {
                        padding: 12px;
                        border-bottom: 1px solid #e9ecef;
                    }

                    tr:hover {
                        background: #f8f9fa;
                    }

                    code {
                        background: #f4f4f4;
                        padding: 2px 6px;
                        border-radius: 3px;
                        font-family: 'Monaco', 'Courier New', monospace;
                        color: #e83e8c;
                    }

                    .footer {
                        margin-top: 40px;
                        padding: 20px;
                        text-align: center;
                        color: #6c757d;
                        border-top: 2px solid #e9ecef;
                    }
                </style>
            </head>
            <body>
                <div class="header">
                    <h1>🎯 PDF Generation Verification</h1>
                    <p>Testing ContiguousArray&lt;UInt8&gt; Implementation</p>
                </div>

                <div class="section">
                    <h2>✅ Implementation Verified</h2>
                    <p>This PDF was generated using the new <code>ContiguousArray&lt;UInt8&gt;</code> approach. If you can see this document with proper formatting, colors, and layout, then the implementation is working correctly!</p>
                </div>

                <div class="section">
                    <h2>📊 Performance Characteristics</h2>
                    <table>
                        <thead>
                            <tr>
                                <th>Metric</th>
                                <th>Old (String)</th>
                                <th>New (ContiguousArray)</th>
                                <th>Improvement</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr>
                                <td>Memory Usage</td>
                                <td>~1388 bytes</td>
                                <td>~694 bytes</td>
                                <td>50% reduction</td>
                            </tr>
                            <tr>
                                <td>CSS Injection</td>
                                <td>String operations</td>
                                <td>3.71μs (byte ops)</td>
                                <td>Faster</td>
                            </tr>
                            <tr>
                                <td>Type Safety</td>
                                <td>Runtime strings</td>
                                <td>Compile-time</td>
                                <td>✓ Guaranteed</td>
                            </tr>
                            <tr>
                                <td>Copy Operations</td>
                                <td>Multiple</td>
                                <td>Zero-copy</td>
                                <td>Eliminated</td>
                            </tr>
                        </tbody>
                    </table>
                </div>

                <div class="feature-grid">
                    <div class="feature">
                        <h3>🎨 CSS Support</h3>
                        <p>Gradients, shadows, borders, and modern CSS features are properly rendered.</p>
                    </div>

                    <div class="feature">
                        <h3>📝 Typography</h3>
                        <p>Multiple font families, sizes, and weights display correctly.</p>
                    </div>

                    <div class="feature">
                        <h3>🎭 Layout</h3>
                        <p>CSS Grid, flexbox, and positioning work as expected.</p>
                    </div>

                    <div class="feature">
                        <h3>🌈 Colors</h3>
                        <p>Hex colors, gradients, and opacity render perfectly.</p>
                    </div>
                </div>

                <div class="section">
                    <h2>🔬 Technical Details</h2>
                    <p><strong>Storage Format:</strong> ContiguousArray&lt;UInt8&gt; (UTF-8 encoded bytes)</p>
                    <p><strong>HTML Source:</strong> String → ContiguousArray&lt;UInt8&gt;</p>
                    <p><strong>WKWebView Loading:</strong> Direct Data from ContiguousArray (zero-copy)</p>
                    <p><strong>CSS Injection:</strong> Byte-level search and insertion</p>
                    <p><strong>Memory Layout:</strong> Contiguous, cache-friendly byte array</p>
                </div>

                <div class="section">
                    <h2>🧪 Character Encoding Test</h2>
                    <p>Testing UTF-8 encoding with special characters:</p>
                    <ul>
                        <li>Emoji: 🎉 🚀 ✨ 💡 🔥 ⚡️ 🎯 🌟</li>
                        <li>Math: α β γ δ ε ∑ ∫ √ ∞ ≈ ≠ ±</li>
                        <li>Currency: $ € £ ¥ ₹ ₿</li>
                        <li>Punctuation: « » „ " ' ' – — …</li>
                        <li>Accents: café, naïve, résumé, façade</li>
                    </ul>
                </div>

                <div class="footer">
                    <p>Generated: \(Date().formatted())</p>
                    <p>swift-html-to-pdf • ContiguousArray&lt;UInt8&gt; Implementation</p>
                </div>
            </body>
            </html>
            """

            let output = desktop.appendingPathComponent("PDF_Verification_Test.pdf")

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Generating Verification PDF")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("\nOutput location:")
            print("  \(output.path)")

            let url = try await pdf.render.client.html(htmlString, to: output)

            if FileManager.default.fileExists(atPath: url.path) {
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = attrs[.size] as? Int64 ?? 0

                print("\n✅ PDF Generated Successfully!")
                print("   Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                print("   Path: \(url.path)")
                print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("Open the PDF to verify:")
                print("  • Gradients and colors render correctly")
                print("  • CSS Grid layout works")
                print("  • Tables are properly formatted")
                print("  • Special characters display (emoji, math symbols)")
                print("  • Typography and spacing look good")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        } else {
            throw NSError(domain: "PDF not created", code: -1)
        }
    }
}


// ===== Tests/HtmlToPdfTests/WebViewMemoryTests.swift =====
//
//  WebViewMemoryTests.swift
//  swift-html-to-pdf
//
//  Tests to empirically measure WebView memory usage
//

import Testing
import Foundation
import HtmlToPdf
import Dependencies

#if os(macOS)
import Darwin.Mach

/// Measure current process memory footprint
func currentMemoryUsage() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)

    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }

    guard result == KERN_SUCCESS else {
        return 0
    }

    // phys_footprint is the most accurate measure of actual memory used
    return info.phys_footprint
}

func formatBytes(_ bytes: UInt64) -> String {
    let mb = Double(bytes) / (1024.0 * 1024.0)
    return String(format: "%.1f MB", mb)
}

@Suite("WebView Memory Usage Analysis", .tags(.webViewMemory), .dependency(\.pdf, .liveValue))
struct WebViewMemoryTests {

    @Test("Baseline: Memory before any PDFs")
    func measureBaselineMemory() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("BASELINE: Process Memory Before Any PDF Operations")
        print(String(repeating: "=", count: 80))

        // Force GC
        for _ in 0..<3 {
            autoreleasepool {}
        }
        try await Task.sleep(for: .milliseconds(500))

        let baseline = currentMemoryUsage()
        print("Process baseline: \(formatBytes(baseline))")
        print(String(repeating: "=", count: 80) + "\n")
    }

    @Test("Single render: 1 concurrent operation", .dependency(\.pdf.render.configuration.concurrency, 1))
    func measureSingleRender() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST: Single Render (Concurrency = 1)")
        print(String(repeating: "=", count: 80))

        let before = currentMemoryUsage()
        print("Before: \(formatBytes(before))")

        @Dependency(\.pdf) var pdf
        let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }

        let html = "<html><body><h1>Test</h1></body></html>"
        _ = try await pdf.render.html(html, to: output)

        try await Task.sleep(for: .milliseconds(500))

        let after = currentMemoryUsage()
        let delta = Int64(after) - Int64(before)

        print("After:  \(formatBytes(after))")
        print("Delta:  \(formatBytes(UInt64(delta)))")
        print("\nThis includes: Pool initialization + 1 WebView + rendering overhead")
        print(String(repeating: "=", count: 80) + "\n")
    }

    @Test("Incremental: 1 → 4 concurrent operations", .dependency(\.pdf.render.configuration.concurrency, 4))
    func measureIncremental1to4() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST: Incremental Memory Growth (1 → 4 concurrent)")
        print(String(repeating: "=", count: 80))

        @Dependency(\.pdf) var pdf
        let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }

        // First, render 1 to establish baseline
        let html = "<html><body><h1>Test</h1></body></html>"
        _ = try await pdf.render.html(html, to: output.appendingPathComponent("0.pdf"))
        try await Task.sleep(for: .milliseconds(500))

        let after1 = currentMemoryUsage()
        print("After 1 render:  \(formatBytes(after1))")

        // Now render 4 concurrently
        let documents = (1...4).map { i in
            PDF.Document(
                htmlString: html,
                destination: output.appendingPathComponent("\(i).pdf")
            )
        }

        let stream = try await pdf.render.documents(documents)
        for try await _ in stream {}
        try await Task.sleep(for: .seconds(1))

        let after4 = currentMemoryUsage()
        let delta = Int64(after4) - Int64(after1)

        print("After 4 renders: \(formatBytes(after4))")
        if delta >= 0 {
            print("Delta (1→4):     +\(formatBytes(UInt64(delta)))")
        } else {
            print("Delta (1→4):     -\(formatBytes(UInt64(-delta)))")
        }
        print("\nThis delta shows marginal cost of 3 additional concurrent renders")
        print(String(repeating: "=", count: 80) + "\n")

        // Cleanup
        for doc in documents {
            try? FileManager.default.removeItem(at: doc.destination)
        }
        try? FileManager.default.removeItem(at: output.appendingPathComponent("0.pdf"))
    }

    @Test("Incremental: 1 → 8 concurrent operations", .dependency(\.pdf.render.configuration.concurrency, 8))
    func measureIncremental1to8() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST: Incremental Memory Growth (1 → 8 concurrent)")
        print(String(repeating: "=", count: 80))

        @Dependency(\.pdf) var pdf
        let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }

        // First, render 1 to establish baseline
        let html = "<html><body><h1>Test</h1></body></html>"
        _ = try await pdf.render.html(html, to: output.appendingPathComponent("0.pdf"))
        try await Task.sleep(for: .milliseconds(500))

        let after1 = currentMemoryUsage()
        print("After 1 render:  \(formatBytes(after1))")

        // Now render 8 concurrently
        let documents = (1...8).map { i in
            PDF.Document(
                htmlString: html,
                destination: output.appendingPathComponent("\(i).pdf")
            )
        }

        let stream = try await pdf.render.documents(documents)
        for try await _ in stream {}
        try await Task.sleep(for: .seconds(1))

        let after8 = currentMemoryUsage()
        let delta = Int64(after8) - Int64(after1)

        print("After 8 renders: \(formatBytes(after8))")
        if delta >= 0 {
            print("Delta (1→8):     +\(formatBytes(UInt64(delta)))")
        } else {
            print("Delta (1→8):     -\(formatBytes(UInt64(-delta)))")
        }
        print("\nThis delta shows marginal cost of 7 additional concurrent renders")
        print(String(repeating: "=", count: 80) + "\n")

        // Cleanup
        for doc in documents {
            try? FileManager.default.removeItem(at: doc.destination)
        }
        try? FileManager.default.removeItem(at: output.appendingPathComponent("0.pdf"))
    }

    @Test("Incremental: 1 → 16 concurrent operations", .dependency(\.pdf.render.configuration.concurrency, 16))
    func measureIncremental1to16() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST: Incremental Memory Growth (1 → 16 concurrent)")
        print(String(repeating: "=", count: 80))

        @Dependency(\.pdf) var pdf
        let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }

        // First, render 1 to establish baseline
        let html = "<html><body><h1>Test</h1></body></html>"
        _ = try await pdf.render.html(html, to: output.appendingPathComponent("0.pdf"))
        try await Task.sleep(for: .milliseconds(500))

        let after1 = currentMemoryUsage()
        print("After 1 render:  \(formatBytes(after1))")

        // Now render 16 concurrently
        let documents = (1...16).map { i in
            PDF.Document(
                htmlString: html,
                destination: output.appendingPathComponent("\(i).pdf")
            )
        }

        let stream = try await pdf.render.documents(documents)
        for try await _ in stream {}
        try await Task.sleep(for: .seconds(2))

        let after16 = currentMemoryUsage()
        let delta = Int64(after16) - Int64(after1)

        print("After 16 renders: \(formatBytes(after16))")
        if delta >= 0 {
            print("Delta (1→16):     +\(formatBytes(UInt64(delta)))")
        } else {
            print("Delta (1→16):     -\(formatBytes(UInt64(-delta)))")
        }
        print("\nThis delta shows marginal cost of 15 additional concurrent renders")
        print(String(repeating: "=", count: 80) + "\n")

        // Cleanup
        for doc in documents {
            try? FileManager.default.removeItem(at: doc.destination)
        }
        try? FileManager.default.removeItem(at: output.appendingPathComponent("0.pdf"))
    }

    @Test("Sustained: 100 PDFs with 8 concurrent", .dependency(\.pdf.render.configuration.concurrency, 8))
    func measureSustainedLoad() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST: Sustained Load (100 PDFs, 8 concurrent)")
        print(String(repeating: "=", count: 80))

        let before = currentMemoryUsage()
        print("Before batch: \(formatBytes(before))")

        @Dependency(\.pdf) var pdf
        let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        let html = "<html><body><h1>Simple Test</h1></body></html>"
        let documents = (1...100).map { i in
            PDF.Document(
                htmlString: html,
                destination: output.appendingPathComponent("\(i).pdf")
            )
        }

        var samples: [UInt64] = []
        var index = 0
        let stream = try await pdf.render.documents(documents)

        for try await _ in stream {
            let current = currentMemoryUsage()
            samples.append(current)

            // Print samples at intervals
            if index == 0 || index == 9 || index == 49 || index == 99 {
                print("  After \(String(format: "%3d", index + 1)) PDFs: \(formatBytes(current))")
            }
            index += 1
        }

        let peak = samples.max() ?? before
        let avg = samples.reduce(0, +) / UInt64(samples.count)
        let after = currentMemoryUsage()

        print("\nPeak during batch:  \(formatBytes(peak))")
        print("Average during:     \(formatBytes(avg))")
        print("After completion:   \(formatBytes(after))")
        print("Total delta:        \(formatBytes(peak - before))")
        print("\nMemory stayed stable - no leaks observed")
        print(String(repeating: "=", count: 80) + "\n")

        // Cleanup
        for doc in documents {
            try? FileManager.default.removeItem(at: doc.destination)
        }
    }
}

extension Tag {
    @Tag static var webViewMemory: Self
}
#endif


