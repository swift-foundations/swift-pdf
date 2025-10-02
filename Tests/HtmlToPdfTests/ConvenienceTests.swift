//
//  ConvenienceTests.swift
//  swift-html-to-pdf
//
//  Tests demonstrating three levels of API convenience
//

import Testing
import Foundation
import Dependencies
@testable import HtmlToPdf

@Suite("Convenience API Levels", .serialized)
struct ConvenienceTests {

    @Test("Level 1: Top-level convenience (shortest)")
    func testTopLevelConvenience() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.render.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = "<html><body><h1>Level 1: Top-level</h1></body></html>"
            let output = URL.temporaryDirectory
                .appendingPathComponent("level1-\(UUID().uuidString).pdf")

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            // Shortest form - forwards through PDF -> Render -> Client
            let result = try await pdf.html(html, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path), "Top-level convenience should work")
        }
    }

    @Test("Level 2: Capability-level convenience (mid-level)")
    func testCapabilityLevelConvenience() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.render.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = "<html><body><h1>Level 2: Capability</h1></body></html>"
            let output = URL.temporaryDirectory
                .appendingPathComponent("level2-\(UUID().uuidString).pdf")

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            // Mid-level - shows capability structure, forwards to client
            let result = try await pdf.render.html(html, output)

            #expect(FileManager.default.fileExists(atPath: result.path), "Capability-level convenience should work")
        }
    }

    @Test("Level 3: Explicit client access (full control)")
    func testExplicitClientAccess() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.render.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = "<html><body><h1>Level 3: Explicit</h1></body></html>"
            let output = URL.temporaryDirectory
                .appendingPathComponent("level3-\(UUID().uuidString).pdf")

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            // Explicit form - direct client access
            let result = try await pdf.render.client.html(html, output)

            #expect(FileManager.default.fileExists(atPath: result.path), "Explicit client access should work")
        }
    }

    @Test("Batch convenience levels")
    func testBatchConvenienceLevels() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.render.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

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

            // Level 1: Top-level (batch -> batchSync for clarity)
            let urls1 = try await pdf.batchSync(htmls, to: output)
            #expect(urls1.count == 3, "Top-level batch should work")

            // Clean for next test
            try? FileManager.default.removeItem(at: output)

            // Level 2: Capability-level
            let urls2 = try await pdf.render.renderBatchSync(htmls, to: output)
            #expect(urls2.count == 3, "Capability-level batch should work")

            // Clean for next test
            try? FileManager.default.removeItem(at: output)

            // Level 3: Explicit client
            let urls3 = try await pdf.render.client.renderBatchSync(htmls, to: output)
            #expect(urls3.count == 3, "Explicit client batch should work")
        }
    }

    @Test("Data rendering convenience levels")
    func testDataRenderingLevels() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.render.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let html = "<html><body><h1>In-memory PDF</h1></body></html>"

            // Level 1: Top-level
            let data1 = try await pdf.data(html)
            #expect(data1.count > 1000, "Top-level data should work")

            // Level 2: Capability-level
            let data2 = try await pdf.render.data(html)
            #expect(data2.count > 1000, "Capability-level data should work")

            // Level 3: Explicit client
            let data3 = try await pdf.render.client.data(html)
            #expect(data3.count > 1000, "Explicit client data should work")
        }
    }

    @Test("Document array convenience levels")
    func testDocumentArrayLevels() async throws {
        try await withDependencies {
            $0.pdf = .liveValue
            $0.pdf.render.configuration = .default
        } operation: {
            @Dependency(\.pdf) var pdf

            let output = URL.temporaryDirectory
                .appendingPathComponent("docs-\(UUID().uuidString)")

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let documents = [
                PDF.Document(htmlString: "<html><body>A</body></html>", title: "a", in: output),
                PDF.Document(htmlString: "<html><body>B</body></html>", title: "b", in: output)
            ]

            // Level 1: Top-level
            var count1 = 0
            for try await _ in try await pdf.documents(documents) {
                count1 += 1
            }
            #expect(count1 == 2, "Top-level documents should work")

            // Clean for next test
            try? FileManager.default.removeItem(at: output)

            // Level 2: Capability-level
            var count2 = 0
            for try await _ in try await pdf.render.documents(documents) {
                count2 += 1
            }
            #expect(count2 == 2, "Capability-level documents should work")

            // Clean for next test
            try? FileManager.default.removeItem(at: output)

            // Level 3: Explicit client
            var count3 = 0
            for try await _ in try await pdf.render.client.documents(documents) {
                count3 += 1
            }
            #expect(count3 == 2, "Explicit client documents should work")
        }
    }
}
