//
//  TestUtilities.swift
//  PDFTestSupport
//
//  Common test utilities and extensions
//

import Foundation
import Testing

// MARK: - URL Extensions

extension URL {
    /// Generate a temporary output URL for test PDFs
    public static func output(id: UUID = UUID()) -> Self {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("html-to-pdf")
            .appendingPathComponent(id.uuidString)
    }

    /// Local HtmlToPdf directory (platform-aware)
    public static var localHtmlToPdf: Self {
        #if os(macOS)
        return URL.documentsDirectory.appendingPathComponent("HtmlToPdf")
        #else
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths.first!.appendingPathComponent("HtmlToPdf")
        #endif
    }
}

// MARK: - FileManager Extensions

extension FileManager {
    /// Remove all items within a directory
    public func removeItems(at url: URL) throws {
        let fileURLs = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        for fileURL in fileURLs {
            try removeItem(at: fileURL)
        }
    }

    /// Clean up any leftover test directories from interrupted tests
    ///
    /// This is useful when tests timeout or are interrupted before cleanup can run
    public static func cleanupTestDirectories() {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("html-to-pdf")

        guard fm.fileExists(atPath: tempDir.path) else { return }

        do {
            let subdirs = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            print("🧹 Cleaning up \(subdirs.count) leftover test directories...")

            for subdir in subdirs {
                try? fm.removeItem(at: subdir)
            }

            try? fm.removeItem(at: tempDir)
            print("✅ Cleanup complete")
        } catch {
            print("⚠️ Cleanup failed: \(error)")
        }
    }
}

// MARK: - AsyncStream Extensions

extension AsyncStream<URL> {
    /// Test that yielded URLs exist on the file system
    public func testIfYieldedUrlExistsOnFileSystem(directory: URL) async throws {
        for await url in self {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).map(\.lastPathComponent)
            #expect(contents.contains(where: { $0 == url.lastPathComponent }))
        }
    }
}

extension AsyncThrowingStream<URL, Error> {
    /// Test that yielded URLs exist on the file system
    public func testIfYieldedUrlExistsOnFileSystem(directory: URL) async throws {
        for try await url in self {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).map(\.lastPathComponent)
            #expect(contents.contains(where: { $0 == url.lastPathComponent }))
        }
    }
}
