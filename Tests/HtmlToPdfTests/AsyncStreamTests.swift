//
//  AsyncStreamTests.swift
//  swift-html-to-pdf
//
//  Tests for AsyncThrowingStream<PDF.Result, Error> return values
//

import Testing
import Foundation
import Dependencies
@testable import HtmlToPdf

@Suite("AsyncStream Results", .serialized)
struct AsyncStreamTests {

    @Test("AsyncStream yields correct results for small batch")
    func testAsyncStreamSmallBatch() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdfConfiguration = .default
            $0.pdfConfiguration.namingStrategy = .custom { _ in UUID().uuidString }
        } operation: {
            @Dependency(\.pdf) var pdf

            let count = 5
            let output = URL.output()

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let htmls = [String](repeating: .html, count: count)
            let stream = try await pdf.renderBatch(htmls, output)

            var resultCount = 0
            for try await result in stream {
                resultCount += 1
                #expect(FileManager.default.fileExists(atPath: result.url.path), "Yielded URL should exist")
            }

            #expect(resultCount == count, "Should yield all \(count) results")

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == count, "All files should exist after stream completes")
        }
    }

    @Test("AsyncStream yields results as PDFs complete")
    func testAsyncStreamProgressiveResults() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdfConfiguration = .default
            $0.pdfConfiguration.namingStrategy = .custom { i in "doc-\(i)" }
        } operation: {
            @Dependency(\.pdf) var pdf

            let count = 20
            let output = URL.output()

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            actor CompletionTracker {
                var completedCount = 0
                var yieldedURLs: [URL] = []

                func recordCompletion(url: URL) {
                    completedCount += 1
                    yieldedURLs.append(url)
                }
            }
            let tracker = CompletionTracker()

            let htmls = [String](repeating: .html, count: count)
            let stream = try await pdf.renderBatch(htmls, output)

            for try await result in stream {
                await tracker.recordCompletion(url: result.url)
                #expect(FileManager.default.fileExists(atPath: result.url.path), "Yielded URL should exist")
            }

            let completedCount = await tracker.completedCount
            let yieldedURLs = await tracker.yieldedURLs

            #expect(completedCount == count, "Should yield all \(count) URLs")
            #expect(yieldedURLs.count == count, "Should track all completions")

            // Verify all files exist
            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == count, "All files should exist")
        }
    }

    @Test("AsyncStream from Documents")
    func testAsyncStreamFromDocuments() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdfConfiguration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let count = 8
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

            let stream = try await pdf.renderDocuments(documents)

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
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdfConfiguration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let count = 10
            let output = URL.output()

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            try await withDependencies {
                $0.pdfConfiguration.namingStrategy = .custom { _ in "stream1-\(UUID().uuidString)" }
            } operation: {
                let stream1 = try await pdf.renderBatch([String](repeating: .html, count: count), output)

                for try await result in stream1 {
                    #expect(FileManager.default.fileExists(atPath: result.url.path))
                }
            }

            try await withDependencies {
                $0.pdfConfiguration.namingStrategy = .custom { _ in "stream2-\(UUID().uuidString)" }
            } operation: {
                let stream2 = try await pdf.renderBatch([String](repeating: .html, count: count), output)

                for try await result in stream2 {
                    #expect(FileManager.default.fileExists(atPath: result.url.path))
                }
            }

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == count * 2, "Both streams should complete")
        }
    }
}
