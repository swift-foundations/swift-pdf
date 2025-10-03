//
//  PerformanceBenchmarks.swift
//  swift-html-to-pdf
//
//  Performance benchmarks for README documentation
//

import Testing
import Foundation
import Dependencies
import PDFTestSupport
@testable import HtmlToPdf

extension Tag {
    @Tag static var benchmark: Self
}

/// Performance benchmarks for generating README statistics
///
/// Run with: swift test --filter tag:benchmark
///
/// These tests generate consistent performance metrics for documentation.
/// Run multiple times and report the median results.
@Suite("Performance Benchmarks", .dependency(\.pdf, .liveValue), .serialized, .tags(.benchmark))
struct PerformanceBenchmarks {
    @Dependency(\.pdf) var pdf
    // MARK: - Helper Types

    private actor PeakMemoryTracker {
        private var peak: MemorySnapshot?

        func update(_ current: MemorySnapshot) {
            if let existingPeak = peak {
                if current.residentMB > existingPeak.residentMB {
                    peak = current
                }
            } else {
                peak = current
            }
        }

        func getPeak() -> MemorySnapshot {
            peak ?? MemorySnapshot(residentMB: 0, virtualMB: 0)
        }
    }

    struct MemorySnapshot: Sendable {
        let residentMB: Double
        let virtualMB: Double

        static func current() -> MemorySnapshot {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(
                        mach_task_self_,
                        task_flavor_t(MACH_TASK_BASIC_INFO),
                        $0,
                        &count
                    )
                }
            }

            guard result == KERN_SUCCESS else {
                return MemorySnapshot(residentMB: 0, virtualMB: 0)
            }

            return MemorySnapshot(
                residentMB: Double(info.resident_size) / 1_048_576,
                virtualMB: Double(info.virtual_size) / 1_048_576
            )
        }
    }

    struct BenchmarkResult {
        let name: String
        let count: Int
        let mode: PDF.PaginationMode
        let concurrency: Int
        let duration: TimeInterval
        let throughput: Double
        let avgPerItem: TimeInterval
        let memoryBefore: MemorySnapshot
        let memoryAfter: MemorySnapshot
        let peakMemory: MemorySnapshot
        let minDuration: TimeInterval
        let maxDuration: TimeInterval
        let p50Duration: TimeInterval
        let p95Duration: TimeInterval
        let p99Duration: TimeInterval

        var throughputPerSec: String {
            String(format: "%.0f", throughput)
        }

        var avgPerItemMs: String {
            String(format: "%.2f", avgPerItem * 1000)
        }

        var memoryDeltaMB: Double {
            memoryAfter.residentMB - memoryBefore.residentMB
        }

        var memoryPerPDFKB: Double {
            (memoryDeltaMB * 1024) / Double(count)
        }

        func printMarkdownRow() {
            print("| \(name.padding(toLength: 25, withPad: " ", startingAt: 0)) | \(String(count).padding(toLength: 8, withPad: " ", startingAt: 0)) | \(String(format: "%.2f", duration).padding(toLength: 8, withPad: " ", startingAt: 0))s | \(throughputPerSec.padding(toLength: 12, withPad: " ", startingAt: 0)) | \(avgPerItemMs.padding(toLength: 10, withPad: " ", startingAt: 0))ms | \(String(format: "%.1f", peakMemory.residentMB).padding(toLength: 8, withPad: " ", startingAt: 0))MB |")
        }

        func printDetailedRow() {
            print("| \(name.padding(toLength: 25, withPad: " ", startingAt: 0)) | \(String(count).padding(toLength: 8, withPad: " ", startingAt: 0)) | \(String(format: "%.2f", duration).padding(toLength: 8, withPad: " ", startingAt: 0))s | \(throughputPerSec.padding(toLength: 12, withPad: " ", startingAt: 0)) | \(avgPerItemMs.padding(toLength: 8, withPad: " ", startingAt: 0))ms | \(String(format: "%.2f", p50Duration * 1000).padding(toLength: 8, withPad: " ", startingAt: 0))ms | \(String(format: "%.2f", p95Duration * 1000).padding(toLength: 8, withPad: " ", startingAt: 0))ms | \(String(format: "%.2f", p99Duration * 1000).padding(toLength: 8, withPad: " ", startingAt: 0))ms | \(String(format: "%.1f", peakMemory.residentMB).padding(toLength: 8, withPad: " ", startingAt: 0))MB |")
        }
    }

    // MARK: - Benchmarks

    @Test("Benchmark: 100 simple PDFs")
    func benchmark100SimplePDFs() async throws {
        let result = try await runBenchmark(
            name: "100 Simple PDFs",
            count: 100,
            html: "<html><body><p>{{ID}}</p></body></html>",
            maxConcurrent: 8
        )

        printBenchmarkResult(result)
    }

    @Test("Benchmark: 1,000 simple PDFs")
    func benchmark1kSimplePDFs() async throws {
        let result = try await runBenchmark(
            name: "1k Simple PDFs",
            count: 1_000,
            html: "<html><body><p>{{ID}}</p></body></html>",
            maxConcurrent: 8
        )

        printBenchmarkResult(result)
    }

    @Test("Benchmark: 10,000 simple PDFs")
    func benchmark10kSimplePDFs() async throws {
        let result = try await runBenchmark(
            name: "10k Simple PDFs",
            count: 10_000,
            html: "<html><body><p>{{ID}}</p></body></html>",
            maxConcurrent: 8
        )

        printBenchmarkResult(result)
    }

    @Test("Benchmark: 100 complex PDFs")
    func benchmark100ComplexPDFs() async throws {
        let result = try await runBenchmark(
            name: "100 Complex PDFs",
            count: 100,
            html: complexHTML,
            maxConcurrent: 6
        )

        printBenchmarkResult(result)
    }

    @Test("Benchmark: 1,000 complex PDFs")
    func benchmark1kComplexPDFs() async throws {
        let result = try await runBenchmark(
            name: "1k Complex PDFs",
            count: 1_000,
            html: complexHTML,
            maxConcurrent: 6
        )

        printBenchmarkResult(result)
    }

    @Test("Benchmark: Concurrent batches")
    func benchmarkConcurrentBatches() async throws {
        let output = URL.output()
        defer {
            try? FileManager.default.removeItem(at: output)
        }
        
        let startTime = Date()
        
        // Run 10 concurrent batches of 100 PDFs each
        await withTaskGroup(of: Void.self) { group in
            for batch in 1...10 {
                let outputDir = output
                group.addTask { @Sendable in
                    try? await withDependencies {
                        $0.pdf.render.configuration.namingStrategy = .init { i in "batch\(batch)-doc\(i)" }
                    } operation: {
                        @Dependency(\.pdf) var batchPdf
                        let htmls = (1...100).map { i in
                            "<html><body><p>Batch \(batch) - Doc \(i)</p></body></html>"
                        }
                        var urls: [URL] = []
                        for try await result in try await batchPdf.render.client.html(htmls, to: outputDir) {
                            urls.append(result.url)
                        }
                    }
                }
            }
            
            await group.waitForAll()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let count = 1_000
        let memBefore = MemorySnapshot.current()
        let memAfter = MemorySnapshot.current()
        
        let result = BenchmarkResult(
            name: "10 Concurrent Batches",
            count: count,
            mode: .continuous,
            concurrency: 10,
            duration: duration,
            throughput: Double(count) / duration,
            avgPerItem: duration / Double(count),
            memoryBefore: memBefore,
            memoryAfter: memAfter,
            peakMemory: memAfter,
            minDuration: 0,
            maxDuration: 0,
            p50Duration: 0,
            p95Duration: 0,
            p99Duration: 0
        )
        
        printBenchmarkResult(result)
        
        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        #expect(files.count == count)
        
    }

    @Test("Benchmark: Pool warmup time")
    func benchmarkPoolWarmup() async throws {
        
        
        // This measures the initial pool creation cost
        // Note: With background warmup, this should be very fast
        
        let startTime = Date()
        
        let html = "<html><body><p>Test</p></body></html>"
        let output = URL.output().appendingPathComponent("warmup.pdf")
        
        defer {
            try? FileManager.default.removeItem(at: output)
        }
        
        _ = try await pdf.render.client.html(html, to: output)
        
        let duration = Date().timeIntervalSince(startTime)
        
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Pool Warmup Benchmark")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("First PDF generation: \(String(format: "%.3f", duration))s")
        print("(Includes pool initialization + first PDF)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
    }

    // MARK: - Summary Report

    @Test("Generate README Performance Table", .timeLimit(.minutes(10)))
    func generateReadmeTable() async throws {
        print("\n")
        print("╔═══════════════════════════════════════════════════════════════════════════╗")
        print("║                     PERFORMANCE BENCHMARK RESULTS                         ║")
        print("║                    Copy this table to README.md                           ║")
        print("╚═══════════════════════════════════════════════════════════════════════════╝")
        print()

        let simpleHTML = "<html><body><p>{{ID}}</p></body></html>"

        // Run benchmarks for PAGINATED mode (print-ready)
        let paginatedResults = [
            try await runBenchmark(name: "100 Simple", count: 100, html: simpleHTML, maxConcurrent: 8, mode: .paginated),
            try await runBenchmark(name: "1,000 Simple", count: 1_000, html: simpleHTML, maxConcurrent: 8, mode: .paginated),
            try await runBenchmark(name: "10,000 Simple", count: 10_000, html: simpleHTML, maxConcurrent: 8, mode: .paginated),
            try await runBenchmark(name: "100 Complex", count: 100, html: complexHTML, maxConcurrent: 6, mode: .paginated),
            try await runBenchmark(name: "1,000 Complex", count: 1_000, html: complexHTML, maxConcurrent: 6, mode: .paginated),
        ]

        // Run benchmarks for CONTINUOUS mode (fast)
        let continuousResults = [
            try await runBenchmark(name: "100 Simple", count: 100, html: simpleHTML, maxConcurrent: 8, mode: .continuous),
            try await runBenchmark(name: "1,000 Simple", count: 1_000, html: simpleHTML, maxConcurrent: 8, mode: .continuous),
            try await runBenchmark(name: "10,000 Simple", count: 10_000, html: simpleHTML, maxConcurrent: 8, mode: .continuous),
        ]

        // Calculate dynamic comparisons
        let continuousAvg = continuousResults.map { $0.throughput }.reduce(0, +) / Double(continuousResults.count)
        let paginatedAvg = paginatedResults.map { $0.throughput }.reduce(0, +) / Double(paginatedResults.count)
        let speedupRatio = continuousAvg / paginatedAvg

        // Print markdown table for PAGINATED mode
        print("### Performance Results - Paginated Mode (Print-Ready)")
        print()
        print("Paginated mode uses NSPrintOperation for proper multi-page documents (invoices, reports).")
        print()
        print("| Test                      | Count    | Duration | Throughput   | Avg/PDF   | Peak Mem |")
        print("|---------------------------|----------|----------|--------------|-----------|----------|")

        for result in paginatedResults {
            result.printMarkdownRow()
        }

        print()

        // Print markdown table for CONTINUOUS mode
        print("### Performance Results - Continuous Mode (Fast)")
        print()
        print("Continuous mode uses WKWebView.createPDF for single-page documents (web captures, articles).")
        print()
        print("| Test                      | Count    | Duration | Throughput   | Avg/PDF   | Peak Mem |")
        print("|---------------------------|----------|----------|--------------|-----------|----------|")

        for result in continuousResults {
            result.printMarkdownRow()
        }

        print()

        // Detailed performance breakdown
        print("### Detailed Performance Metrics")
        print()
        print("| Test                      | Count    | Duration | Throughput   | Avg      | p50      | p95      | p99      | Peak Mem |")
        print("|---------------------------|----------|----------|--------------|----------|----------|----------|----------|----------|")

        for result in continuousResults + paginatedResults {
            result.printDetailedRow()
        }

        print()

        // System information
        let physicalMemoryGB = ProcessInfo.processInfo.physicalMemory / 1_073_741_824
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let cpuCount = ProcessInfo.processInfo.activeProcessorCount

        print("**Test Environment:**")
        print("- Platform: macOS \(osVersion)")
        print("- CPU Cores: \(cpuCount)")
        print("- Physical Memory: \(physicalMemoryGB) GB")
        print("- Swift Version: \(getSwiftVersion())")
        print()

        // Dynamic pool size information from actual benchmarks
        let poolSizes = Set(continuousResults.map { $0.concurrency } + paginatedResults.map { $0.concurrency })
        print("**Pool Configuration:**")
        for poolSize in poolSizes.sorted() {
            let tests = (continuousResults + paginatedResults).filter { $0.concurrency == poolSize }
            let testNames = tests.map { $0.name }.joined(separator: ", ")
            print("- \(poolSize) WebViews: \(testNames)")
        }
        print()

        // Dynamic performance comparison
        print("**Performance Comparison:**")
        print("- Continuous mode is \(String(format: "%.1f", speedupRatio))x faster than paginated mode (average)")
        print("- Best throughput (continuous): \(String(format: "%.0f", continuousResults.map { $0.throughput }.max() ?? 0)) PDFs/sec")
        print("- Best throughput (paginated): \(String(format: "%.0f", paginatedResults.map { $0.throughput }.max() ?? 0)) PDFs/sec")
        print()

        print("**Mode Selection Guide:**")
        print("- **Choose Continuous** for: Web captures, articles, infographics (single tall page)")
        print("- **Choose Paginated** for: Invoices, reports, documents for printing (proper page breaks)")
        print()

        // Memory analysis
        let avgMemoryPaginated = paginatedResults.map { $0.peakMemory.residentMB }.reduce(0, +) / Double(paginatedResults.count)
        let avgMemoryContinuous = continuousResults.map { $0.peakMemory.residentMB }.reduce(0, +) / Double(continuousResults.count)

        print("**Memory Profile:**")
        print("- Paginated mode peak: \(String(format: "%.1f", avgMemoryPaginated)) MB (average)")
        print("- Continuous mode peak: \(String(format: "%.1f", avgMemoryContinuous)) MB (average)")
        print()

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()
    }

    // MARK: - Helpers

    private func runBenchmark(
        name: String,
        count: Int,
        html: String,
        maxConcurrent: Int,
        mode: PDF.PaginationMode = .paginated
    ) async throws -> BenchmarkResult {
        try await withDependencies {
            $0.pdf.render.configuration.paginationMode = mode
            $0.pdf.render.configuration.concurrency = .fixed(maxConcurrent)
            $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(120)
        } operation: {
            let output = URL.output()

            defer {
                try? FileManager.default.removeItem(at: output)
            }

            let htmls = (1...count).map { i in
                html.replacingOccurrences(of: "{{ID}}", with: "\(i)")
            }

            let memoryBefore = MemorySnapshot.current()
            let peakMemoryActor = PeakMemoryTracker()
            var durations: [TimeInterval] = []

            // Track memory during execution
            let memoryTask = Task {
                while !Task.isCancelled {
                    let current = MemorySnapshot.current()
                    await peakMemoryActor.update(current)
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }

            let startTime = Date()

            // Render with per-PDF timing
            let stream = try await pdf.render.client.html(htmls, to: output)
            for try await result in stream {
                durations.append(Double(result.duration.components.seconds) +
                               Double(result.duration.components.attoseconds) / 1_000_000_000_000_000_000)
            }

            let totalDuration = Date().timeIntervalSince(startTime)
            memoryTask.cancel()

            let memoryAfter = MemorySnapshot.current()
            let peakMemory = await peakMemoryActor.getPeak()

            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            #expect(files.count == count, "All PDFs should be created")

            // Calculate percentiles
            let sortedDurations = durations.sorted()
            let p50Index = sortedDurations.count / 2
            let p95Index = sortedDurations.count * 95 / 100
            let p99Index = sortedDurations.count * 99 / 100

            return BenchmarkResult(
                name: name,
                count: count,
                mode: mode,
                concurrency: maxConcurrent,
                duration: totalDuration,
                throughput: Double(count) / totalDuration,
                avgPerItem: totalDuration / Double(count),
                memoryBefore: memoryBefore,
                memoryAfter: memoryAfter,
                peakMemory: peakMemory,
                minDuration: sortedDurations.first ?? 0,
                maxDuration: sortedDurations.last ?? 0,
                p50Duration: sortedDurations[p50Index],
                p95Duration: sortedDurations[p95Index],
                p99Duration: sortedDurations[p99Index]
            )
        }
    }

    private func printBenchmarkResult(_ result: BenchmarkResult) {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Benchmark: \(result.name)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("PDFs Generated:  \(result.count)")
        print("Duration:        \(String(format: "%.2f", result.duration))s")
        print("Throughput:      \(result.throughputPerSec) PDFs/sec")
        print("Avg per PDF:     \(result.avgPerItemMs)ms")
        print("p50/p95/p99:     \(String(format: "%.2f", result.p50Duration * 1000))ms / \(String(format: "%.2f", result.p95Duration * 1000))ms / \(String(format: "%.2f", result.p99Duration * 1000))ms")
        print("Peak Memory:     \(String(format: "%.1f", result.peakMemory.residentMB)) MB")
        print("Memory Delta:    \(String(format: "%.1f", result.memoryDeltaMB)) MB")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    private func getSwiftVersion() -> String {
        #if compiler(>=6.0)
        return "6.0+"
        #elseif compiler(>=5.9)
        return "5.9+"
        #else
        return "5.x"
        #endif
    }

    private var complexHTML: String {
        """
        <html>
        <head>
            <style>
                body { font-family: Arial, sans-serif; padding: 20px; }
                h1 { color: #333; border-bottom: 2px solid #0066cc; }
                .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
                table { width: 100%; border-collapse: collapse; margin-top: 10px; }
                td, th { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; font-weight: bold; }
            </style>
        </head>
        <body>
            <h1>Document {{ID}}</h1>
            <div class="section">
                <h2>Executive Summary</h2>
                <p>This is a complex document with multiple sections, styling, and structured data.</p>
            </div>
            <div class="section">
                <h2>Data Table</h2>
                <table>
                    <tr><th>Metric</th><th>Value</th><th>Status</th></tr>
                    <tr><td>Revenue</td><td>$1,234,567</td><td>✓ On track</td></tr>
                    <tr><td>Customers</td><td>45,678</td><td>✓ Growing</td></tr>
                    <tr><td>Retention</td><td>94.2%</td><td>✓ Excellent</td></tr>
                </table>
            </div>
            <div class="section">
                <h2>Analysis</h2>
                <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>
            </div>
        </body>
        </html>
        """
    }

    // MARK: - Adaptive Throughput Optimization

    @Test("Find optimal concurrency for maximum throughput", .timeLimit(.minutes(60)))
    func testAdaptiveThroughputOptimization() async throws {
        struct ConcurrencyResult: Sendable {
            let concurrency: Int
            let throughput: Double
            let duration: TimeInterval
            let avgMs: Double
        }

        let testCount = 5000  // Sample size for each concurrency level
        // Respect platform maximum (macOS: 16, iOS: 8)
        let concurrencyLevels = [4, 8, 12, 16]

        print("\n╔════════════════════════════════════════════════════════════╗")
        print("║     ADAPTIVE THROUGHPUT OPTIMIZATION TEST                 ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print("Sample size per test: \(testCount) PDFs")
        print("Testing concurrency levels: \(concurrencyLevels)")
        print("Starting optimization...\n")

        var results: [ConcurrencyResult] = []

        for concurrency in concurrencyLevels {
            try await withDependencies {
                $0.pdf.render.configuration.concurrency = .fixed(concurrency)
                $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(300)
            } operation: {
                try await withTemporaryDirectory { output in
                    setenv("OS_ACTIVITY_MODE", "disable", 1)

                    let documents = (1...testCount).map { i in
                        PDF.Document(
                            htmlString: "<html><body><p>\(i)</p></body></html>",
                            title: "doc-\(i)",
                            in: output
                        )
                    }

                    let startTime = Date()
                    let stream = try await pdf.render.client.documents(documents)

                    var count = 0
                    for try await _ in stream {
                        count += 1
                    }

                    let duration = Date().timeIntervalSince(startTime)
                    let throughput = Double(testCount) / duration
                    let avgMs = duration * 1000 / Double(testCount)

                    let result = ConcurrencyResult(
                        concurrency: concurrency,
                        throughput: throughput,
                        duration: duration,
                        avgMs: avgMs
                    )
                    results.append(result)

                    print("✓ Concurrency \(String(format: "%2d", concurrency)): \(String(format: "%5.0f", throughput)) PDFs/sec  (\(String(format: "%.2f", duration))s, \(String(format: "%.3f", avgMs))ms avg)")
                }
            }
        }

        // Find optimal concurrency
        let optimal = results.max(by: { $0.throughput < $1.throughput })!

        print("\n╔════════════════════════════════════════════════════════════╗")
        print("║                   OPTIMIZATION RESULTS                     ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print("Optimal concurrency: \(optimal.concurrency) WebViews")
        print("Peak throughput:     \(String(format: "%.0f", optimal.throughput)) PDFs/sec")
        print("Avg per PDF:         \(String(format: "%.3f", optimal.avgMs))ms")
        print("\nAll results (sorted by throughput):")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        for result in results.sorted(by: { $0.throughput > $1.throughput }) {
            let marker = result.concurrency == optimal.concurrency ? "🏆" : "  "
            print("\(marker) \(String(format: "%2d", result.concurrency)) WebViews: \(String(format: "%5.0f", result.throughput)) PDFs/sec")
        }
        print("╚════════════════════════════════════════════════════════════╝\n")
    }
}
