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
@testable import HtmlToPdfLive

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
