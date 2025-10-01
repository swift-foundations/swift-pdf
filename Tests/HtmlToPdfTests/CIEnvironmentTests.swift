//
//  CIEnvironmentTests.swift
//  swift-html-to-pdf
//
//  Tests for HTML to PDF functionality in CI environments
//

import Testing
import Foundation
import WebKit
@testable import HtmlToPdf
import Dependencies
import DependenciesTestSupport
import EnvironmentVariables

@Suite("CI Environment Tests", .serialized)
struct CIEnvironmentTests {

    @Test(
        "HTML to PDF in CI environment",
        .dependency(\.envVars, {
            var env = EnvironmentVariables.local
            env["CI"] = "true"
            env["GITHUB_ACTIONS"] = "true"
            env["RUNNER_OS"] = "macOS"
            env["RUNNER_ARCH"] = "X64"
            env["WEBVIEW_POOL_SIZE"] = "4"
            return env
        }())
    )
    func testHtmlToPdfInCI() async throws {
        let html = "<html><body><h1>CI Test Document</h1><p>Generated in CI environment</p></body></html>"
        let output = URL.temporaryDirectory
            .appendingPathComponent("ci-test")
            .appendingPathExtension("pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Should successfully generate PDF in CI environment
        try await html.print(to: output, configuration: .a4)

        #expect(FileManager.default.fileExists(atPath: output.path), "PDF should be created in CI environment")

        // Verify PDF has content
        let pdfData = try Data(contentsOf: output)
        #expect(pdfData.count > 0, "PDF should have content")
    }

    @Test(
        "Batch processing in memory-constrained CI",
        .dependency(\.envVars, {
            var env = EnvironmentVariables.local
            env["CI"] = "true"
            env["WEBVIEW_POOL_SIZE"] = "3"
            return env
        }())
    )
    func testBatchProcessingInCI() async throws {
        let documentCount = 5
        let htmlDocuments = (1...documentCount).map { i in
            "<html><body><h1>Document \(i)</h1><p>Content for document \(i)</p></body></html>"
        }

        let outputDir = URL.temporaryDirectory.appendingPathComponent("ci-batch-test")
        defer {
            try? FileManager.default.removeItem(at: outputDir)
        }

        // Process documents with limited resources (simulating CI)
        try await htmlDocuments.print(to: outputDir, configuration: .a4)

        // Verify all documents were processed
        let files = try FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)
        #expect(files.count == documentCount, "All documents should be processed in CI")

        // Verify each PDF has content
        for file in files {
            let pdfData = try Data(contentsOf: file)
            #expect(pdfData.count > 0, "Each PDF should have content")
        }
    }

    @Test(
        "Large HTML document in CI",
        .dependency(\.envVars, {
            var env = EnvironmentVariables.local
            env["CI"] = "true"
            env["WEBVIEW_POOL_SIZE"] = "2"
            return env
        }())
    )
    func testLargeHtmlInCI() async throws {
        // Generate large HTML content
        let largeContent = String(repeating: "<p>This is a paragraph with some content to make the document larger. ", count: 1000)
        let html = "<html><body><h1>Large Document Test</h1>\(largeContent)</body></html>"

        let output = URL.temporaryDirectory
            .appendingPathComponent("large-ci-test")
            .appendingPathExtension("pdf")

        defer {
            try? FileManager.default.removeItem(at: output)
        }

        // Should handle large documents even with limited resources
        try await html.print(to: output, configuration: .a4)

        #expect(FileManager.default.fileExists(atPath: output.path), "Large PDF should be created in CI")

        // Verify PDF has substantial content
        let pdfData = try Data(contentsOf: output)
        #expect(pdfData.count > 10000, "Large PDF should have substantial content")
    }

    @Test(
        "Concurrent PDF generation in CI",
        .dependency(\.envVars, {
            var env = EnvironmentVariables.local
            env["CI"] = "true"
            env["WEBVIEW_POOL_SIZE"] = "4"
            return env
        }())
    )
    func testConcurrentGenerationInCI() async throws {
        let taskCount = 8
        let outputDir = URL.temporaryDirectory.appendingPathComponent("concurrent-ci-test")

        defer {
            try? FileManager.default.removeItem(at: outputDir)
        }

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Run concurrent PDF generation tasks
        await withTaskGroup(of: Bool.self) { group in
            for i in 1...taskCount {
                group.addTask {
                    do {
                        let html = "<html><body><h1>Concurrent Task \(i)</h1><p>Generated concurrently in CI</p></body></html>"
                        let output = outputDir.appendingPathComponent("task-\(i).pdf")

                        try await html.print(to: output, configuration: .a4)
                        return FileManager.default.fileExists(atPath: output.path)
                    } catch {
                        print("Task \(i) failed: \(error)")
                        return false
                    }
                }
            }

            var successCount = 0
            for await success in group {
                if success {
                    successCount += 1
                }
            }

            #expect(successCount == taskCount, "All concurrent tasks should succeed in CI")
        }
    }
}