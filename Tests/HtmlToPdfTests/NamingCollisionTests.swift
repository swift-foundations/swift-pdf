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
