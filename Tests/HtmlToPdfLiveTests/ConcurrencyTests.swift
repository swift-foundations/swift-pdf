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
import Metrics
@testable import HtmlToPdfLive

@Suite(
    "Concurrency & Pool Behavior"
)
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
            let html = [String](repeating: TestHTML.simple, count: count)

            let stream = try await pdf.render.client.html(html, to: output)

            var completedCount = 0
            for try await _ in stream {
                completedCount += 1
            }

            // Verify all PDFs were generated
            #expect(completedCount == count, "Should generate all \(count) PDFs")

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
                            let html = [String](repeating: TestHTML.simple, count: 10)
                            var urls: [URL] = []
                            for try await result in try await batchPdf.render.client.html(html, to: outputDir) {
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
            let html = [String](repeating: TestHTML.simple, count: count)

            var urls: [URL] = []
            for try await result in try await pdf.render.client.html(html, to: output) {
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
                    let html = [String](repeating: TestHTML.simple, count: 10)
                    var urls: [URL] = []
                    for try await result in try await pdf.render.client.html(html, to: output) {
                        urls.append(result.url)
                    }
                }
            }

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == 30, "All batches should complete successfully")
        }
    }
}
