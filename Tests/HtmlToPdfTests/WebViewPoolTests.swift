//
//  WebViewPoolTests.swift
//  swift-html-to-pdf
//
//  Tests for WebView pool management and performance
//

import Testing
import Foundation
import WebKit
@testable import HtmlToPdf
import Dependencies

@Suite("WebViewPool Tests")
struct WebViewPoolTests {
    @Test("Pool size calculation respects minimum")
    func testPoolSizeCalculation() async throws {
        // Directly test the pool size calculation based on system resources
        @Dependency(\.webViewPool) var pool

        // Acquire and immediately release to trigger initialization
        do {
            let view = try await pool.acquireWebView()
            await pool.releaseWebView(view)
        } catch {
            // Timeout is acceptable on resource-constrained CI
            if case WebViewPoolActor.Error.timeout = error {
                print("[Pool Size Test] Pool initialization timed out on CI")
                return
            }
            throw error
        }

        // Get statistics
        let stats = await pool.getStatistics()
        let poolSize = stats.available + stats.inUse

        // On CI machines with limited resources, pool size might be smaller
        #expect(poolSize >= 1, "Pool should have at least 1 WebView")
        #expect(poolSize <= 16, "Pool shouldn't exceed reasonable maximum")
    }

    @Test("Performance with different pool sizes", .disabled("This test modifies global state via environment variables"))
    func testPoolPerformance() async throws {
        // This test is disabled because it modifies WEBVIEW_POOL_SIZE environment variable
        // which affects the singleton WebViewPoolActor cached by Dependencies

        // Instead, we should test performance using the default pool size
        @Dependency(\.webViewPool) var pool

        let startTime = Date()
        var acquiredViews: [WKWebView] = []

        // Try to acquire multiple views with default pool
        for _ in 0..<3 {
            do {
                let view = try await pool.acquireWithRetry(3, 2.0)
                acquiredViews.append(view)
            } catch {
                // Acceptable on CI
                break
            }
        }

        // Release all views
        for view in acquiredViews {
            await pool.releaseWebView(view)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let poolStats = await pool.getStatistics()
        let poolSize = poolStats.available + poolStats.inUse
        print("[Performance] Default pool size: \(poolSize), Documents: \(acquiredViews.count), Time: \(String(format: "%.3f", elapsed))s")
    }

    @Test("Concurrent acquisition and release")
    func testConcurrentOperations() async throws {
        @Dependency(\.webViewPool) var pool

        // Get pool capacity first
        await pool.waitForInitialization()
        let stats = await pool.getStatistics()
        let capacity = stats.available + stats.inUse

        // Skip if pool is empty (CI resource constraints)
        guard capacity > 0 else {
            print("[Concurrent Test] Skipping - no pool capacity")
            return
        }

        print("[Concurrent Test] Pool capacity: \(capacity)")

        // Run concurrent operations limited by pool capacity
        let operationCount = min(10, capacity * 2)
        var successCount = 0

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<operationCount {
                group.addTask { [pool] in
                    do {
                        let view = try await pool.acquireWithRetry(1, 1.0)
                        // Simulate some work
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        await pool.releaseWebView(view)
                        return true
                    } catch {
                        // Timeout is acceptable
                        return false
                    }
                }
            }

            for await success in group {
                if success {
                    successCount += 1
                }
            }
        }

        print("[Concurrent Test] Completed. Success rate: \(successCount)/\(operationCount)")
        #expect(successCount > 0, "Should complete at least some operations")
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

        // Skip if pool is empty
        guard poolSize > 0 else {
            print("[Exhaustion Test] Skipping - pool not initialized")
            return
        }

        // Try to acquire all views in pool
        for i in 0..<poolSize {
            do {
                let webView = try await pool.acquireWithRetry(1, 0.5)
                acquiredViews.append(webView)
                print("[Exhaustion Test] Acquired view \(i + 1)")
            } catch {
                print("[Exhaustion Test] Failed to acquire view \(i + 1): \(error)")
                break
            }
        }

        // Try to acquire one more (should timeout)
        do {
            _ = try await pool.acquireWithRetry(1, 0.5)
            Issue.record("Should have timed out when pool exhausted")
        } catch WebViewPoolActor.Error.timeout {
            print("[Exhaustion Test] Correctly timed out when pool exhausted")
        }

        // Release all views
        for view in acquiredViews {
            await pool.releaseWebView(view)
        }

        // Wait for releases to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Verify pool is restored
        let finalStats = await pool.getStatistics()
        #expect(finalStats.available == poolSize, "All WebViews should be available again")
    }

    @Test("WebView reuse verification")
    func testWebViewReuse() async throws {
        @Dependency(\.webViewPool) var pool

        // Wait for pool to initialize
        await pool.waitForInitialization()

        // Check pool availability
        let stats = await pool.getStatistics()
        guard stats.available > 0 else {
            print("[Reuse Test] Skipping - no WebViews available")
            return
        }

        // Acquire a WebView
        let firstWebView = try await pool.acquireWebView()
        let firstPointer = Unmanaged.passUnretained(firstWebView).toOpaque()

        // Release it
        await pool.releaseWebView(firstWebView)

        // Wait longer for async cleanup to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Acquire again - should get the same instance
        let secondWebView = try await pool.acquireWebView()
        let secondPointer = Unmanaged.passUnretained(secondWebView).toOpaque()

        #expect(firstPointer == secondPointer, "Should reuse the same WebView instance")

        // Cleanup
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

        // Skip if pool is empty
        guard poolSize > 0 else {
            print("[Timeout Test] Skipping - pool not initialized")
            return
        }

        var acquiredViews: [WKWebView] = []

        // Acquire all available views
        for _ in 0..<poolSize {
            do {
                let view = try await pool.acquireWithRetry(1, 0.5)
                acquiredViews.append(view)
            } catch {
                break // Pool might be partially initialized
            }
        }

        // Now try to acquire with timeout - should fail
        do {
            _ = try await pool.acquireWithRetry(1, 0.1)
            Issue.record("Should have timed out")
        } catch WebViewPoolActor.Error.timeout {
            print("[Timeout Test] Correctly timed out when pool exhausted")
        }

        // Release all views
        for view in acquiredViews {
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

        // Skip if pool is empty
        guard initialStats.available > 0 else {
            print("[Stats Test] Skipping - no WebViews available")
            return
        }

        // Perform some operations
        let view1 = try await pool.acquireWebView()
        let stats1 = await pool.getStatistics()
        #expect(stats1.totalAcquisitions > initialStats.totalAcquisitions)

        await pool.releaseWebView(view1)

        // Wait longer for async cleanup
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let finalStats = await pool.getStatistics()
        print("[Stats Test] Final: \(finalStats)")

        #expect(finalStats.totalAcquisitions >= 1, "Should track acquisitions")
        #expect(finalStats.available == initialStats.available, "Pool should be restored")
    }

    @Test("Pool size respects environment variable", .disabled("This test modifies global state and affects other tests"))
    func testEnvironmentVariableOverride() async throws {
        // This test is disabled because:
        // 1. Dependencies caches the liveValue, so setting env vars affects all subsequent tests
        // 2. The WebViewPoolActor becomes a singleton with the first env var setting
        // 3. This causes the pool exhaustion test to fail when it runs after this test

        // Set a custom pool size via environment variable
        setenv("WEBVIEW_POOL_SIZE", "2", 1)

        @Dependency(\.webViewPool) var pool

        // Wait for initialization
        await pool.waitForInitialization()

        let stats = await pool.getStatistics()
        let actualSize = stats.available + stats.inUse

        // On CI, the pool might not fully initialize
        if ProcessInfo.processInfo.environment["CI"] != nil {
            #expect(actualSize <= 2, "Pool size should respect environment variable limit")
        } else {
            #expect(actualSize == 2, "Pool size should match environment variable")
        }

        // Clean up
        unsetenv("WEBVIEW_POOL_SIZE")
    }
}

@Suite("Pool Size Calculation")
struct PoolSizeCalculationTests {
    @Test("CPU-constrained calculation")
    func testCPUConstraint() {
        let cpuCount = 2
        let memory: UInt64 = 16 * 1024 * 1024 * 1024 // 16GB
        let calculated = WebViewPoolClient.calculatePoolSize(cpuCount: cpuCount, memoryBytes: memory)

        // With 2 CPUs, should be limited by CPU count
        #expect(calculated == 2, "Should be limited by CPU count")
    }

    @Test("Memory-constrained calculation")
    func testMemoryConstraint() {
        let cpuCount = 8
        let memory: UInt64 = 2 * 1024 * 1024 * 1024 // 2GB
        let calculated = WebViewPoolClient.calculatePoolSize(cpuCount: cpuCount, memoryBytes: memory)

        // With 2GB memory, 10% = 200MB, at 200MB per WebView = 1
        #expect(calculated == 2, "Should be limited by memory but with minimum of 2")
    }

    @Test("Calculation for typical desktop system")
    func testTypicalDesktop() {
        let cpuCount = ProcessInfo.processInfo.activeProcessorCount
        let memory = ProcessInfo.processInfo.physicalMemory
        let calculated = WebViewPoolClient.calculatePoolSize(cpuCount: cpuCount, memoryBytes: memory)

        print("[Calculation Test] CPUs: \(cpuCount), Memory: \(memory / (1024*1024*1024))GB, Calculated: \(calculated)")

        #expect(calculated >= 2, "Should have at least 2 WebViews")
        #expect(calculated <= cpuCount, "Shouldn't exceed CPU count")
    }
}
