//
//  WebViewMemoryTests.swift
//  swift-html-to-pdf
//
//  Tests to empirically measure WebView memory usage
//

import Testing
import Foundation
import HtmlToPdfLive
import Dependencies

#if os(macOS)
import Darwin.Mach

/// Measure current process memory footprint
func currentMemoryUsage() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)

    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }

    guard result == KERN_SUCCESS else {
        return 0
    }

    // phys_footprint is the most accurate measure of actual memory used
    return info.phys_footprint
}

func formatBytes(_ bytes: UInt64) -> String {
    let mb = Double(bytes) / (1024.0 * 1024.0)
    return String(format: "%.1f MB", mb)
}

func formatBytesSigned(_ bytes: Int64) -> String {
    let mb = Double(bytes) / (1024.0 * 1024.0)
    let sign = bytes >= 0 ? "+" : ""
    return String(format: "\(sign)%.1f MB", mb)
}

@Suite(
    "WebView Memory Usage Analysis",
    .tags(.webViewMemory)
)
struct WebViewMemoryTests {

    @Test("Baseline: Process memory before any operations")
    func measureBaselineMemory() async throws {
        // Force GC
        for _ in 0..<3 {
            autoreleasepool {}
        }
        try await Task.sleep(for: .milliseconds(500))

        let baseline = currentMemoryUsage()
        print("\n╔════════════════════════════════════════════════════════════════╗")
        print("║  BASELINE: Process Memory Before Any PDF Operations           ║")
        print("╚════════════════════════════════════════════════════════════════╝")
        print("Process baseline: \(formatBytes(baseline))\n")
    }

    @Test("Steady-state memory by concurrency level")
    func measureSteadyStateMemory() async throws {
        print("\n╔════════════════════════════════════════════════════════════════╗")
        print("║  STEADY-STATE MEMORY USAGE BY CONCURRENCY LEVEL                ║")
        print("╚════════════════════════════════════════════════════════════════╝")
        print("Methodology:")
        print("  1. Initialize pool at concurrency level N")
        print("  2. Render 50 PDFs to reach steady state")
        print("  3. Sample memory 10 times during next 50 PDFs")
        print("  4. Report min/avg/max/final memory usage")
        print("")

        let levels = [1, 4, 8, 16, 24]

        for concurrency in levels {
            try await withDependencies {
                $0.pdf.render.configuration.concurrency = .fixed(concurrency)
            } operation: {
                @Dependency(\.pdf) var pdf
                let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: output) }

                let html = "<html><body><h1>Memory Test</h1><p>Concurrency: \(concurrency)</p></body></html>"

                // Phase 1: Warm-up (50 PDFs to reach steady state)
                let warmupDocs = (0..<50).map { i in
                    PDF.Document(
                        htmlString: html,
                        destination: output.appendingPathComponent("warmup_\(i).pdf")
                    )
                }

                for try await _ in try await pdf.render.client.documents(warmupDocs) {}
                try await Task.sleep(for: .milliseconds(500))

                // Phase 2: Measure during sustained rendering (50 PDFs)
                let measureDocs = (0..<50).map { i in
                    PDF.Document(
                        htmlString: html,
                        destination: output.appendingPathComponent("measure_\(i).pdf")
                    )
                }

                var samples: [UInt64] = []
                var count = 0

                for try await _ in try await pdf.render.client.documents(measureDocs) {
                    // Sample every 5 PDFs
                    if count % 5 == 0 {
                        samples.append(currentMemoryUsage())
                    }
                    count += 1
                }

                try await Task.sleep(for: .milliseconds(500))
                let final = currentMemoryUsage()
                samples.append(final)

                let min = samples.min() ?? 0
                let max = samples.max() ?? 0
                let avg = samples.reduce(0, +) / UInt64(samples.count)

                print("Concurrency \(String(format: "%2d", concurrency)):  "
                    + "Min: \(formatBytes(min))  "
                    + "Avg: \(formatBytes(avg))  "
                    + "Max: \(formatBytes(max))  "
                    + "Final: \(formatBytes(final))")

                // Cleanup
                for doc in warmupDocs + measureDocs {
                    try? FileManager.default.removeItem(at: doc.destination)
                }
            }
        }
        print("")
    }

    @Test("Peak memory during concurrent burst")
    func measurePeakConcurrentMemory() async throws {
        print("\n╔════════════════════════════════════════════════════════════════╗")
        print("║  PEAK MEMORY DURING CONCURRENT BURST                           ║")
        print("╚════════════════════════════════════════════════════════════════╝")
        print("Methodology:")
        print("  1. Warm up pool with 20 PDFs")
        print("  2. Launch N concurrent renders simultaneously")
        print("  3. Sample memory rapidly during burst")
        print("  4. Report peak memory usage")
        print("")

        let levels = [1, 4, 8, 16, 24]

        for concurrency in levels {
            try await withDependencies {
                $0.pdf.render.configuration.concurrency = .fixed(concurrency)
            } operation: {
                @Dependency(\.pdf) var pdf
                let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: output) }

                let html = "<html><body><h1>Peak Test</h1></body></html>"

                // Warm-up
                let warmupDocs = (0..<20).map { i in
                    PDF.Document(
                        htmlString: html,
                        destination: output.appendingPathComponent("warmup_\(i).pdf")
                    )
                }
                for try await _ in try await pdf.render.client.documents(warmupDocs) {}
                try await Task.sleep(for: .milliseconds(500))

                let beforeBurst = currentMemoryUsage()

                // Burst: Launch concurrency * 2 PDFs to ensure pool saturation
                let burstSize = concurrency * 2
                let burstDocs = (0..<burstSize).map { i in
                    PDF.Document(
                        htmlString: html,
                        destination: output.appendingPathComponent("burst_\(i).pdf")
                    )
                }

                var peakSamples: [UInt64] = [beforeBurst]
                var count = 0

                for try await _ in try await pdf.render.client.documents(burstDocs) {
                    peakSamples.append(currentMemoryUsage())
                    count += 1
                }

                try await Task.sleep(for: .milliseconds(500))
                let afterBurst = currentMemoryUsage()
                peakSamples.append(afterBurst)

                let peak = peakSamples.max() ?? beforeBurst
                let delta = Int64(peak) - Int64(beforeBurst)

                print("Concurrency \(String(format: "%2d", concurrency)):  "
                    + "Before: \(formatBytes(beforeBurst))  "
                    + "Peak: \(formatBytes(peak))  "
                    + "Delta: \(formatBytesSigned(delta))  "
                    + "After: \(formatBytes(afterBurst))")

                // Cleanup
                for doc in warmupDocs + burstDocs {
                    try? FileManager.default.removeItem(at: doc.destination)
                }
            }
        }
        print("")
    }

    @Test("Memory stability over extended batch")
    func measureMemoryStability() async throws {
        print("\n╔════════════════════════════════════════════════════════════════╗")
        print("║  MEMORY STABILITY: 500 PDFs with 8 concurrent                  ║")
        print("╚════════════════════════════════════════════════════════════════╝")
        print("Measuring memory at regular intervals to verify no leaks\n")

        try await withDependencies {
            $0.pdf.render.configuration.concurrency = .fixed(8)
        } operation: {
            @Dependency(\.pdf) var pdf
            let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: output) }

            let html = "<html><body><h1>Stability Test</h1></body></html>"
            let documents = (0..<500).map { i in
                PDF.Document(
                    htmlString: html,
                    destination: output.appendingPathComponent("\(i).pdf")
                )
            }

            var samples: [(index: Int, memory: UInt64)] = []
            var count = 0
            let sampleInterval = 50

            let start = currentMemoryUsage()
            print("Start:        \(formatBytes(start))")

            for try await _ in try await pdf.render.client.documents(documents) {
                if count % sampleInterval == 0 {
                    let memory = currentMemoryUsage()
                    samples.append((count, memory))
                    print("After \(String(format: "%3d", count)) PDFs: \(formatBytes(memory))")
                }
                count += 1
            }

            try await Task.sleep(for: .milliseconds(500))
            let final = currentMemoryUsage()
            samples.append((count, final))
            print("Final:        \(formatBytes(final))")

            // Analyze trend
            let allMemory = samples.map { $0.memory }
            let min = allMemory.min() ?? start
            let max = allMemory.max() ?? start
            let avg = allMemory.reduce(0, +) / UInt64(allMemory.count)
            let range = max - min

            print("\nStatistics:")
            print("  Min:       \(formatBytes(min))")
            print("  Max:       \(formatBytes(max))")
            print("  Avg:       \(formatBytes(avg))")
            print("  Range:     \(formatBytes(range))")
            print("  Stability: \(range < (avg / 2) ? "✓ Stable (range < 50% avg)" : "⚠ Variable")")
            print("")

            // Cleanup
            for doc in documents {
                try? FileManager.default.removeItem(at: doc.destination)
            }
        }
    }

    @Test("Pool initialization overhead")
    func measurePoolInitializationOverhead() async throws {
        print("\n╔════════════════════════════════════════════════════════════════╗")
        print("║  POOL INITIALIZATION OVERHEAD BY CONCURRENCY                   ║")
        print("╚════════════════════════════════════════════════════════════════╝")
        print("Measuring memory before and after pool initialization\n")

        let levels = [1, 4, 8, 16, 24]

        for concurrency in levels {
            // Force GC
            for _ in 0..<3 {
                autoreleasepool {}
            }
            try await Task.sleep(for: .milliseconds(500))

            let beforeInit = currentMemoryUsage()

            try await withDependencies {
                $0.pdf.render.configuration.concurrency = .fixed(concurrency)
            } operation: {
                @Dependency(\.pdf) var pdf
                let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: output) }

                let html = "<html><body><h1>Init Test</h1></body></html>"

                // Single render to initialize pool
                _ = try await pdf.render.html(html, to: output.appendingPathComponent("init.pdf"))

                try await Task.sleep(for: .milliseconds(500))
                let afterInit = currentMemoryUsage()
                let overhead = Int64(afterInit) - Int64(beforeInit)

                print("Concurrency \(String(format: "%2d", concurrency)):  "
                    + "Before: \(formatBytes(beforeInit))  "
                    + "After: \(formatBytes(afterInit))  "
                    + "Overhead: \(formatBytesSigned(overhead))")

                // Cleanup
                try? FileManager.default.removeItem(at: output.appendingPathComponent("init.pdf"))
            }
        }
        print("")
    }
}

extension Tag {
    @Tag static var webViewMemory: Self
}
#endif
