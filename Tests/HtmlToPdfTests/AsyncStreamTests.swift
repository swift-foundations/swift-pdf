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
import Metrics
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

            // Track URLs as stream yields them
            var yieldedURLs: [URL] = []

            let htmls = [String](repeating: TestHTML.simple, count: count)
            let stream = try await pdf.render.client.html(htmls, to: output)

            for try await result in stream {
                yieldedURLs.append(result.url)
                #expect(FileManager.default.fileExists(atPath: result.url.path), "Yielded URL should exist")
            }

            // Verify all results were yielded
            #expect(yieldedURLs.count == count, "Should yield all \(count) results")

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
