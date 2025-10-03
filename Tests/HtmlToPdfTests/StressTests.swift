//
//  StressTests.swift
//  swift-html-to-pdf
//
//  Extreme stress tests for resource pool under heavy load
//

import Testing
import Foundation
import Dependencies
import PDFTestSupport
import Metrics
@testable import HtmlToPdf

extension Tag {
    @Tag static var stress: Self
}

@Suite(
    "Stress Tests",
    .dependency(\.pdf, .liveValue),
    .serialized,
    .tags(.stress),
    .disabled()
)
struct StressTests {
    
    @Dependency(\.pdf) var pdf
    
    // MARK: - Extreme Load Tests
    
    @Test(
        "Generate 1,000,000 PDFs",
        .timeLimit(.minutes(120)),
        .dependencies {
            $0.pdf.render.configuration.concurrency = 8
            $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(600)
        }
        //        .disabled { false }
    )
    func test1MPDFs() async throws {
        let metricsBackend = TestMetricsBackend.forTest()
        try await withTemporaryDirectory { output in
            // Suppress WebKit console warnings
            setenv("OS_ACTIVITY_MODE", "disable", 1)
            
            let count = 1_000_000
            let filesPerDirectory = 1_000 // Keep directories manageable
            
            let startTime = Date()
            
            // Setup live metrics display
            let metricsTracker = MetricsProgressTracker(
                totalCount: count,
                metricsBackend: metricsBackend,
                reportInterval: .seconds(10)
            )
            await metricsTracker.start()
            
            // Create subdirectories to avoid file system degradation
            // 1M files split into 1000 directories of 1000 files each
            let numDirectories = (count + filesPerDirectory - 1) / filesPerDirectory
            for dirIndex in 0..<numDirectories {
                let subdirUrl = output.appendingPathComponent("batch-\(dirIndex)")
                try FileManager.default.createDirectory(at: subdirUrl, withIntermediateDirectories: true)
            }
            
            // Create minimal HTML documents with subdirectory paths
            let documents = (1...count).map { i in
                let dirIndex = (i - 1) / filesPerDirectory
                let subdirUrl = output.appendingPathComponent("batch-\(dirIndex)")
                return PDF.Document(
                    htmlString: "<html><body><p>\(i)</p></body></html>",
                    title: "doc-\(i)",
                    in: subdirUrl
                )
            }
            
            @Dependency(\.pdf) var pdf
            let poolSize = pdf.render.configuration.concurrency.resolved
            
            print("\n╔═══════════════════════════════════════════════════════════╗")
            print("║           1 MILLION PDF GENERATION TEST                  ║")
            print("╚═══════════════════════════════════════════════════════════╝")
            print("Total documents: \(count.formatted())")
            print("Subdirectories:  \(numDirectories) (\(filesPerDirectory) files each)")
            print("Pool size: \(poolSize) WebViews")
            print("Starting generation...\n")
            
            let stream = try await pdf.render.client.documents(documents)
            
            for try await _ in stream {
                // Metrics automatically recorded, live display updates
            }
            
            await metricsTracker.stop()
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Verify all files were created by counting across all subdirectories
            var totalFiles = 0
            let subdirs = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            for subdir in subdirs where subdir.hasDirectoryPath {
                let files = try FileManager.default.contentsOfDirectory(at: subdir, includingPropertiesForKeys: nil)
                totalFiles += files.count
            }
            #expect(totalFiles == count, "Should create all \(count) PDFs")
            
            // Get stats from metrics instead of manual calculation
            let throughput = metricsBackend.gauge("htmltopdf_throughput_pdfs_per_sec")?.value ?? (Double(count) / duration)
            let timer = metricsBackend.timer("htmltopdf_render_duration_seconds")
            let avgMs = (timer?.average ?? 0) * 1000
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            
            // Print final statistics with metrics summary
            await metricsTracker.printSummary()
            
            print("\n╔═══════════════════════════════════════════════════════════╗")
            print("║         1 MILLION PDF TEST - RESULTS                     ║")
            print("╚═══════════════════════════════════════════════════════════╝")
            print("Total PDFs:      \(count.formatted())")
            print("Duration:        \(minutes)m \(seconds)s (\(String(format: "%.2f", duration))s)")
            print("Throughput:      \(String(format: "%.0f", throughput)) PDFs/sec")
            print("Avg per PDF:     \(String(format: "%.3f", avgMs))ms")
            print("p95 per PDF:     \(String(format: "%.3f", (timer?.p95 ?? 0) * 1000))ms")
            print("Files created:   \(totalFiles.formatted())")
            print("Subdirectories:  \(subdirs.count)")
            print("╚═══════════════════════════════════════════════════════════╝\n")
            
            // Verify reasonable throughput (at least 100 PDFs/sec)
            #expect(throughput > 100, "Should maintain reasonable throughput")
        }
        
    }
    
    @Test("Generate 200,000 PDFs", .timeLimit(.minutes(30)))
    func test100kPDFs() async throws {
        try await withDependencies {
            // Using .automatic now defaults to 3x CPU count (24 on 8-core Mac)
            $0.pdf.render.configuration.concurrency = .automatic
            $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(300)
            // Enable adaptive throughput optimization
            $0.pdf.render.configuration.adaptiveThroughputOptimization = true
        } operation: {
            try await withTemporaryDirectory { output in
                // Suppress WebKit console warnings
                setenv("OS_ACTIVITY_MODE", "disable", 1)
                
                let count = 200_000
                let filesPerDirectory = 1_000 // Keep directories manageable
                
                let tracker = ProgressTracker(totalCount: count, reportInterval: 5.0)
                let startTime = Date()
                
                // Create subdirectories to avoid file system degradation
                let numDirectories = (count + filesPerDirectory - 1) / filesPerDirectory
                for dirIndex in 0..<numDirectories {
                    let subdirUrl = output.appendingPathComponent("batch-\(dirIndex)")
                    try FileManager.default.createDirectory(at: subdirUrl, withIntermediateDirectories: true)
                }
                
                // Create minimal HTML documents with subdirectory paths
                let documents = (1...count).map { i in
                    let dirIndex = (i - 1) / filesPerDirectory
                    let subdirUrl = output.appendingPathComponent("batch-\(dirIndex)")
                    return PDF.Document(
                        htmlString: "<html><body><p>\(i)</p></body></html>",
                        title: "doc-\(i)",
                        in: subdirUrl
                    )
                }
                
                @Dependency(\.pdf) var pdf
                let poolSize = pdf.render.configuration.concurrency.resolved
                
                print("\n╔═══════════════════════════════════════════════════════════╗")
                print("║           100K PDF GENERATION TEST                       ║")
                print("╚═══════════════════════════════════════════════════════════╝")
                print("Total documents: \(count.formatted())")
                print("Subdirectories:  \(numDirectories) (\(filesPerDirectory) files each)")
                print("Pool size: \(poolSize) WebViews")
                print("Adaptive optimization: ENABLED")
                print("Starting generation...\n")
                
                let stream = try await pdf.render.client.documents(documents)
                
                for try await _ in stream {
                    _ = await tracker.recordCompletion()
                }
                
                let duration = Date().timeIntervalSince(startTime)
                _ = await tracker.completed
                
                // Verify all files were created by counting across all subdirectories
                var totalFiles = 0
                let subdirs = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
                for subdir in subdirs where subdir.hasDirectoryPath {
                    let files = try FileManager.default.contentsOfDirectory(at: subdir, includingPropertiesForKeys: nil)
                    totalFiles += files.count
                }
                #expect(totalFiles == count, "Should create all \(count) PDFs")
                
                // Calculate stats
                let throughput = Double(count) / duration
                let avgMs = duration * 1000 / Double(count)
                let minutes = Int(duration / 60)
                let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
                
                // Print final statistics
                print("\n╔═══════════════════════════════════════════════════════════╗")
                print("║         100K PDF TEST - RESULTS                          ║")
                print("╚═══════════════════════════════════════════════════════════╝")
                print("Total PDFs:      \(count.formatted())")
                print("Duration:        \(minutes)m \(seconds)s (\(String(format: "%.2f", duration))s)")
                print("Throughput:      \(String(format: "%.0f", throughput)) PDFs/sec")
                print("Avg per PDF:     \(String(format: "%.3f", avgMs))ms")
                print("Files created:   \(totalFiles.formatted())")
                print("Subdirectories:  \(subdirs.count)")
                print("╚═══════════════════════════════════════════════════════════╝\n")
                
                // Verify reasonable throughput (at least 100 PDFs/sec)
                #expect(throughput > 100, "Should maintain reasonable throughput")
            }
        }
    }
    
    @Test("Generate 1,000 PDFs with complex HTML", .timeLimit(.minutes(5)))
    func test1kComplexPDFs() async throws {
        try await withDependencies {
            $0.pdf.render.configuration.concurrency = 6
            $0.pdf.render.configuration.webViewAcquisitionTimeout = .seconds(120)
        } operation: {
            try await withTemporaryDirectory { output in
                let count = 1_000
                
                let startTime = Date()
                
                // More complex HTML to stress rendering
                let complexHTML = """
                <html>
                <head>
                    <style>
                        body { font-family: Arial, sans-serif; padding: 20px; }
                        h1 { color: #333; }
                        .section { margin: 20px 0; padding: 10px; border: 1px solid #ddd; }
                        table { width: 100%; border-collapse: collapse; }
                        td, th { border: 1px solid #ddd; padding: 8px; }
                    </style>
                </head>
                <body>
                    <h1>Document {{ID}}</h1>
                    <div class="section">
                        <h2>Summary</h2>
                        <p>This is a more complex document with styling and structure.</p>
                    </div>
                    <div class="section">
                        <h2>Data Table</h2>
                        <table>
                            <tr><th>Column 1</th><th>Column 2</th><th>Column 3</th></tr>
                            <tr><td>Data 1</td><td>Data 2</td><td>Data 3</td></tr>
                            <tr><td>Data 4</td><td>Data 5</td><td>Data 6</td></tr>
                        </table>
                    </div>
                </body>
                </html>
                """
                
                let htmls = (1...count).map { i in
                    complexHTML.replacingOccurrences(of: "{{ID}}", with: "\(i)")
                }
                
                print("Starting 1k complex PDF generation test...")
                
                var urls: [URL] = []
                for try await result in try await pdf.render.client.html(htmls, to: output) {
                    urls.append(result.url)
                }
                
                let duration = Date().timeIntervalSince(startTime)
                
                let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
                #expect(files.count == count, "Should create all \(count) PDFs")
                
                print("\n✅ 1k Complex PDF Stress Test Complete!")
                print("Duration: \(String(format: "%.2f", duration))s")
                print("Throughput: \(String(format: "%.0f", Double(count) / duration)) PDFs/sec")
                
                // Verify some PDFs have reasonable size (not empty)
                let sampleFile = files[0]
                let fileSize = try FileManager.default.attributesOfItem(atPath: sampleFile.path)[.size] as? Int ?? 0
                #expect(fileSize > 5000, "Complex PDFs should have substantial content")
            }
        }
    }
    
    @Test("Sustained load test - 5 minutes continuous generation")
    func testSustainedLoad() async throws {
        try await withTemporaryDirectory { output in
            let duration: TimeInterval = 300 // 5 minutes
            
            actor Counter {
                var count = 0
                func increment() -> Int {
                    count += 1
                    return count
                }
                func get() -> Int { count }
            }
            
            let counter = Counter()
            let startTime = Date()
            
            print("Starting sustained load test (5 minutes)...")
            
            // Generate PDFs continuously for 5 minutes
            await withTaskGroup(of: Void.self) { group in
                // Launch multiple concurrent generators
                for batch in 1...10 {
                    let testDuration = duration
                    let start = startTime
                    let outputDir = output
                    group.addTask { @Sendable in
                        while Date().timeIntervalSince(start) < testDuration {
                            do {
                                let count = await counter.increment()
                                let html = "<html><body><p>PDF \(count)</p></body></html>"
                                let destination = outputDir.appendingPathComponent("sustained-\(count).pdf")
                                
                                _ = try await pdf.render.client.html(html, to: destination)
                                
                                // Brief pause to simulate realistic workload
                                try? await Task.sleep(for: .milliseconds(100))
                            } catch {
                                print("Error in batch \(batch): \(error)")
                            }
                        }
                    }
                }
                
                await group.waitForAll()
            }
            
            let totalDuration = Date().timeIntervalSince(startTime)
            let totalGenerated = await counter.get()
            
            let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            
            print("\n✅ Sustained Load Test Complete!")
            print("Duration: \(String(format: "%.2f", totalDuration))s")
            print("PDFs generated: \(totalGenerated)")
            print("Average rate: \(String(format: "%.1f", Double(totalGenerated) / totalDuration)) PDFs/sec")
            print("Files created: \(files.count)")
            
            #expect(totalGenerated > 100, "Should generate substantial number of PDFs")
            #expect(files.count == totalGenerated, "All PDFs should be created")
        }
    }
}
