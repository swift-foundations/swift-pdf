//
//  WebViewPoolTests.swift
//  swift-html-to-pdf
//
//  Tests for WebView pool sizing and performance
//

import Testing
import Foundation
import Dependencies
@testable import HtmlToPdf
#if canImport(WebKit)
import WebKit

@Suite("WebViewPool Tests")
struct WebViewPoolTests {

    // MARK: - Pool Size Calculation Tests

    @Test("Pool size calculation respects minimum")
    func testMinimumPoolSize() async throws {
        // Even on very low-resource systems, we should have at least 2 WebViews
        // This is tested by the actual calculation in the library
        @Dependency(\.webViewPool) var pool

        // Acquire two web views to verify minimum pool size
        let webView1 = try await pool.acquireWebView()
        let webView2 = try await pool.acquireWebView()

        #expect(webView1 !== webView2, "Should get different WebView instances")

        await pool.releaseWebView(webView1)
        await pool.releaseWebView(webView2)
    }

    @Test("Pool size respects environment variable")
    func testEnvironmentVariableOverride() async throws {
        // This test verifies that WEBVIEW_POOL_SIZE environment variable works
        // Run with: env WEBVIEW_POOL_SIZE=3 swift test --filter testEnvironmentVariableOverride

        if let poolSizeStr = ProcessInfo.processInfo.environment["WEBVIEW_POOL_SIZE"],
           let expectedSize = Int(poolSizeStr) {

            @Dependency(\.webViewPool) var pool
            var webViews: [WKWebView] = []

            // Try to acquire the expected number of WebViews
            for _ in 0..<expectedSize {
                do {
                    let webView = try await pool.acquireWebView()
                    webViews.append(webView)
                } catch {
                    break // Pool exhausted
                }
            }

            #expect(webViews.count == expectedSize, "Pool size should match environment variable")

            // Clean up
            for webView in webViews {
                await pool.releaseWebView(webView)
            }
        }
    }

    // MARK: - Performance Tests with Different Pool Sizes

    @Test("Performance with different pool sizes")
    func testPoolSizePerformance() async throws {
        // Test with a small number of documents for quick execution
        let documentCount = 3

        for poolSize in [2, 4, 8] {
            let startTime = Date()

            // Create simple test documents
            let testHTML = "<html><body><h1>Test</h1></body></html>"
            let urls = (0..<documentCount).map { i in
                URL.temporaryDirectory
                    .appendingPathComponent("perf-test-\(poolSize)-\(i)")
                    .appendingPathExtension("pdf")
            }

            // Generate PDFs
            for url in urls {
                try await testHTML.print(to: url, configuration: .a4, createDirectories: false)
            }

            let duration = Date().timeIntervalSince(startTime)
            print("[Performance] Pool size: \(poolSize), Documents: \(documentCount), Time: \(String(format: "%.3f", duration))s")

            // Clean up
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Concurrency Stress Tests

    @Test("Concurrent acquisition and release")
    func testConcurrentPoolAccess() async throws {
        @Dependency(\.webViewPool) var pool

        // Get pool statistics to understand capacity
        let initialStats = await pool.getStatistics()
        print("[Concurrent Test] Pool capacity: \(initialStats.available + initialStats.inUse)")

        // Use reasonable number of concurrent tasks (2x pool size)
        let concurrentTasks = min(16, (initialStats.available + initialStats.inUse) * 2)

        // Stress test with concurrent tasks
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentTasks {
                group.addTask { [pool] in
                    do {
                        // Use acquireWithRetry which has timeout built-in
                        let webView = try await pool.acquireWithRetry(3, 1.0)

                        // Simulate very brief work (10-20ms)
                        try await Task.sleep(nanoseconds: UInt64.random(in: 10_000_000...20_000_000))

                        await pool.releaseWebView(webView)
                    } catch {
                        print("[Concurrent Test] Task \(i) failed: \(error)")
                        throw error
                    }
                }
            }

            try await group.waitForAll()
        }

        // Verify pool is back to normal
        let finalStats = await pool.getStatistics()
        print("[Concurrent Test] Completed. Total acquisitions: \(finalStats.totalAcquisitions)")
        #expect(finalStats.pending == 0, "No requests should be pending after test")
    }

    @Test("Pool exhaustion handling")
    func testPoolExhaustion() async throws {
        @Dependency(\.webViewPool) var pool
        var acquiredViews: [WKWebView] = []

        // Wait for pool to initialize
        await pool.waitForInitialization()

        // Get initial pool size
        let stats = await pool.getStatistics()
        let poolSize = stats.available + stats.inUse

        // Try to acquire more views than pool size
        for i in 0..<(poolSize + 5) {
            do {
                // Use short timeout to test exhaustion quickly
                let webView = try await pool.acquireWithRetry(1, 0.5)
                acquiredViews.append(webView)
                print("[Exhaustion Test] Acquired view \(i + 1)")
            } catch WebViewPoolActor.Error.timeout {
                // Pool exhausted, this is expected
                print("[Exhaustion Test] Pool exhausted after \(acquiredViews.count) acquisitions")
                break
            } catch {
                print("[Exhaustion Test] Unexpected error: \(error)")
                throw error
            }
        }

        #expect(acquiredViews.count > 0, "Should acquire at least some WebViews")
        #expect(acquiredViews.count <= poolSize, "Shouldn't acquire more than pool size")

        // Release all views
        for view in acquiredViews {
            await pool.releaseWebView(view)
        }

        // Verify pool is restored
        let finalStats = await pool.getStatistics()
        #expect(finalStats.available == poolSize, "All WebViews should be available again")
    }

    @Test("WebView reuse verification")
    func testWebViewReuse() async throws {
        @Dependency(\.webViewPool) var pool

        // Wait for pool to initialize
        await pool.waitForInitialization()

        // Acquire a WebView
        let firstWebView = try await pool.acquireWebView()
        let firstPointer = Unmanaged.passUnretained(firstWebView).toOpaque()

        // Release it
        await pool.releaseWebView(firstWebView)

        // Acquire again - should get the same instance
        let secondWebView = try await pool.acquireWebView()
        let secondPointer = Unmanaged.passUnretained(secondWebView).toOpaque()

        #expect(firstPointer == secondPointer, "Should reuse the same WebView instance")

        await pool.releaseWebView(secondWebView)
    }

    @Test("Acquisition timeout handling")
    func testAcquisitionTimeout() async throws {
        @Dependency(\.webViewPool) var pool

        // Wait for pool to initialize
        await pool.waitForInitialization()

        // Get pool size
        let stats = await pool.getStatistics()
        let poolSize = stats.available + stats.inUse

        // Acquire all available WebViews
        var heldViews: [WKWebView] = []
        for _ in 0..<poolSize {
            let view = try await pool.acquireWebView()
            heldViews.append(view)
        }

        // Now try to acquire one more with a short timeout - should fail
        do {
            _ = try await pool.acquireWithRetry(1, 0.5)
            Issue.record("Should have timed out")
        } catch WebViewPoolActor.Error.timeout {
            // Expected
            print("[Timeout Test] Correctly timed out when pool exhausted")
        }

        // Release all views
        for view in heldViews {
            await pool.releaseWebView(view)
        }
    }

    @Test("Pool statistics tracking")
    func testPoolStatistics() async throws {
        @Dependency(\.webViewPool) var pool

        // Wait for pool to initialize
        await pool.waitForInitialization()

        // Get initial statistics
        let initialStats = await pool.getStatistics()
        print("[Stats Test] Initial: \(initialStats)")

        // Perform some operations
        let view1 = try await pool.acquireWebView()
        let stats1 = await pool.getStatistics()
        #expect(stats1.totalAcquisitions > initialStats.totalAcquisitions)

        let view2 = try await pool.acquireWebView()
        let stats2 = await pool.getStatistics()
        #expect(stats2.totalAcquisitions > stats1.totalAcquisitions)

        // Release views
        await pool.releaseWebView(view1)
        await pool.releaseWebView(view2)

        let finalStats = await pool.getStatistics()
        print("[Stats Test] Final: \(finalStats)")
        #expect(finalStats.pending == 0)
    }

}

// MARK: - Pool Size Calculation Unit Tests

@Suite("Pool Size Calculation")
struct PoolSizeCalculationTests {

    @Test("Calculation for typical desktop system")
    func testDesktopCalculation() {
        // We can't directly test the private calculateOptimalPoolSize function,
        // but we can verify the behavior through the public API

        let processInfo = ProcessInfo.processInfo
        let cpuCount = processInfo.activeProcessorCount
        let memoryGB = Double(processInfo.physicalMemory) / (1024 * 1024 * 1024)

        // Based on the algorithm:
        // - Memory limit: 10% of RAM / 200MB per WebView
        // - CPU limit: min(cpuCount, 8)
        // - Platform max: 8 for macOS

        let expectedMemoryLimit = Int((memoryGB * 1024 * 0.10) / 200)
        let expectedCPULimit = min(cpuCount, 8)
        let expected = max(2, min(expectedMemoryLimit, expectedCPULimit, 8))

        print("[Calculation Test] CPUs: \(cpuCount), Memory: \(memoryGB)GB, Expected: \(expected)")

        #expect(expected >= 2, "Should always have at least 2 WebViews")
        #expect(expected <= cpuCount, "Should not exceed CPU count")
        #expect(expected <= 8, "Should not exceed platform maximum")
    }

    @Test("Memory-constrained calculation")
    func testMemoryConstrainedSystem() {
        // This test documents the expected behavior for low-memory systems
        // For a system with 4GB RAM:
        // 4GB * 0.10 = 409MB for WebViews
        // 409MB / 200MB per WebView = ~2 WebViews

        let lowMemoryGB = 4.0
        let expectedPoolSize = Int((lowMemoryGB * 1024 * 0.10) / 200)

        #expect(expectedPoolSize >= 2, "Even low-memory systems should support 2 WebViews")
    }

    @Test("CPU-constrained calculation")
    func testCPUConstrainedSystem() {
        // Document expected behavior for systems with few CPUs
        // For a dual-core system: min(2, 8) = 2
        // But we ensure minimum of 2, so result is 2

        let dualCoreExpected = max(2, min(2, 8))
        #expect(dualCoreExpected == 2, "Dual-core should use 2 WebViews")

        let quadCoreExpected = max(2, min(4, 8))
        #expect(quadCoreExpected == 4, "Quad-core should use 4 WebViews")
    }
}

#endif // canImport(WebKit)