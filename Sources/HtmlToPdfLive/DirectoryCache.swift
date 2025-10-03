//
//  DirectoryCache.swift
//  swift-html-to-pdf
//
//  Thread-safe directory validation cache
//

import Dependencies
import Foundation
import IssueReporting

/// Thread-safe cache for directory validation
///
/// Reduces redundant file system checks by caching validated directory paths.
/// Uses lock-based synchronization to protect the validated set.
///
/// Thread Safety: Uses `LockIsolated` to protect the validated set with an NSRecursiveLock.
/// All mutations to the set are performed within `withLock` closures, ensuring exclusive access.
final class DirectoryCache: Sendable {
    private let validated = LockIsolated(Set<String>())

    func ensureDirectory(
        at url: URL,
        createIfNeeded: Bool
    ) throws {
        let path = url.path

        // Fast path: check cache with lock
        let isValidated = validated.withValue { $0.contains(path) }

        if isValidated {
            return
        }

        // Slow path: check and possibly create (file I/O)
        if createIfNeeded {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
            _ = validated.withValue { $0.insert(path) }
        } else {
            // Validate directory exists when createDirectories is false
            var isDirectory: ObjCBool = false
            if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) || !isDirectory.boolValue {
                throw PrintingError.invalidFilePath(
                    url,
                    underlyingError: NSError(
                        domain: NSCocoaErrorDomain,
                        code: NSFileNoSuchFileError,
                        userInfo: [NSLocalizedDescriptionKey: "Directory does not exist: \(path)"]
                    )
                )
            }
            _ = validated.withValue { $0.insert(path) }
        }
    }

    func clear() {
        validated.withValue { $0.removeAll() }
    }
}

/// Shared directory cache for the rendering session
let directoryCache = DirectoryCache()
