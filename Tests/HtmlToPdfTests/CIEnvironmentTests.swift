//
//  CIEnvironmentTests.swift
//  swift-html-to-pdf
//
//  Tests for CI environment simulation
//

import Testing
import Foundation
import WebKit
@testable import HtmlToPdf
import Dependencies
import DependenciesTestSupport
import EnvironmentVariables

@Suite("CI Environment Tests")
struct CIEnvironmentTests {

    @Test(
        "GitHub Actions environment simulation",
        .dependency(\.envVars, {
            var env = EnvironmentVariables.local
            env["CI"] = "true"
            env["GITHUB_ACTIONS"] = "true"
            env["RUNNER_OS"] = "macOS"
            env["RUNNER_ARCH"] = "X64"
            env["WEBVIEW_POOL_SIZE"] = "2"
            env["WEBVIEW_POOL_SILENT"] = "true"
            return env
        }())
    )
    func testGitHubActionsEnvironment() async throws {
        @Dependency(\.envVars) var envVars
        @Dependency(\.webViewPool) var pool

        // Verify CI environment is detected
        let config = WebViewPoolConfiguration(env: envVars)
        #expect(config.isCI == true, "Should detect CI environment")
        #expect(config.isGitHubActions == true, "Should detect GitHub Actions")
        #expect(config.poolSize == 2, "Should use CI pool size")

        // Verify pool initialization with CI constraints
        await pool.waitForFullInitialization()
        let stats = await pool.getStatistics()
        let poolSize = stats.available + stats.inUse
        #expect(poolSize == 2, "Pool should be limited to 2 in CI")

        // Test that CI pool can still handle concurrent operations
        var acquiredViews: [WKWebView] = []

        // Acquire both views
        for i in 1...2 {
            do {
                let view = try await pool.acquireWithRetry(1, 0.5)
                acquiredViews.append(view)
                print("[CI Test] Acquired view \(i)")
            } catch {
                Issue.record("Failed to acquire view in CI: \(error)")
            }
        }

        #expect(acquiredViews.count == 2, "Should acquire all CI pool views")

        // Release views
        for view in acquiredViews {
            await pool.releaseWebView(view)
        }

        // Verify pool is restored
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        let finalStats = await pool.getStatistics()
        #expect(finalStats.available == 2, "All CI pool views should be available")
    }

    @Test(
        "CI memory-constrained environment",
        .dependency(\.envVars, {
            var env = EnvironmentVariables.local
            env["CI"] = "true"
            env["WEBVIEW_POOL_SILENT"] = "true"
            // Don't set WEBVIEW_POOL_SIZE to test automatic CI detection
            return env
        }())
    )
    func testCIMemoryConstraints() async throws {
        @Dependency(\.webViewPool) var pool

        // Pool should automatically detect CI and use conservative size
        await pool.waitForFullInitialization()
        let stats = await pool.getStatistics()
        let poolSize = stats.available + stats.inUse

        // In CI mode without explicit size, should use calculated CI size (max 2)
        #expect(poolSize <= 2, "CI should use conservative pool size")
        #expect(poolSize >= 1, "CI should have at least 1 WebView")
    }

    @Test(
        "Local development environment",
        .dependency(\.envVars, {
            var env = EnvironmentVariables.local
            env["WEBVIEW_POOL_SILENT"] = "true"
            // Explicitly mark as NOT CI
            env["CI"] = "false"
            return env
        }())
    )
    func testLocalEnvironment() async throws {
        @Dependency(\.envVars) var envVars
        @Dependency(\.webViewPool) var pool

        let config = WebViewPoolConfiguration(env: envVars)
        #expect(config.isCI == false, "Should not detect CI environment")
        #expect(config.isGitHubActions == false, "Should not detect GitHub Actions")

        // Local environment should use normal pool size calculation
        await pool.waitForFullInitialization()
        let stats = await pool.getStatistics()
        let poolSize = stats.available + stats.inUse

        // Local development typically has more resources
        #expect(poolSize >= 2, "Local should have reasonable pool size")
    }

    @Test(
        "CI with large document batch",
        .dependency(\.envVars, {
            var env = EnvironmentVariables.local
            env["CI"] = "true"
            env["GITHUB_ACTIONS"] = "true"
            env["WEBVIEW_POOL_SIZE"] = "2"
            env["WEBVIEW_POOL_SILENT"] = "true"
            return env
        }())
    )
    func testCILargeBatch() async throws {
        @Dependency(\.webViewPool) var pool

        // Simulate processing many documents with limited CI pool
        let documentCount = 10
        var processedCount = 0

        await withTaskGroup(of: Bool.self) { group in
            for i in 1...documentCount {
                group.addTask { [pool] in
                    do {
                        // Try to acquire with short timeout (CI is resource-constrained)
                        let view = try await pool.acquireWithRetry(2, 0.5)

                        // Simulate PDF generation
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

                        await pool.releaseWebView(view)
                        print("[CI Batch] Processed document \(i)")
                        return true
                    } catch {
                        print("[CI Batch] Failed document \(i): \(error)")
                        return false
                    }
                }
            }

            for await success in group {
                if success {
                    processedCount += 1
                }
            }
        }

        // Even with limited pool, should process all documents
        #expect(processedCount == documentCount, "CI should handle all documents despite limited pool")
    }

    @Test(
        "Pool size calculation for various CI configurations",
        .dependency(\.envVars, EnvironmentVariables.local)
    )
    func testCIPoolSizeCalculations() {
        // Test various CI hardware configurations
        let configurations: [(name: String, cpus: Int, memory: UInt64, expected: Int)] = [
            ("GitHub Actions Standard", 2, 7 * 1024 * 1024 * 1024, 2),
            ("GitHub Actions Large", 4, 14 * 1024 * 1024 * 1024, 2),
            ("Minimal CI", 1, 2 * 1024 * 1024 * 1024, 1),
            ("High-end CI", 8, 32 * 1024 * 1024 * 1024, 2)
        ]

        for config in configurations {
            let poolSize = WebViewPoolClient.calculatePoolSize(
                cpuCount: config.cpus,
                memoryBytes: config.memory,
                isCI: true
            )

            #expect(
                poolSize == config.expected,
                "\(config.name): Expected \(config.expected), got \(poolSize)"
            )
        }

        // Compare with non-CI calculation
        let normalSize = WebViewPoolClient.calculatePoolSize(
            cpuCount: 8,
            memoryBytes: 32 * 1024 * 1024 * 1024,
            isCI: false
        )

        let ciSize = WebViewPoolClient.calculatePoolSize(
            cpuCount: 8,
            memoryBytes: 32 * 1024 * 1024 * 1024,
            isCI: true
        )

        #expect(ciSize < normalSize, "CI should use smaller pool than normal")
    }
}
