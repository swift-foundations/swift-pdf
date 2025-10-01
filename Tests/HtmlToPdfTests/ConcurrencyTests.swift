//
//  ConcurrencyTests.swift
//  swift-html-to-pdf
//
//  Tests for concurrent PDF generation and pool behavior
//

import Testing
import Foundation
@testable import HtmlToPdf

@Suite("Concurrency & Pool Behavior")
struct ConcurrencyTests {

    // MARK: - Pool Efficiency Tests

    @Test("Pool handles 20 documents efficiently")
    func testMediumBatch() async throws {
        let count = 20
        let htmls = [String](repeating: .html, count: count)
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let config = PrintingConfiguration(
            maxConcurrentOperations: 5,
            webViewAcquisitionTimeout: 30
        )

        try await htmls.print(
            to: output,
            configuration: .a4,
            printingConfiguration: config
        )

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count, "All \(count) documents should be created")
    }

    @Test("Pool handles 50 documents with queueing")
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

        let config = PrintingConfiguration(
            maxConcurrentOperations: 4,
            webViewAcquisitionTimeout: 60,
            progressHandler: { completed, total in
                Task { await tracker.increment() }
            }
        )

        try await htmls.print(
            to: output,
            configuration: .a4,
            printingConfiguration: config
        )

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
                group.addTask {
                    let htmls = [String](repeating: .html, count: 10)
                    try? await htmls.print(
                        to: output,
                        configuration: .a4,
                        filename: { i in "batch\(batch)-doc\(i)" }
                    )
                }
            }
            await group.waitForAll()
        }

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == 30, "All concurrent operations should complete")
    }

    @Test("Pool reuses resources efficiently")
    func testResourceReuse() async throws {
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Generate documents in waves to test resource reuse
        for wave in 1...5 {
            let htmls = [String](repeating: .html, count: 3)
            try await htmls.print(
                to: output,
                configuration: .a4,
                filename: { i in "wave\(wave)-doc\(i)" }
            )
        }

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == 15, "All waves should complete with resource reuse")
    }

    // MARK: - Pool Stress Tests

    @Test("Pool handles many small documents")
    func testManySmallDocuments() async throws {
        let count = 100
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let documents = (1...count).map { i in
            Document(
                fileUrl: output.appendingPathComponent("doc-\(i).pdf"),
                html: "<html><body><p>Document \(i)</p></body></html>"
            )
        }

        let config = PrintingConfiguration(
            maxConcurrentOperations: 8,
            webViewAcquisitionTimeout: 120
        )

        try await documents.print(
            configuration: .a4,
            printingConfiguration: config
        )

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count, "Should handle \(count) small documents")
    }

    @Test("Pool handles timeout gracefully")
    func testPoolTimeout() async throws {
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Create situation where pool is exhausted
        let htmls = [String](repeating: .html2, count: 10)  // Complex HTML takes longer

        let config = PrintingConfiguration(
            maxConcurrentOperations: 1,
            webViewAcquisitionTimeout: 1  // Very short timeout to trigger queue
        )

        do {
            try await htmls.print(
                to: output,
                configuration: .a4,
                printingConfiguration: config
            )
            // May succeed if operations are fast enough
        } catch {
            // Expected to fail due to aggressive timeout
            #expect(error.localizedDescription.contains("timeout") ||
                    error.localizedDescription.contains("exhausted"))
        }
    }

    // MARK: - Mixed Workload Tests

    @Test("Pool handles mixed document sizes")
    func testMixedDocumentSizes() async throws {
        let output = URL.output()

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        var documents: [Document] = []

        // Small documents
        for i in 1...10 {
            documents.append(Document(
                fileUrl: output.appendingPathComponent("small-\(i).pdf"),
                html: "<html><body><p>Small \(i)</p></body></html>"
            ))
        }

        // Large documents
        for i in 1...5 {
            documents.append(Document(
                fileUrl: output.appendingPathComponent("large-\(i).pdf"),
                html: String.html2
            ))
        }

        let config = PrintingConfiguration(
            maxConcurrentOperations: 5,
            webViewAcquisitionTimeout: 60
        )

        try await documents.print(
            configuration: .a4,
            printingConfiguration: config
        )

        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == 15, "Should handle mixed workload")
    }
}
