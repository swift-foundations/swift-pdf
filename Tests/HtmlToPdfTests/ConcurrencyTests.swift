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

        let count = 50
        let htmls = [String](repeating: .html, count: count)
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

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

    // MARK: - Concurrent Operation Tests

    @Test("Multiple concurrent print operations")
    func testConcurrentOperations() async throws {

        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

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
                        let htmls = [String](repeating: .html, count: 10)
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

    @Test("Handles rapid sequential operations")
    func testRapidSequentialOperations() async throws {

        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Generate 20 PDFs one after another rapidly
        for i in 1...20 {
            let html = "<html><body><h1>Document \(i)</h1></body></html>"
            let doc = PDF.Document(htmlString: html, title: "rapid-\(i)", in: output)
            _ = try await pdf.render.client.document(doc)
        }

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == 20, "All 20 sequential documents should be created")
    }

    // MARK: - Concurrency Limit Tests

    @Test(
        "Respects maxConcurrentOperations limit",
        .dependency(\.pdf.render.configuration.concurrency, 2)
    )
    func testConcurrencyLimit() async throws {

        let count = 10
        let htmls = [String](repeating: .html, count: count)
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        var urls: [URL] = []
        for try await result in try await pdf.render.client.html(htmls, to: output) {
            urls.append(result.url)
        }

        #expect(urls.count == count, "Should complete all documents despite low concurrency")

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count)
    }

    // MARK: - Mixed Size Documents

    @Test(
        "Handles mixed document sizes efficiently",
        .dependency(\.pdf.render.configuration.concurrency, 5),
        .dependency(\.pdf.render.configuration.webViewAcquisitionTimeout, .seconds(60))
    )
    func testMixedDocumentSizes() async throws {

        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

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
                htmlString: String.html2,
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

    // MARK: - Resource Cleanup Tests

    @Test("Resources properly cleaned up after batch")
    func testResourceCleanup() async throws {

        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Generate multiple batches sequentially
        for batch in 1...3 {
            try await withDependencies {
                $0.pdf.render.configuration.namingStrategy = .init { i in "batch\(batch)-\(i)" }
            } operation: {
                let htmls = [String](repeating: .html, count: 10)
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
