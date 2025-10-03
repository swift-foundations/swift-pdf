# ``HtmlToPdf``

State-of-the-art HTML to PDF generation for Apple platforms with exceptional performance and type safety.

## Overview

HtmlToPdf provides a powerful, type-safe API for generating PDF documents from HTML with industry-leading throughput of over 2,000 PDFs per second. Built with Swift 6 strict concurrency, it offers both beginner-friendly simplicity and advanced customization options.

### Key Features

- **⚡ Exceptional Performance**: 2,016 PDFs/sec peak throughput
- **🎯 Type-Safe**: Full Swift 6 strict concurrency support
- **📄 Dual Modes**: Fast continuous or print-ready paginated output
- **🔄 Streaming**: Process results as they complete
- **💾 Memory Efficient**: Constant memory usage regardless of batch size

## Quick Start

Generate a PDF in one line:

```swift
@Dependency(\.pdf) var pdf
try await pdf.html("<html><body><h1>Hello</h1></body></html>", to: fileURL)
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:PerformanceGuide>
- <doc:ConfigurationGuide>

### Core Types

- ``PDF``
- ``PDF/Render``
- ``PDF/Configuration``
- ``PDF/Document``
- ``PDF/Result``

### Rendering

- ``PDF/Render/Client``
- ``PDF/FailedDocument``

### Configuration

- ``PDF/PaginationMode``
- ``PDF/ConcurrencyStrategy``
- ``PDF/NamingStrategy``
- ``EdgeInsets``

### Error Handling

- ``PrintingError``

### Platform Features

- ``PDF/Capabilities``
