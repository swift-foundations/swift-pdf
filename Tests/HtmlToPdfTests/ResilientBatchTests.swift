//
//  ResilientBatchTests.swift
//  swift-html-to-pdf
//
//  Tests for resilient batch processing that continues on individual failures
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
@testable import HtmlToPdf

@Suite("Resilient Batch Processing", .dependency(\.pdf, .liveValue), .serialized)
struct ResilientBatchTests {
    @Dependency(\.pdf) var pdf

    @Test("Resilient batch continues after individual failures")
    func testResilientBatchContinuesOnFailure() async throws {
        let output = URL.temporaryDirectory.appendingPathComponent("resilient-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Create mix of valid documents and one with invalid destination
        let invalidPath = URL(fileURLWithPath: "/dev/null/impossible.pdf")
        let documents = [
            PDF.Document(htmlString: "<html><body><h1>Doc 1</h1></body></html>", title: "doc1", in: output),
            PDF.Document(htmlString: "<html><body><h1>Doc 2</h1></body></html>", destination: invalidPath),  // Invalid: bad path
            PDF.Document(htmlString: "<html><body><h1>Doc 3</h1></body></html>", title: "doc3", in: output),
            PDF.Document(htmlString: "<html><body><h1>Doc 4</h1></body></html>", title: "doc4", in: output),
        ]

        var successes: [PDF.Result] = []
        var failures: [PDF.FailedDocument] = []

        // Use resilient API - stream never throws
        for await batchResult in await pdf.render.client.documentsResilient(documents) {
            switch batchResult {
            case .success(let pdfResult):
                successes.append(pdfResult)
            case .failure(let failed):
                failures.append(failed)
            }
        }

        // Verify we got results for all documents
        #expect(successes.count + failures.count == 4, "Should process all documents")

        // Verify we got expected successes (doc1, doc3, doc4)
        #expect(successes.count == 3, "Should have 3 successful documents")

        // Verify we got expected failure (doc2 - invalid path)
        #expect(failures.count == 1, "Should have 1 failed document")
        #expect(failures.first?.index == 1, "Failed document should be at index 1 (doc2)")
        #expect(failures.first?.document.destination == invalidPath, "Failed document should have invalid path")

        // Verify all successful PDFs exist
        for success in successes {
            #expect(FileManager.default.fileExists(atPath: success.url.path), "PDF should exist at \(success.url.lastPathComponent)")
        }
    }

    @Test("Resilient batch reports failure details")
    func testResilientBatchFailureDetails() async throws {
        let output = URL.temporaryDirectory.appendingPathComponent("resilient-details-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Create document with invalid destination (readonly directory if we can)
        let invalidPath = URL(fileURLWithPath: "/dev/null/impossible.pdf")
        let documents = [
            PDF.Document(htmlString: "<html><body><h1>Valid</h1></body></html>", title: "valid", in: output),
            PDF.Document(htmlString: "<html><body><h1>Invalid</h1></body></html>", destination: invalidPath),
        ]

        var failures: [PDF.FailedDocument] = []

        for await batchResult in await pdf.render.client.documentsResilient(documents) {
            if case .failure(let failed) = batchResult {
                failures.append(failed)
            }
        }

        // Verify failure contains useful information
        #expect(failures.count >= 1, "Should have at least one failure")
        if let failed = failures.first {
            #expect(failed.index == 1, "Failure should be for document 1")
            #expect(failed.document.destination == invalidPath, "Failure should include original document")
            // Error type may vary (NSError, PrintingError, etc.) - just verify it exists
            #expect(failed.duration >= .zero, "Failure should include duration")
        }
    }

    @Test("Compare fail-fast vs resilient behavior")
    func testFailFastVsResilient() async throws {
        let output = URL.temporaryDirectory.appendingPathComponent("compare-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let invalidPath = URL(fileURLWithPath: "/dev/null/impossible.pdf")
        let documents = [
            PDF.Document(htmlString: "<html><body>1</body></html>", title: "1", in: output),
            PDF.Document(htmlString: "<html><body>2</body></html>", destination: invalidPath),  // This will fail
            PDF.Document(htmlString: "<html><body>3</body></html>", title: "3", in: output),
        ]

        // Test 1: Fail-fast (throws on first error)
        do {
            var count = 0
            for try await _ in try await pdf.render.client.documents(documents) {
                count += 1
            }
            Issue.record("Should have thrown on invalid path")
        } catch {
            // Expected - batch stopped on error
            // Just verify we got an error (type varies by system)
        }

        // Clean up for next test
        try? FileManager.default.removeItem(at: output)

        // Test 2: Resilient (continues on errors)
        var total = 0
        for await _ in await pdf.render.client.documentsResilient(documents) {
            total += 1
        }

        #expect(total == 3, "Resilient should process all documents (2 success + 1 failure)")
    }

    @Test("Resilient batch with all successes")
    func testResilientBatchAllSuccesses() async throws {
        let output = URL.temporaryDirectory.appendingPathComponent("all-success-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        let documents = (1...10).map { i in
            PDF.Document(htmlString: "<html><body>Doc \(i)</body></html>", title: "\(i)", in: output)
        }

        var successes = 0
        var failures = 0

        for await batchResult in await pdf.render.client.documentsResilient(documents) {
            switch batchResult {
            case .success:
                successes += 1
            case .failure:
                failures += 1
            }
        }

        #expect(successes == 10, "All documents should succeed")
        #expect(failures == 0, "No failures expected")
    }
}
