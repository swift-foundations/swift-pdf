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
@testable import HtmlToPdfLive

@Suite(
    "Convenience API Levels",
    .serialized
)
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

        let html = [
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
        for try await result in try await pdf.render(html: html, to: output) {
            urls2.append(result.url)
        }
        #expect(urls2.count == 3, "Capability-level htmls should work")

        // Clean for next test
        try? FileManager.default.removeItem(at: output)

        // Level 3: Explicit client
        var urls3: [URL] = []
        for try await result in try await pdf.render.client.html(html, to: output) {
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
