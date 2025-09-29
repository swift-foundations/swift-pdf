# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2025-09-29

### Added
- iOS batch printing support with WebView pool for concurrent document processing
- Comprehensive documentation for `PrintingConfiguration` API in README
- Feature parity between iOS and macOS platforms for batch printing
- This CHANGELOG file to track version history

### Changed
- Improved performance: Test execution reduced from 28-39 seconds to 2.4 seconds
- Updated installation instructions in README to reference correct version
- Enhanced WebView pool management with better resource utilization

### Fixed
- Task group sequential execution bug that prevented proper concurrent processing
- NSPrintOperation crashes on macOS (replaced with WKWebView.createPDF() API)
- Continuation double-resume crashes with thread-safe ContinuationHandler actor
- WebView pool race conditions with proper initialization synchronization

### Removed
- Commented-out dead code in NSPrintOperation.swift

## [0.4.0] - 2024

### Added
- `PrintingConfiguration` struct for controlling printing behavior
- Support for million-document printing jobs with `largeBatch` configuration
- WebView pool with configurable size and acquisition timeouts
- Progress tracking callbacks for batch operations
- Retry logic for WebView acquisition

### Changed
- Replaced NSPrintOperation.runModal() with WKWebView.createPDF() for better stability
- Optimized WebView configuration for PDF generation
- Improved concurrent operation limiting based on processor count

## [0.3.0] - 2024

### Added
- WebViewPool actor for managing WKWebView instances
- Process pool sharing to reduce GPU/Network process initialization overhead
- Pre-warming of WebView processes for better performance

## [0.2.1] - 2024

### Fixed
- Minor bug fixes and performance improvements

## [0.2.0] - 2024

### Added
- AsyncStream support for tracking PDF generation progress
- Batch printing capabilities for document collections

## [0.1.6] - 2024

### Added
- Support for base64-encoded images in PDFs
- Paper orientation configuration options

## [0.1.0] - 2024

### Added
- Initial release
- Basic HTML to PDF conversion for iOS and macOS
- Support for custom margins and paper sizes
- Swift 6 language mode support

## Migration Guide

### Migrating to 0.5.0

#### New Features Available

1. **iOS Batch Printing**: iOS now supports batch printing similar to macOS:
```swift
// Previously iOS only supported single documents
// Now iOS supports batch printing:
let documents = [Document(...), Document(...)]
try await documents.print(
    configuration: .a4,
    printingConfiguration: .default
)
```

2. **PrintingConfiguration**: Control resource usage and timeouts:
```swift
// New configuration options
let config = PrintingConfiguration(
    maxConcurrentOperations: 8,
    documentTimeout: 30,
    progressHandler: { completed, total in
        print("\(completed)/\(total)")
    }
)
```

#### Breaking Changes

No breaking changes in this release. All existing APIs remain compatible.

#### Performance Improvements

This version includes significant performance improvements:
- 10x faster test execution (from ~30s to ~2.4s)
- Better WebView pool management
- Reduced memory usage for large batches

### Migrating to 0.4.0

#### New Required Parameter

If you were using custom configurations, you now need to use `PrintingConfiguration`:

**Before:**
```swift
try await documents.print(configuration: .a4)
```

**After:**
```swift
try await documents.print(
    configuration: .a4,
    printingConfiguration: .default  // New parameter
)
```

The default value maintains backward compatibility, so existing code will continue to work.