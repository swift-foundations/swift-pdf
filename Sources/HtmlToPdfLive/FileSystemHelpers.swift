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
/// Uses write-then-move pattern for atomic file replacement:
/// 1. Write to temporary file in same directory
/// 2. Move temp file to final destination (atomic operation)
///
/// This prevents partial PDFs if the process is interrupted during write.
internal func writeAtomically(_ data: Data, to outputURL: URL) throws {
    let dir = outputURL.deletingLastPathComponent()
    let tmp = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf.tmp")
    try data.write(to: tmp)
    try FileManager.default.moveItem(at: tmp, to: outputURL)
}
