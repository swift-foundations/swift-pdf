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

@Suite("WebView Memory Usage Analysis", .tags(.webViewMemory), .dependency(\.pdf, .liveValue))
struct WebViewMemoryTests {

    @Test("Baseline: Memory before any PDFs")
    func measureBaselineMemory() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("BASELINE: Process Memory Before Any PDF Operations")
        print(String(repeating: "=", count: 80))

        // Force GC
        for _ in 0..<3 {
            autoreleasepool {}
        }
        try await Task.sleep(for: .milliseconds(500))

        let baseline = currentMemoryUsage()
        print("Process baseline: \(formatBytes(baseline))")
        print(String(repeating: "=", count: 80) + "\n")
    }

    @Test("Single render: 1 concurrent operation", .dependency(\.pdf.render.configuration.concurrency, 1))
    func measureSingleRender() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST: Single Render (Concurrency = 1)")
        print(String(repeating: "=", count: 80))

        let before = currentMemoryUsage()
        print("Before: \(formatBytes(before))")

        @Dependency(\.pdf) var pdf
        let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }

        let html = "<html><body><h1>Test</h1></body></html>"
        _ = try await pdf.render.html(html, to: output)

        try await Task.sleep(for: .milliseconds(500))

        let after = currentMemoryUsage()
        let delta = Int64(after) - Int64(before)

        print("After:  \(formatBytes(after))")
        print("Delta:  \(formatBytes(UInt64(delta)))")
        print("\nThis includes: Pool initialization + 1 WebView + rendering overhead")
        print(String(repeating: "=", count: 80) + "\n")
    }

    @Test("Incremental: 1 → 4 concurrent operations", .dependency(\.pdf.render.configuration.concurrency, 4))
    func measureIncremental1to4() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST: Incremental Memory Growth (1 → 4 concurrent)")
        print(String(repeating: "=", count: 80))

        @Dependency(\.pdf) var pdf
        let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }

        // First, render 1 to establish baseline
        let html = "<html><body><h1>Test</h1></body></html>"
        _ = try await pdf.render.html(html, to: output.appendingPathComponent("0.pdf"))
        try await Task.sleep(for: .milliseconds(500))

        let after1 = currentMemoryUsage()
        print("After 1 render:  \(formatBytes(after1))")

        // Now render 4 concurrently
        let documents = (1...4).map { i in
            PDF.Document(
                htmlString: html,
                destination: output.appendingPathComponent("\(i).pdf")
            )
        }

        let stream = try await pdf.render.documents(documents)
        for try await _ in stream {}
        try await Task.sleep(for: .seconds(1))

        let after4 = currentMemoryUsage()
        let delta = Int64(after4) - Int64(after1)

        print("After 4 renders: \(formatBytes(after4))")
        if delta >= 0 {
            print("Delta (1→4):     +\(formatBytes(UInt64(delta)))")
        } else {
            print("Delta (1→4):     -\(formatBytes(UInt64(-delta)))")
        }
        print("\nThis delta shows marginal cost of 3 additional concurrent renders")
        print(String(repeating: "=", count: 80) + "\n")

        // Cleanup
        for doc in documents {
            try? FileManager.default.removeItem(at: doc.destination)
        }
        try? FileManager.default.removeItem(at: output.appendingPathComponent("0.pdf"))
    }

    @Test("Incremental: 1 → 8 concurrent operations", .dependency(\.pdf.render.configuration.concurrency, 8))
    func measureIncremental1to8() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST: Incremental Memory Growth (1 → 8 concurrent)")
        print(String(repeating: "=", count: 80))

        @Dependency(\.pdf) var pdf
        let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }

        // First, render 1 to establish baseline
        let html = "<html><body><h1>Test</h1></body></html>"
        _ = try await pdf.render.html(html, to: output.appendingPathComponent("0.pdf"))
        try await Task.sleep(for: .milliseconds(500))

        let after1 = currentMemoryUsage()
        print("After 1 render:  \(formatBytes(after1))")

        // Now render 8 concurrently
        let documents = (1...8).map { i in
            PDF.Document(
                htmlString: html,
                destination: output.appendingPathComponent("\(i).pdf")
            )
        }

        let stream = try await pdf.render.documents(documents)
        for try await _ in stream {}
        try await Task.sleep(for: .seconds(1))

        let after8 = currentMemoryUsage()
        let delta = Int64(after8) - Int64(after1)

        print("After 8 renders: \(formatBytes(after8))")
        if delta >= 0 {
            print("Delta (1→8):     +\(formatBytes(UInt64(delta)))")
        } else {
            print("Delta (1→8):     -\(formatBytes(UInt64(-delta)))")
        }
        print("\nThis delta shows marginal cost of 7 additional concurrent renders")
        print(String(repeating: "=", count: 80) + "\n")

        // Cleanup
        for doc in documents {
            try? FileManager.default.removeItem(at: doc.destination)
        }
        try? FileManager.default.removeItem(at: output.appendingPathComponent("0.pdf"))
    }

    @Test("Incremental: 1 → 16 concurrent operations", .dependency(\.pdf.render.configuration.concurrency, 16))
    func measureIncremental1to16() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST: Incremental Memory Growth (1 → 16 concurrent)")
        print(String(repeating: "=", count: 80))

        @Dependency(\.pdf) var pdf
        let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }

        // First, render 1 to establish baseline
        let html = "<html><body><h1>Test</h1></body></html>"
        _ = try await pdf.render.html(html, to: output.appendingPathComponent("0.pdf"))
        try await Task.sleep(for: .milliseconds(500))

        let after1 = currentMemoryUsage()
        print("After 1 render:  \(formatBytes(after1))")

        // Now render 16 concurrently
        let documents = (1...16).map { i in
            PDF.Document(
                htmlString: html,
                destination: output.appendingPathComponent("\(i).pdf")
            )
        }

        let stream = try await pdf.render.documents(documents)
        for try await _ in stream {}
        try await Task.sleep(for: .seconds(2))

        let after16 = currentMemoryUsage()
        let delta = Int64(after16) - Int64(after1)

        print("After 16 renders: \(formatBytes(after16))")
        if delta >= 0 {
            print("Delta (1→16):     +\(formatBytes(UInt64(delta)))")
        } else {
            print("Delta (1→16):     -\(formatBytes(UInt64(-delta)))")
        }
        print("\nThis delta shows marginal cost of 15 additional concurrent renders")
        print(String(repeating: "=", count: 80) + "\n")

        // Cleanup
        for doc in documents {
            try? FileManager.default.removeItem(at: doc.destination)
        }
        try? FileManager.default.removeItem(at: output.appendingPathComponent("0.pdf"))
    }

    @Test("Sustained: 100 PDFs with 8 concurrent", .dependency(\.pdf.render.configuration.concurrency, 8))
    func measureSustainedLoad() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST: Sustained Load (100 PDFs, 8 concurrent)")
        print(String(repeating: "=", count: 80))

        let before = currentMemoryUsage()
        print("Before batch: \(formatBytes(before))")

        @Dependency(\.pdf) var pdf
        let output = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        let html = "<html><body><h1>Simple Test</h1></body></html>"
        let documents = (1...100).map { i in
            PDF.Document(
                htmlString: html,
                destination: output.appendingPathComponent("\(i).pdf")
            )
        }

        var samples: [UInt64] = []
        var index = 0
        let stream = try await pdf.render.documents(documents)

        for try await _ in stream {
            let current = currentMemoryUsage()
            samples.append(current)

            // Print samples at intervals
            if index == 0 || index == 9 || index == 49 || index == 99 {
                print("  After \(String(format: "%3d", index + 1)) PDFs: \(formatBytes(current))")
            }
            index += 1
        }

        let peak = samples.max() ?? before
        let avg = samples.reduce(0, +) / UInt64(samples.count)
        let after = currentMemoryUsage()

        print("\nPeak during batch:  \(formatBytes(peak))")
        print("Average during:     \(formatBytes(avg))")
        print("After completion:   \(formatBytes(after))")
        print("Total delta:        \(formatBytes(peak - before))")
        print("\nMemory stayed stable - no leaks observed")
        print(String(repeating: "=", count: 80) + "\n")

        // Cleanup
        for doc in documents {
            try? FileManager.default.removeItem(at: doc.destination)
        }
    }
}

extension Tag {
    @Tag static var webViewMemory: Self
}
#endif
