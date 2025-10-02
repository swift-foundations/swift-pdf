//
//  TestOutput.swift
//  PDFTestSupport
//
//  Automatic cleanup for PDF test files with parallel test execution support
//

import Foundation

/// Provides a temporary directory for test output with automatic cleanup
///
/// Creates a unique temporary directory, executes the closure with that directory,
/// and automatically removes it when done. Safe for parallel test execution.
///
/// Usage:
/// ```swift
/// try await withTemporaryDirectory { outputDir in
///     let url = try await pdf.render.client.html(
///         TestHTML.simple,
///         to: outputDir.appendingPathComponent("test.pdf")
///     )
///     // Directory is automatically cleaned up when scope exits
/// }
/// ```
public func withTemporaryDirectory<T>(
    id: UUID = UUID(),
    _ body: (URL) async throws -> T
) async rethrows -> T {
    let output = FileManager.default.temporaryDirectory
        .appendingPathComponent("html-to-pdf")
        .appendingPathComponent(id.uuidString)

    try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: output)
    }

    return try await body(output)
}

/// Synchronous variant for non-async tests
public func withTemporaryDirectory<T>(
    id: UUID = UUID(),
    _ body: (URL) throws -> T
) rethrows -> T {
    let output = FileManager.default.temporaryDirectory
        .appendingPathComponent("html-to-pdf")
        .appendingPathComponent(id.uuidString)

    try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: output)
    }

    return try body(output)
}

/// Provides a temporary PDF file URL with automatic cleanup
///
/// Creates a unique temporary file URL based on the calling location,
/// cleans up the entire directory when done. Safe for parallel test execution.
///
/// Usage:
/// ```swift
/// try await withTemporaryPDF { output in
///     let url = try await pdf.render.client.html(TestHTML.simple, to: output)
///     #expect(FileManager.default.fileExists(atPath: url.path))
/// }
/// ```
public func withTemporaryPDF<T>(
    fileID: String = #fileID,
    line: Int = #line,
    _ body: (URL) async throws -> T
) async rethrows -> T {
    let dirID = UUID()
    let outputDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("html-to-pdf")
        .appendingPathComponent(dirID.uuidString)

    // Extract test name from fileID (e.g., "HtmlToPdfTests/BasicFunctionalityTests.swift")
    let fileName = fileID.split(separator: "/").last?.replacingOccurrences(of: ".swift", with: "") ?? "test"
    let uniqueName = "\(fileName)-L\(line).pdf"
    let output = outputDir.appendingPathComponent(uniqueName)

    try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: outputDir)
    }

    return try await body(output)
}

/// Synchronous variant for non-async tests
public func withTemporaryPDF<T>(
    fileID: String = #fileID,
    line: Int = #line,
    _ body: (URL) throws -> T
) rethrows -> T {
    let dirID = UUID()
    let outputDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("html-to-pdf")
        .appendingPathComponent(dirID.uuidString)

    // Extract test name from fileID
    let fileName = fileID.split(separator: "/").last?.replacingOccurrences(of: ".swift", with: "") ?? "test"
    let uniqueName = "\(fileName)-L\(line).pdf"
    let output = outputDir.appendingPathComponent(uniqueName)

    try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: outputDir)
    }

    return try body(output)
}

/// Helper to generate unique PDF filename based on caller location
///
/// Creates a filename like "BasicFunctionalityTests-testSinglePDFGeneration-L42.pdf"
/// Safe for parallel execution as each test gets a unique filename.
///
/// Usage:
/// ```swift
/// try await withTemporaryDirectory { outputDir in
///     let url = try await pdf.render.client.html(
///         TestHTML.simple,
///         to: outputDir.pdfPath()
///     )
/// }
/// ```
public extension URL {
    func pdfPath(
        fileID: String = #fileID,
        line: Int = #line
    ) -> URL {
        // Extract test name from fileID (e.g., "HtmlToPdfTests/BasicFunctionalityTests.swift")
        let fileName = fileID.split(separator: "/").last?.replacingOccurrences(of: ".swift", with: "") ?? "test"
        let uniqueName = "\(fileName)-L\(line).pdf"
        return self.appendingPathComponent(uniqueName)
    }
}

/// Clean up all leftover test directories from interrupted tests
///
/// This is useful for CI cleanup or manual maintenance when tests are killed
/// before cleanup can run. Call this at the start of test suites if desired.
public func cleanupAllTestOutputs() {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent("html-to-pdf")

    guard fm.fileExists(atPath: tempDir.path) else { return }

    do {
        let subdirs = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)

        for subdir in subdirs {
            try? fm.removeItem(at: subdir)
        }

        try? fm.removeItem(at: tempDir)
    } catch {
        // Silently fail - this is a cleanup utility
    }
}
