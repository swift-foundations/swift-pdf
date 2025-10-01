//
//  AsyncStreamTests.swift
//  swift-html-to-pdf
//
//  Tests for AsyncThrowingStream<URL, Error> return values
//

import Testing
import Foundation
@testable import HtmlToPdf

@Suite("AsyncStream Results", .serialized)
struct AsyncStreamTests {

    @Test("AsyncStream yields correct URLs for small batch")
    func testAsyncStreamSmallBatch() async throws {
        let count = 5
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let htmls = [String](repeating: .html, count: count)
        let stream: AsyncThrowingStream = try await htmls.print(
            to: output,
            configuration: .a4,
            filename: { _ in UUID().uuidString }
        )

        try await stream.testIfYieldedUrlExistsOnFileSystem(directory: output)

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count, "All files should exist after stream completes")
    }

    @Test("AsyncStream yields URLs as PDFs complete")
    func testAsyncStreamProgressiveResults() async throws {
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
        let stream: AsyncThrowingStream = try await htmls.print(
            to: output,
            configuration: .a4,
            filename: { i in "doc-\(i)" }
        )

        for try await url in stream {
            await tracker.recordCompletion(url: url)
            #expect(FileManager.default.fileExists(atPath: url.path), "Yielded URL should exist")
        }

        let completedCount = await tracker.completedCount
        let yieldedURLs = await tracker.yieldedURLs

        #expect(completedCount == count, "Should yield all \(count) URLs")
        #expect(yieldedURLs.count == count, "Should track all completions")

        // Verify all files exist
        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count, "All files should exist")
    }

    @Test("AsyncStream from Documents")
    func testAsyncStreamFromDocuments() async throws {
        let count = 8
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

        let stream: AsyncThrowingStream = try await documents.print(configuration: .a4)

        try await stream.testIfYieldedUrlExistsOnFileSystem(directory: output)

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count, "All documents should be created")
    }

    @Test("Concurrent AsyncStreams")
    func testConcurrentAsyncStreams() async throws {
        let count = 10
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        async let stream1: AsyncThrowingStream = try [String](repeating: .html, count: count).print(
            to: output,
            configuration: .a4,
            filename: { _ in "stream1-\(UUID().uuidString)" }
        )

        async let stream2: AsyncThrowingStream = try [String](repeating: .html, count: count).print(
            to: output,
            configuration: .a4,
            filename: { _ in "stream2-\(UUID().uuidString)" }
        )

        try await stream1.testIfYieldedUrlExistsOnFileSystem(directory: output)
        try await stream2.testIfYieldedUrlExistsOnFileSystem(directory: output)

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count * 2, "Both streams should complete")
    }
}
