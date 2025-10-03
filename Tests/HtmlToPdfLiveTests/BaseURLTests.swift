//
//  BaseURLTests.swift
//  swift-html-to-pdf
//
//  Tests for baseURL functionality
//

import Testing
import Foundation
import Dependencies
import DependenciesTestSupport
import PDFTestSupport
@testable import HtmlToPdfLive

@Suite("BaseURL Tests", .dependency(\.pdf, .liveValue))
struct BaseURLTests {
    @Dependency(\.pdf) var pdf

    @Test("BaseURL is set correctly via withBaseURL")
    func testWithBaseURLSetsConfiguration() async throws {
        let testURL = URL(fileURLWithPath: "/test/assets")

        let configured = pdf.withBaseURL(testURL)

        #expect(configured.render.configuration.baseURL == testURL)
    }

    @Test("BaseURL nil clears configuration")
    func testWithBaseURLNilClearsConfiguration() async throws {
        // First set a baseURL
        let configured = pdf.withBaseURL(URL(fileURLWithPath: "/test"))

        // Then clear it
        let cleared = configured.withBaseURL(nil)

        #expect(cleared.render.configuration.baseURL == nil)
    }

    @Test("withBaseURL allows fluent chaining")
    func testWithBaseURLFluentAPI() async throws {
        try await withTemporaryPDF { output in
            let baseURL = URL(fileURLWithPath: "/assets")

            let html = "<html><body><h1>Test</h1></body></html>"

            let result = try await pdf
                .withBaseURL(baseURL)
                .render(html: html, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path))
        }
    }

    @Test("BaseURL is used during rendering (macOS)")
    func testBaseURLUsedInRendering() async throws {
        // Note: This test verifies the configuration is passed through
        // Actual asset loading would require test assets on disk

        try await withTemporaryPDF { output in
            let baseURL = URL(fileURLWithPath: "/tmp/test-assets")

            // HTML with relative reference (won't actually load, but tests config passing)
            let html = #"<html><body><img src="test.png"></body></html>"#

            // Should not throw - baseURL is configured even if asset doesn't exist
            let result = try await pdf
                .withBaseURL(baseURL)
                .render(html: html, to: output)

            #expect(FileManager.default.fileExists(atPath: result.path))
        }
    }

    @Test("BaseURL configuration persists across multiple renders")
    func testBaseURLPersistsAcrossRenders() async throws {
        try await withTemporaryDirectory { dir in
            let baseURL = URL(fileURLWithPath: "/assets")

            let configured = pdf.withBaseURL(baseURL)

            // Render multiple PDFs with same configuration
            for i in 1...3 {
                let output = dir.appendingPathComponent("test-\(i).pdf")
                let html = "<html><body>Document \(i)</body></html>"

                let result = try await configured.render(html: html, to: output)
                #expect(FileManager.default.fileExists(atPath: result.path))
            }

            // All should have been rendered with the baseURL
            let files = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            )

            #expect(files.count == 3)
        }
    }
}

@Suite("Concurrency Limit Tests", .dependency(\.pdf, .liveValue))
struct ConcurrencyLimitTests {
    @Dependency(\.pdf) var pdf

    @Test("Platform concurrency limits are correct")
    func testPlatformLimits() {
        #if os(macOS)
        #expect(PDF.PlatformConcurrencyLimit.macOS == 16)
        #elseif os(iOS)
        #expect(PDF.PlatformConcurrencyLimit.iOS == 8)
        #endif
    }

    @Test("Exceeding platform concurrency throws capability error")
    func testExceedingConcurrencyThrows() async throws {
        await withTemporaryDirectory { dir in
            #if os(macOS)
            let platformMax = PDF.PlatformConcurrencyLimit.macOS
            #else
            let platformMax = PDF.PlatformConcurrencyLimit.iOS
            #endif

            // Try to set concurrency above platform maximum
            let excessiveConcurrency = platformMax + 10

            await withDependencies {
                $0.pdf.render.configuration.concurrency = .fixed(excessiveConcurrency)
            } operation: {
                @Dependency(\.pdf) var configuredPDF

                let html = "<html><body>Test</body></html>"
                let output = dir.appendingPathComponent("test.pdf")

                do {
                    _ = try await configuredPDF.render(html: html, to: output)
                    Issue.record("Should have thrown capabilityUnavailable error")
                } catch let error as PrintingError {
                    if case .capabilityUnavailable(let capability, let platform, let reason) = error {
                        #expect(capability.contains("concurrency"))
                        #expect(platform.count > 0)
                        #expect(reason.contains("maximum"))
                    } else {
                        Issue.record("Expected capabilityUnavailable, got \(error)")
                    }
                } catch {
                    Issue.record("Expected PrintingError.capabilityUnavailable, got \(error)")
                }
            }
        }
    }

    @Test("Automatic concurrency respects platform limits")
    func testAutomaticConcurrencyRespectsPlatform() async throws {
        try await withTemporaryPDF { output in
            // Use automatic concurrency
            try await withDependencies {
                $0.pdf.render.configuration.concurrency = .automatic
            } operation: {
                @Dependency(\.pdf) var configuredPDF

                let html = "<html><body>Test</body></html>"

                // Should not throw - automatic should calculate safe value
                let result = try await configuredPDF.render(html: html, to: output)

                #expect(FileManager.default.fileExists(atPath: result.path))
            }
        }
    }

    @Test("Capability error messages are informative")
    func testCapabilityErrorMessages() {
        let error = PrintingError.capabilityUnavailable(
            capability: "concurrency=32",
            platform: "iOS",
            reason: "Platform maximum is 8. Requested 32 concurrent operations."
        )

        let description = error.errorDescription ?? ""
        let failureReason = error.failureReason ?? ""
        let recoverySuggestion = error.recoverySuggestion ?? ""

        #expect(description.contains("iOS"))
        #expect(description.contains("concurrency=32"))
        #expect(failureReason.count > 0)
        #expect(recoverySuggestion.contains("reduce") || recoverySuggestion.contains("platform"))
    }
}
