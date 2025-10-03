//
//  FileSystemHelpers.swift
//  swift-html-to-pdf
//
//  Shared file system utilities
//

import Foundation

// MARK: - Atomic File Operations

/// Write data atomically to prevent partial files
///
/// Uses write-then-move/replace pattern for atomic file operations:
/// 1. Write to temporary file in same directory
/// 2. If destination exists: replace atomically (handles overwrite)
/// 3. If destination doesn't exist: move atomically (creates new file)
///
/// This prevents partial PDFs if the process is interrupted during write.
internal func writeAtomically(_ data: Data, to outputURL: URL) throws {
    let dir = outputURL.deletingLastPathComponent()
    let tmp = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf.tmp")
    try data.write(to: tmp)

    // Use replaceItemAt for existing files (atomic replacement)
    // Use moveItem for new files (replaceItemAt requires destination to exist)
    if FileManager.default.fileExists(atPath: outputURL.path) {
        _ = try FileManager.default.replaceItemAt(outputURL, withItemAt: tmp)
    } else {
        try FileManager.default.moveItem(at: tmp, to: outputURL)
    }
}
